defmodule MaxiTaxi.SimulatedTaxi do
  def child_spec(_) do
    name = :"taxi_#{:rand.uniform(1_000_000)}"
    %{id: name, start: {__MODULE__, :start_link, [name]}}
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  defstruct location: {0, 0},
            direction: {0, 0},
            name: ""

  @tick_interval 300
  @bounds {{0, 0}, {1, 1}}

  def init(name) do
    initial_state = %__MODULE__{name: name}
    schedule_next_tick()
    {:ok, initial_state}
  end

  defp schedule_next_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end

  def handle_info(:tick, state) do
    new_state =
      state
      |> randomize_direction()
      |> calculate_new_location()

    MaxiTaxi.TaxiLocationsDatabase.update(state.name, state.location)

    schedule_next_tick()
    {:noreply, new_state}
  end

  defp randomize_direction(state) do
    impulse = (:rand.uniform(200) - 100) / 500

    {x, y} = state.direction

    new_direction =
      case :rand.uniform(2) do
        1 -> {x + impulse, y}
        2 -> {x, y + impulse}
      end
      |> normalize_direction()

    Map.put(state, :direction, new_direction)
  end

  defp calculate_new_location(state) do
    {x, y} = state.location
    {dx, dy} = state.direction

    new_location = {x + dx / 1000, y + dy / 1000}

    case in_bounds?(new_location, @bounds) do
      :ok ->
        Map.put(state, :location, new_location)

      :out_of_bounds_x ->
        Map.put(state, :direction, {-dx, dy}) |> calculate_new_location()

      :out_of_bounds_y ->
        Map.put(state, :direction, {dx, -dy}) |> calculate_new_location()
    end
  end

  defp normalize_direction({x, y}) when x == 0 and y == 0, do: {0, 0}

  defp normalize_direction({x, y}) do
    divisor = :math.sqrt(:math.pow(x, 2) + :math.pow(y, 2))

    {x / divisor, y / divisor}
  end

  defp reverse_direction({x, y}), do: {-x, -y}

  defp in_bounds?({x, y}, {{min_x, min_y}, {max_x, max_y}}) do
    cond do
      x < min_x || x > max_x -> :out_of_bounds_x
      y < min_y || y > max_y -> :out_of_bounds_y
      true -> :ok
    end
  end
end
