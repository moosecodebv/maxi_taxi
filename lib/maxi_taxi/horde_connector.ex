defmodule MaxiTaxi.HordeConnector do
  use GenServer

  @table __MODULE__

  def child_spec(arg) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [arg]}}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    set_neighbours()
    :net_kernel.monitor_nodes(true)

    {:ok, nil}
  end

  defp set_neighbours() do
    neighbour_nodes =
      ([node() | Node.list()] -- [:"manager@127.0.0.1"])
      |> case do
        [] -> [node()]
        nodes -> nodes
      end

    set_neighbours_supervisor(neighbour_nodes)
    set_neighbours_registry(neighbour_nodes)
  end

  defp set_neighbours_registry(neighbour_nodes) do
    neighbours = Enum.map(neighbour_nodes, fn node -> {MaxiTaxi.TaxiRegistry, node} end)
    # |> IO.inspect(label: :registry_neighbours)

    Horde.Cluster.set_members(MaxiTaxi.TaxiRegistry, neighbours)
  end

  defp set_neighbours_supervisor(neighbour_nodes) do
    neighbours = Enum.map(neighbour_nodes, fn node -> {MaxiTaxi.TaxiSupervisor, node} end)
    # |> IO.inspect(label: :supervisor_neighbours)

    Horde.Cluster.set_members(MaxiTaxi.TaxiSupervisor, neighbours)
  end

  def handle_info({node_change, _node}, state) when node_change in [:nodeup, :nodedown] do
    # exclude the central test node (manager@127.0.0.1)
    set_neighbours()
    {:noreply, state}
  end
end
