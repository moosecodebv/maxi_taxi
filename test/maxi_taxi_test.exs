defmodule MaxiTaxiTest do
  use ExUnit.Case, async: false
  doctest MaxiTaxi
  alias MaxiTaxi.TaxiLocationsDatabase

  setup do
    MaxiTaxi.TaxiLocationsDatabase.clear()
    :ok
  end

  test "can store and retrieve taxi locations" do
    assert :ok = TaxiLocationsDatabase.update("1", {1, 1})
    assert :ok = TaxiLocationsDatabase.update("2", {1, 1})
    assert :ok = TaxiLocationsDatabase.update("1", {2, 1})

    assert {:ok, {1, 1}} = TaxiLocationsDatabase.fetch("2")
    assert {:ok, {2, 1}} = TaxiLocationsDatabase.fetch("1")
    assert :no_known_location = TaxiLocationsDatabase.fetch("3")
  end

  test "can find the nearest taxi" do
    :ok = TaxiLocationsDatabase.update("1", {0.01, 0.01})
    :ok = TaxiLocationsDatabase.update("2", {0.01, 0.02})
    :ok = TaxiLocationsDatabase.update("3", {0.02, 0.01})

    assert :no_taxi_found = TaxiLocationsDatabase.find({1, 1})
    assert {:ok, "1"} = TaxiLocationsDatabase.find({0.01, 0.012})
    assert {:ok, "2"} = TaxiLocationsDatabase.find({0.01, 0.019})
    assert {:ok, "3"} = TaxiLocationsDatabase.find({0.019, 0.01})
  end

  test "taxi locations database works across multiple nodes" do
    [n1, _n2, n3] = LocalCluster.start_nodes("maxi-cluster-0", 3)

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["1", {0.01, 0.01}])
    Process.sleep(50)
    assert {:ok, "1"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])
  end

  test "taxi locations have a TTL of 2s" do
    [n1, _n2, n3] = LocalCluster.start_nodes("maxi-cluster-1", 3)

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["1", {0.01, 0.01}])
    Process.sleep(50)
    assert {:ok, "1"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])

    Process.sleep(2500)

    assert :no_taxi_found = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])
  end

  # TODO this should go in a different branch
  test "the database recovers after a netsplit" do
    [n1, n2, n3] = LocalCluster.start_nodes("maxi-cluster-2", 3)

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["1", {0.01, 0.01}])
    Process.sleep(200)

    Schism.partition([n2])

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["2", {0.012, 0.012}])
    Process.sleep(200)

    assert {:ok, "1"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])
    assert {:ok, "2"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.012, 0.012}])

    assert {:ok, "1"} = :rpc.call(n2, TaxiLocationsDatabase, :find, [{0.012, 0.012}])

    Schism.heal([n1, n2, n3])

    Process.sleep(500)

    assert {:ok, "2"} = :rpc.call(n2, TaxiLocationsDatabase, :find, [{0.012, 0.012}])
  end

  test "can reserve and unreserve a taxi" do
    Process.sleep(100)
    assert :ok = MaxiTaxi.Taxi.enter("2", "4")

    # idempotent
    assert :ok = MaxiTaxi.Taxi.enter("2", "4")

    # rejects an occupied taxi
    assert {:error, :taxi_occupied} = MaxiTaxi.Taxi.enter("2", "3")

    # idempotent
    assert :ok = MaxiTaxi.Taxi.exit("2", "3")

    # can exit taxi you have entered
    assert :ok = MaxiTaxi.Taxi.exit("2", "4")

    # now passenger 3 can enter
    assert :ok = MaxiTaxi.Taxi.enter("2", "3")
    assert :ok = MaxiTaxi.Taxi.exit("2", "3")
  end

  test "reserving and unreserving is consistent in the cluster" do
    [n1, n2, n3] = LocalCluster.start_nodes("maxicluster-3", 3)

    Process.sleep(100)

    assert :ok = :rpc.call(n1, MaxiTaxi.Taxi, :enter, ["2", "4"])

    Process.sleep(1000)

    assert "4" = :rpc.call(n1, MaxiTaxi.Taxi, :which_customer, ["2"])
    assert "4" = :rpc.call(n2, MaxiTaxi.Taxi, :which_customer, ["2"])
    assert "4" = :rpc.call(n3, MaxiTaxi.Taxi, :which_customer, ["2"])
    assert {:error, :taxi_occupied} = :rpc.call(n1, MaxiTaxi.Taxi, :enter, ["2", "3"])
    assert {:error, :taxi_occupied} = :rpc.call(n2, MaxiTaxi.Taxi, :enter, ["2", "3"])
    assert {:error, :taxi_occupied} = :rpc.call(n3, MaxiTaxi.Taxi, :enter, ["2", "3"])
  end

  test "can recover from a netsplit" do
    [n1, n2, n3] = LocalCluster.start_nodes("maxicluster-4", 3)

    Schism.partition([n2])

    Process.sleep(50)

    assert :ok = :rpc.call(n1, MaxiTaxi.Taxi, :enter, ["3", "4"])
    assert :ok = :rpc.call(n2, MaxiTaxi.Taxi, :enter, ["3", "9"])

    # during network partition, multiple truths are possible
    assert "4" = :rpc.call(n1, MaxiTaxi.Taxi, :which_customer, ["3"])
    assert "9" = :rpc.call(n2, MaxiTaxi.Taxi, :which_customer, ["3"])

    Schism.heal([n1, n2, n3])

    Process.sleep(200)

    # after the partition is healed, only one truth persists

    assert taxi_id = :rpc.call(n1, MaxiTaxi.Taxi, :which_customer, ["3"])
    assert ^taxi_id = :rpc.call(n2, MaxiTaxi.Taxi, :which_customer, ["3"])
  end

  test "attempts to replicate own state to winning process" do
    [n1, n2, n3] = LocalCluster.start_nodes("maxicluster-4", 3)

    Schism.partition([n2])

    Process.sleep(50)

    assert nil == :rpc.call(n1, MaxiTaxi.Taxi, :which_customer, ["3"])
    Process.sleep(50)
    assert nil == :rpc.call(n2, MaxiTaxi.Taxi, :which_customer, ["3"])

    assert :ok = :rpc.call(Enum.random([n1, n2]), MaxiTaxi.Taxi, :enter, ["3", "4"])

    Schism.heal([n1, n2, n3])

    Process.sleep(200)

    # after the partition is healed, only one truth persists

    assert "4" = :rpc.call(n1, MaxiTaxi.Taxi, :which_customer, ["3"])
    assert "4" = :rpc.call(n2, MaxiTaxi.Taxi, :which_customer, ["3"])
  end
end
