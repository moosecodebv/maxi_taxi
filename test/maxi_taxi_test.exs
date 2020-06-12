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

  test "can find taxi locations" do
    :ok = TaxiLocationsDatabase.update("1", {0.01, 0.01})
    :ok = TaxiLocationsDatabase.update("2", {0.01, 0.02})
    :ok = TaxiLocationsDatabase.update("3", {0.02, 0.01})

    assert :no_taxi_found = TaxiLocationsDatabase.find({1, 1})
    assert {:ok, "1"} = TaxiLocationsDatabase.find({0.01, 0.012})
    assert {:ok, "2"} = TaxiLocationsDatabase.find({0.01, 0.019})
    assert {:ok, "3"} = TaxiLocationsDatabase.find({0.019, 0.01})
  end

  test "taxi locations database works across multiple nodes" do
    [n1, _n2, n3] = LocalCluster.start_nodes("maxi-cluster-", 3)

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["1", {0.01, 0.01}])
    assert {:ok, "1"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])
  end

  test "taxi locations have a TTL of 2s" do
    [n1, _n2, n3] = LocalCluster.start_nodes("maxi-cluster-", 3)

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["1", {0.01, 0.01}])
    assert {:ok, "1"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])

    Process.sleep(2500)

    assert :no_taxi_found = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])
  end

  # TODO this should go in a different branch
  test "the database recovers after a netsplit" do
    [n1, n2, n3] = LocalCluster.start_nodes("maxi-cluster-", 3)

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["1", {0.01, 0.01}])

    Schism.partition([n2])

    :ok = :rpc.call(n1, TaxiLocationsDatabase, :update, ["2", {0.012, 0.012}])

    assert {:ok, "1"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.01, 0.01}])
    assert {:ok, "2"} = :rpc.call(n3, TaxiLocationsDatabase, :find, [{0.012, 0.012}])

    assert {:ok, "1"} = :rpc.call(n2, TaxiLocationsDatabase, :find, [{0.012, 0.012}])

    Schism.heal([n1, n2, n3])

    Process.sleep(500)

    assert {:ok, "2"} = :rpc.call(n2, TaxiLocationsDatabase, :find, [{0.012, 0.012}])
  end
end
