defmodule Quarry do
  @moduledoc """
  A data-driven ecto query builder for nested associations.

  Quarry allows you to interact with your database thinking only about your data, and generates queries
  for exactly what you need. You can specify all the filters, loads, and sorts with any level of granularity
  and at any association level, and Quarry will build a query for you that optimizes for joining just the data
  that is necessary and no more. To optimize has_many associations, subqueries are used for preloading the entity.
  This is generally more optimal than joining and selecting all the data because it avoids pulling n*m
  records into memory.
  """
  require Ecto.Query

  alias Quarry.{From, Filter, Load, Sort}

  @type operation :: :lt | :gt | :lte | :gte | :starts_with | :ends_with
  @type filter_param :: String.t() | number
  @type tuple_filter_param :: {operation(), filter_param()}
  @type filter :: %{optional(atom()) => filter_param() | tuple_filter_param()}
  @type load :: atom() | [atom() | keyword(load())]
  @type sort :: atom() | [atom() | [atom()] | {:asc | :desc, atom() | [atom()]}]
  @type opts :: [
          filter: filter(),
          load: load(),
          sort: sort(),
          limit: integer(),
          offset: integer()
        ]

  @type error :: %{type: :filter | :load, path: [atom()], message: String.t()}

  @doc """
  Builds a query for an entity type from parameters


  ## Examples

  ```elixir
  # Top level attribute
  iex> Quarry.build!(Quarry.Post, filter: %{title: "Value"})
  #Ecto.Query<from p0 in Quarry.Post, as: :post, where: as(:post).title == ^"Value">

  # Field on nested belongs_to relationship
  iex> Quarry.build!(Quarry.Post, filter: %{author: %{publisher: "Publisher"}})
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: a1 in assoc(p0, :author), as: :post_author, where: as(:post_author).publisher == ^"Publisher">

  # Field on nested has_many relationship
  iex> Quarry.build!(Quarry.Post, filter: %{comments: %{body: "comment body"}})
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: c1 in assoc(p0, :comments), as: :post_comments, where: as(:post_comments).body == ^"comment body">


  # Can filter by explicit operation
  iex> Quarry.build!(Quarry.Post, filter: %{author: %{user: %{login_count: {:eq, 1}}}})
  iex> Quarry.build!(Quarry.Post, filter: %{author: %{user: %{login_count: {:lt, 1}}}})
  iex> Quarry.build!(Quarry.Post, filter: %{author: %{user: %{login_count: {:gt, 1}}}})
  iex> Quarry.build!(Quarry.Post, filter: %{author: %{user: %{login_count: {:lte, 1}}}})
  iex> Quarry.build!(Quarry.Post, filter: %{author: %{user: %{login_count: {:gte, 1}}}})
  iex> Quarry.build!(Quarry.Post, filter: %{title: {:starts_with, "How to"}})
  iex> Quarry.build!(Quarry.Post, filter: %{title: {:ends_with, "learn vim"}})
  ```

  ### Load examples

  ```elixir
  # Single atom
  iex> Quarry.build!(Quarry.Post, load: :author)
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: a1 in assoc(p0, :author), as: :post_author, preload: [author: a1]>

  # List of atoms
  iex> Quarry.build!(Quarry.Post, load: [:author, :comments])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: a1 in assoc(p0, :author), as: :post_author, preload: [comments: #Ecto.Query<from c0 in Quarry.Comment, as: :post_comment>], preload: [author: a1]>

  # Nested entities
  iex> Quarry.build!(Quarry.Post, load: [comments: :user])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, preload: [comments: #Ecto.Query<from c0 in Quarry.Comment, as: :post_comment, join: u1 in assoc(c0, :user), as: :post_comment_user, preload: [user: u1]>]>

  # List of nested entities
  iex> Quarry.build!(Quarry.Post, load: [author: [:user, :posts]])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: a1 in assoc(p0, :author), as: :post_author, join: u2 in assoc(a1, :user), as: :post_author_user, preload: [author: [posts: #Ecto.Query<from p0 in Quarry.Post, as: :post_author_post>]], preload: [author: {a1, user: u2}]>

  # Use Quarry on nested has_many association
  iex> Quarry.build!(Quarry.Post, load: [comments: [filter: %{body: "comment"}, load: :user]])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, preload: [comments: #Ecto.Query<from c0 in Quarry.Comment, as: :post_comment, join: u1 in assoc(c0, :user), as: :post_comment_user, where: as(:post_comment).body == ^"comment", preload: [user: u1]>]>
  ```

  ### Sort examples

  ```elixir
  # Single field
  iex> Quarry.build!(Quarry.Post, sort: :title)
  #Ecto.Query<from p0 in Quarry.Post, as: :post, order_by: [asc: as(:post).title]>

  # Multiple fields
  iex> Quarry.build!(Quarry.Post, sort: [:title, :body])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, order_by: [asc: as(:post).title], order_by: [asc: as(:post).body]>

  # Nested fields
  iex> Quarry.build!(Quarry.Post, sort: [[:author, :publisher], :title, [:author, :user, :name]])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: a1 in assoc(p0, :author), as: :post_author, join: u2 in assoc(a1, :user), as: :post_author_user, order_by: [asc: as(:post_author).publisher], order_by: [asc: as(:post).title], order_by: [asc: as(:post_author_user).name]>

  # Descending sort
  iex> Quarry.build!(Quarry.Post, sort: [:title, desc: :body, desc: [:author, :publisher]])
  #Ecto.Query<from p0 in Quarry.Post, as: :post, join: a1 in assoc(p0, :author), as: :post_author, order_by: [asc: as(:post).title], order_by: [desc: as(:post).body], order_by: [desc: as(:post_author).publisher]>
  ```

  ### Limit example

  ```elixir
  iex> Quarry.build!(Quarry.Post, limit: 10)
  #Ecto.Query<from p0 in Quarry.Post, as: :post, limit: ^10>
  ```

  ### Offset example

  ```elixir
  iex> Quarry.build!(Quarry.Post, limit: 10, offset: 20)
  #Ecto.Query<from p0 in Quarry.Post, as: :post, limit: ^10, offset: ^20>
  ```

  """
  @spec build!(atom(), opts()) :: Ecto.Query.t()
  def build!(schema, opts \\ []) do
    {query, _errors} = build(schema, opts)
    query
  end

  @spec build(atom(), opts()) :: {Ecto.Query.t(), [error()]}
  def build(schema, opts \\ []) do
    default_opts = %{
      binding_prefix: nil,
      load_path: [],
      filter: %{},
      load: [],
      sort: [],
      limit: nil,
      offset: nil
    }

    opts = Map.merge(default_opts, Map.new(opts))

    {schema, []}
    |> From.build(opts.binding_prefix)
    |> Filter.build(opts.filter, opts.load_path)
    |> Load.build(opts.load, opts.load_path)
    |> Sort.build(opts.sort, opts.load_path)
    |> limit(opts.limit)
    |> offset(opts.offset)
  end

  defp limit({query, errors}, value) when is_integer(value),
    do: {Ecto.Query.limit(query, ^value), errors}

  defp limit(token, _limit), do: token

  defp offset({query, errors}, value) when is_integer(value),
    do: {Ecto.Query.offset(query, ^value), errors}

  defp offset(token, _value), do: token
end
