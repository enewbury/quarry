# Quarry

[![Build Status](https://github.com/enewbury/quarry/workflows/test/badge.svg)](https://github.com/enewbury/quarry/actions)
[![Coverage Status](https://coveralls.io/repos/enewbury/quarry/badge.svg?branch=main)](https://coveralls.io/r/enewbury/quarry?branch=main)
[![hex.pm version](https://img.shields.io/hexpm/v/quarry.svg)](https://hex.pm/packages/quarry)
[![hex.pm downloads](https://img.shields.io/hexpm/dt/quarry.svg)](https://hex.pm/packages/quarry)
[![hex.pm license](https://img.shields.io/hexpm/l/quarry.svg)](https://github.com/enewbury/quarry/blob/main/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/enewbury/quarry.svg)](https://github.com/enewbury/quarry/commits/main)


A data-driven Ecto Query builder for nested associations.

With specifications like GraphQL which seek to granularly fetch data as needed by a client,
we are generally forced to either fetch more data than we need to satisfy the greatest need,
joining in lots of data to allow filtering on nested data, or we end up limiting the functionality
of the endpoint to a few predefined types of selections.

Technologies like Dataloader help solve for this by allowing you to fetch nested objects as needed
in one query per entity type, but this doesn't help for filtering or sorting by nested entities
which require a join to be available in the main query. Also belongs_to associations that only include
one sub entity are more efficient to join into the main query, and using Dataloader to fetch this
ads an unnecessary query.

This is where Quarry comes in, named for its ability to "excavate valuable materials". You can specify all the
filters, loads, and sorts with any level of granularity and at any association level, and Quarry will build a
query for you that optimizes for joining just the data you need and no more. To optimize has_many associations, subqueries
are used for preloading the entity. This is generally more optimal than joining and selecting all the data
because it avoids pulling n\*m records into memory.

When loading in nested data, you can also apply the full set of Quarry options to filter, sort, limit,
and load the list of nested data.

This is an internal library and takes all options as atoms. In production, you may want to do some field authorization
or pruning prior to passing user data into Quarry. If you are using graphql this is mostly taken care of through
defining your schema, but if you are mapping url params in a json api, you'll want to do some pre-checking of
authorized fields before converting them to atoms and passing them into Quarry. Quarry allows filtering by any
field or association on a schema and you may not want this. It would also be wise to do this checking before
converting into atoms since a user could theoretically pass a huge amount of bad keys and fill of the Beam atom store.

## Installation

The package can be installed by adding `quarry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:quarry, "~> 0.1.0"}
  ]
end
```

## Example

```elixir
filter = %{title: "Hello", author: %{name: {:starts_with, "John"}}}
load = [:author, comments: :user]
sort = [[:author, :publisher], :title]
limit = 10
offset = 20
Quarry.build(Post, filter: filter, load: load, sort: sort, limit: limit, offset: offset)
```

See Docs for a more exhaustive list of examples

## Usage

Quarry is quite flexible, and can be used as you see fit, but it basically comes down to 1) Validating input 2) Calling Quarry to build a query, and 3) calling Repo.all()

```elixir
defmodule Blog.Posts do
  def list(opts \\ %{}) do
    opts = APIUtils.validate_and_cast(opts)

    Post
    |> Quarry.build(opts)
    |> Repo.all()
  end
end
```

## Documentation

HexDocs documentation can be found at https://hexdocs.pm/quarry
