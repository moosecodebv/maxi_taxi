# MaxiTaxi

MaxiTaxi is a very simple application:

1. Taxis send their location information to MaxiTaxi.
2. Customers can order a taxi and use it to get from A to B.

The system will track:
1. The last known position of each taxi.
2. Whether a taxi is occupied or not.

The following operations will be supported:
1. Update the location of a taxi.
2. Search for a nearby taxi that is unoccupied.
3. Enter a taxi.
4. Leave a taxi.

## Tutorial

1. libcluster & :rpc
2. Distributed location database
3. Horde
4. Horde partition tolerance

## 1a. libcluster

Install libcluster in the application.

Configure libcluster using the guide in the [README](https://github.com/bitwalker/libcluster) (`Cluster.Strategy.Epmd`) to connect nodes `maxi1@127.0.0.1` and `maxi2@127.0.0.1`.

Start the nodes:

```
iex --name maxi1@127.0.0.1 -S mix
```

```
iex --name maxi2@127.0.0.1 -S mix
```

Confirm that the nodes are connected:

```
iex(maxi1@127.0.0.1)1> Node.list()
[:"maxi2@127.0.0.1"]
```

## 1b. using `:rpc`

We will choose one node to be the central "master" of our information, and use `:rpc` to execute functions on this node.

Useful functions:
`Node.list/0`
`Enum.sort/1`
`hd/1`

Use the :rpc module to send all update and find requests to a single node in the cluster.

## optional 1c. using `send/2`

Use `send/2` instead of `:rpc`.

Reminder: `{name, node}`.

## 2a. distributed location database

Now we have designated one node to be our location database. Let's make this more robust. We will use [libring](https://github.com/bitwalker/libring) to push location updates to N/3 nodes.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `maxi_taxi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:maxi_taxi, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/maxi_taxi](https://hexdocs.pm/maxi_taxi).

