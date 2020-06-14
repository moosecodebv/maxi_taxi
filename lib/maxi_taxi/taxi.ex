defmodule MaxiTaxi.Taxi do
  use GenServer
  require Logger

  def enter(taxi_id, customer_id) do
    ensure_started(taxi_id)
    |> GenServer.call({:enter, taxi_id, customer_id})
  end

  def exit(taxi_id, customer_id) do
    ensure_started(taxi_id)
    |> GenServer.call({:exit, taxi_id, customer_id})
  end

  def which_customer(taxi_id) do
    ensure_started(taxi_id)
    |> GenServer.call(:which_customer)
  end

  def init(taxi_id) do
    Process.flag(:trap_exit, true)
    {:ok, {taxi_id, nil}}
  end

  def handle_info({:EXIT, _from, {:name_conflict, _key_value, _registry, pid}}, state) do
    Logger.warn("process stopped, #{inspect(state)}")

    case state do
      {_, nil} -> nil
      {taxi_id, customer_id} -> enter(taxi_id, customer_id)
    end

    {:stop, :normal, state}
  end

  def handle_call({:enter, taxi_id, customer_id}, _from, {taxi_id, nil}) do
    # allow
    {:reply, :ok, {taxi_id, customer_id}}
  end

  def handle_call({:enter, taxi_id, customer_id}, _from, {taxi_id, customer_id}) do
    # idempotent
    {:reply, :ok, {taxi_id, customer_id}}
  end

  def handle_call({:enter, taxi_id, _}, _from, {taxi_id, _} = state) do
    # deny
    {:reply, {:error, :taxi_occupied}, state}
  end

  def handle_call({:exit, taxi_id, customer_id}, _from, {taxi_id, nil}) do
    # idempotent
    {:reply, :ok, {taxi_id, nil}}
  end

  def handle_call({:exit, taxi_id, customer_id}, _from, {taxi_id, customer_id}) do
    # allow
    {:reply, :ok, {taxi_id, nil}}
  end

  def handle_call({:exit, taxi_id, customer_id}, _from, {taxi_id, _} = state) do
    # idempotent
    {:reply, :ok, state}
  end

  def handle_call(:which_customer, _from, {_, customer_id} = state) do
    {:reply, customer_id, state}
  end

  def child_spec(name) do
    %{id: name, start: {__MODULE__, :start_link, [name]}, restart: :transient}
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
    |> case do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> :ignore
    end
  end

  defp via_tuple(name) do
    {:via, Horde.Registry, {MaxiTaxi.TaxiRegistry, name}}
  end

  def ensure_started(taxi_id) do
    Horde.Registry.lookup(MaxiTaxi.TaxiRegistry, taxi_id)
    |> case do
      [{pid, _}] ->
        pid

      [] ->
        Horde.DynamicSupervisor.start_child(MaxiTaxi.TaxiSupervisor, {MaxiTaxi.Taxi, taxi_id})
        |> case do
          {:ok, pid} -> pid
          :ignore -> raise "probably a race condition"
        end
    end
  end
end
