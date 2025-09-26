# Comb

Comb provides small building blocks for caching, refreshing, and scheduled tidying of cached values in Elixir applications.
It's intended to be a lightweight toolkit that you can drop into your supervision tree and wire up
to your app's cache/refresh workflows.

## Key features

- Simple TTL-based caches and table-backed caches
- Single-flight load suppression to avoid thundering-herd problems
- Refreshing and notification helpers for keeping cached values up-to-date
- A small supervision and registry layout suitable for embedding in apps

## Usage

Add `comb` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:comb, "~> 0.0.1"}
  ]
end
```

Then start your instance:

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    children = [
      {Comb, name: MyApp.Cache, fetch_one: &MyApp.DB.fetch_one/1}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Running tests

Run the test suite with:

```bash
mix test
```

Build documentation locally with ExDoc:

```bash
mix docs
```

## License

This project includes a `LICENSE` file in the repository root. See that file
for license terms.
