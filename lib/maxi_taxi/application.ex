defmodule MaxiTaxi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children =
      [
        {Cluster.Supervisor, [libcluster_config(), [name: MaxiTaxi.ClusterSupervisor]]},
        MaxiTaxi.TaxiLocationsDatabase
      ] ++ Enum.map(1..10, fn _ -> MaxiTaxi.SimulatedTaxi end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MaxiTaxi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp libcluster_config do
    [
      maxi_taxi: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: [:"maxi1@127.0.0.1", :"maxi2@127.0.0.1"]]
      ]
    ]
  end
end