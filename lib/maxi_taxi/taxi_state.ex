defmodule MaxiTaxi.TaxiState do
  # A taxi can be occupied, or not occupied
  #
  #   ┌────────────┐            ┌────────────┐
  #   |            |            |            |
  #   |            | --enter--> |            |
  #   | unoccupied |            |  occupied  |
  #   |            | <- exit -- |            |
  #   |            |            |            |
  #   └────────────┘            └────────────┘
  #
  defstruct occupied: false

  def occupied?(%{occupied: false}), do: false
  def occupied?(_), do: true

  def enter(%{occupied: false}, customer_id), do: %{occupied: customer_id}
  def enter(state, _customer_id), do: state

  def exit(%{occupied: customer_id} = state, customer_id), do: %{state | occupied: false}
  def exit(state, _), do: state
end
