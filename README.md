# Quarry

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

## Examples

Full example

```elixir
filter = %{title: "Hello", author: %{name: "John Doe"}}
load = [:author, comments: :user]
sort = [:title, author: :name]
limit = 10
offset = 20
Quarry.build(Post, filter: filter, load: load, sort: sort, limit: limit, offset: offset)
```

Filter examples

```elixir
# Top level attribute
Quarry.build(Post, filter: %{title: "Value"})
# Field on nested belongs_to relationship
Quarry.build(Post, filter: %{author: %{name: "John Doe"}})
# Field on nested has_many relationship
Quarry.build(Post, filter: %{comments: %{body: "comment body"}})
```

Load examples

```elixir
# Single atom
Quarry.build(Post, load: :author)
# List of atoms
Quarry.build(Post, load: [:author, :comments])
# Nested entities
Quarry.build(Post, load: [comments: :user])
# List of nested entities
Quarry.build(Post, load: [author: [:user, :posts]])
# Use Quarry on nested has_many association
Quarry.build(Post, load: [comments: [filter: %{body: "comment"}, load: :user]])
```

Sort examples

```elixir
# Single field
Quarry.build(Post, sort: :title)
# Multiple fields
Quarry.build(Post, sort: [:title, :body])
# Nested fields
Quarry.build(Post, sort: [[:author, :publisher], :title, [:author, :user, :name]])
# Descending sort
Quarry.build(Post, sort: [:title, desc: :body, desc: [:author, :publisher]])
```

Limit example

```elixir
Quarry.build(Post, limit: 10)
```

Offset example

```elixir
Quarry.build(Post, limit: 10, offset: 20)
```

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
