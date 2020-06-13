defmodule MaxiTaxi.Taxi do
  use GenServer

  def enter(taxi_id, customer_id) do
    pid = ensure_started(taxi_id)
    GenServer.call(pid, {:enter, taxi_id, customer_id})
  end

  def exit(taxi_id, customer_id) do
    pid = ensure_started(taxi_id)
    GenServer.call(pid, {:exit, taxi_id, customer_id})
  end

  def init(taxi_id) do
    {:ok, {taxi_id, nil}}
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

  def child_spec(name) do
    %{id: name, start: {__MODULE__, :start_link, [name]}, restart: :transient}
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  defp via_tuple(name) do
    {:via, Horde.Registry, {MaxiTaxi.TaxiRegistry, name}}
  end

  def ensure_started(taxi_id) do
    Horde.DynamicSupervisor.start_child(MaxiTaxi.TaxiSupervisor, {MaxiTaxi.Taxi, taxi_id})
    |> case do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
end
