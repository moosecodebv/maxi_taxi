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

The tutorial is split into 4 branches:
- `exercise_1`
- `exercise_2`
- `exercise_3`
- `exercise_4`

You can start with `exercise_1`. If you have completed the exercises, then you can continue in that branch with your own solutions, or you can choose to switch to the `exercise_2` branch to continue.

The topics covered are:
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

We will distribute the location database to all nodes in the cluster. We will use [`:rpc.call/4`](erlang.org/doc/man/rpc.html#call-4) for this.

1. Send updates to all nodes in the cluster using `:rpc.call/4`.
2. Implement a TTL of 2s on updates to prevent stale information from being served (in case of a netsplit for example).

## optional 1c. using `send/2`

Use [`send/2`](https://hexdocs.pm/elixir/Kernel.html#send/2) instead of `:rpc.call/4`. This will help us avoid bottlenecks in `:rpc`.

Reminder: [`{name, node}`](https://hexdocs.pm/elixir/Process.html#t:dest/0).

## 2. distributed location database

Now we have a "distributed location database", but there is no way for nodes to recover if there is a conflict.

1. Use [`delta_crdt`](https://github.com/derekkraan/delta_crdt_ex/) to make the database eventually consistent.

Note: information on nodes can still be out of date, but after a netsplit the database will globally converge.

## 3. distributed taxi state

A taxi can be entered and exited, but we can't allow more than one customer to enter a taxi.

We will use [`Horde`](https://github.com/derekkraan/horde) ([docs](https://hexdocs.pm/horde/readme.html)) to distribute taxi processes among the nodes in the cluster. We will register and access the taxi processes using [`Horde.Registry`](https://hexdocs.pm/horde/Horde.Registry.html). `Horde.Registry` will also keep them unique.

[`Horde.DynamicSupervisor`](https://hexdocs.pm/horde/Horde.Registry.html) will ensure that if a node goes down, that the taxi processes are restarted on another node.

1. start taxi state processes using Horde.DynamicSupervisor
2. register processes with Horde.Registry

## 4. handling network partitions

1. [read](https://hexdocs.pm/horde/eventual_consistency.html#content) [the](https://hexdocs.pm/horde/state_handoff.html#content) [docs](https://hexdocs.pm/horde/libcluster.html#content) of Horde and figure out how to handle registry conflicts.
