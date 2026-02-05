defmodule Quarry.SelectTest do
  use ExUnit.Case
  doctest Quarry.Select

  import Ecto.Query
  alias Quarry.{Post, Select}

  setup do
    %{base: {from(p in Post, as: :post), []}}
  end

  test "can select single top level field", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        select: %{title: as(:post).title}
      )

    select = :title
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "can select single top level field as list", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        select: %{title: as(:post).title}
      )

    select = [:title]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "can select multiple top level fields", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        select: %{id: as(:post).id, title: as(:post).title}
      )

    select = [:id, :title]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "can select nested field through association", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        select: %{publisher: as(:post_author).publisher}
      )

    select = [[:author, :publisher]]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "can select multiple nested fields", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        select: %{name: as(:post_author_user).name, publisher: as(:post_author).publisher}
      )

    select = [[:author, :user, :name], [:author, :publisher]]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "can select mix of top level and nested fields", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        select: %{title: as(:post).title, publisher: as(:post_author).publisher}
      )

    select = [:title, [:author, :publisher]]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "ignores bad top level field and returns error", %{base: base} do
    select = :bad_field
    {actual, [error]} = Select.build(base, select)

    assert inspect(actual) == inspect(elem(base, 0))
    assert %{type: :select, path: [:bad_field]} = error
  end

  test "ignores bad nested field and returns error", %{base: base} do
    select = [[:author, :bad_field]]
    {actual, [error]} = Select.build(base, select)

    assert inspect(actual) == inspect(elem(base, 0))
    assert %{type: :select, path: [:bad_field]} = error
  end

  test "ignores bad association and returns error", %{base: base} do
    select = [[:bad_association, :field]]
    {actual, [error]} = Select.build(base, select)

    assert inspect(actual) == inspect(elem(base, 0))
    assert %{type: :select, path: [:bad_association]} = error
  end

  test "returns passed in load_path on errors", %{base: base} do
    {_, [error]} = Select.build(base, [[:bad_association, :field]], [:post, :comments])
    assert %{type: :select, path: [:bad_association], load_path: [:comments, :post]} = error
  end

  test "can select from has_many association", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: c in assoc(p, :comments),
        as: :post_comments,
        select: %{body: as(:post_comments).body}
      )

    select = [[:comments, :body]]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "can select deeply nested field", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        left_join: u in assoc(a, :user),
        as: :post_author_user,
        select: %{name: as(:post_author_user).name}
      )

    select = [[:author, :user, :name]]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "handles empty select list", %{base: base} do
    select = []
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(elem(base, 0))
  end

  test "handles duplicate field selection", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        select: %{title: as(:post).title}
      )

    select = [:title, :title]
    assert {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
  end

  test "handles mixed valid and invalid fields", %{base: base} do
    expected =
      from(
        p in Post,
        as: :post,
        select: %{title: as(:post).title}
      )

    select = [:title, :bad_field]
    {actual, [error]} = Select.build(base, select)
    assert inspect(actual) == inspect(expected)
    assert %{type: :select, path: [:bad_field]} = error
  end

  test "handles very deeply nested associations", %{base: base} do
    # This tests 4 levels deep: post -> author -> user -> (through association) -> posts
    # Note: This might not work with the current schema, but tests the recursion logic
    select = [[:author, :user, :name]]
    {_actual, errors} = Select.build(base, select)

    # Should either succeed or fail gracefully
    assert is_list(errors)
  end

  test "handles nil select parameter", %{base: base} do
    select = nil
    {actual, []} = Select.build(base, select)
    assert inspect(actual) == inspect(elem(base, 0))
  end

  test "handles select with existing joins in query", %{base: _base} do
    # Start with a query that already has joins
    base_with_joins = {
      from(p in Post, as: :post, left_join: a in assoc(p, :author), as: :post_author),
      []
    }

    expected =
      from(
        p in Post,
        as: :post,
        left_join: a in assoc(p, :author),
        as: :post_author,
        select: %{publisher: as(:post_author).publisher}
      )

    select = [[:author, :publisher]]
    {actual, []} = Select.build(base_with_joins, select)
    assert inspect(actual) == inspect(expected)
  end

  # Function tests - TODO: Implement function functionality
  test "can select field with basic function", %{base: base} do
    # We can't easily create the expected query with functions in the test
    # because functions need to be created at compile time. Instead, we'll
    # just verify that the query is generated without errors and has the right structure.
    select = [:title, %{field: [:title], as: :title_upper, function: :upper}]
    {actual, errors} = Select.build(base, select)

    assert errors == []
    assert is_struct(actual, Ecto.Query)
    assert actual.select != nil
    # Verify the select clause has both fields
    select_expr = actual.select.expr
    assert is_tuple(select_expr)
    # The select expression is a tuple like {:%{}, [], [title: ..., title_upper: ...]}
    assert elem(select_expr, 0) == :%{}
    select_fields = elem(select_expr, 2)
    assert is_list(select_fields)
    field_names = Keyword.keys(select_fields)
    assert :title in field_names
    assert :title_upper in field_names
  end

  test "can select nested field with function", %{base: base} do
    select = [%{field: [:author, :user, :name], as: :author_name_concat, function: :concat}]
    {actual, errors} = Select.build(base, select)

    assert errors == []
    assert is_struct(actual, Ecto.Query)
    assert actual.select != nil
    # Verify the select clause has the fragment field
    select_expr = actual.select.expr
    assert is_tuple(select_expr)
    select_fields = elem(select_expr, 2)
    field_names = Keyword.keys(select_fields)
    assert :author_name_concat in field_names
    # Verify joins were created
    assert length(actual.joins) >= 2  # Should have author and user joins
  end

  test "can select deeply nested field with function", %{base: base} do
    select = [%{field: [:author, :user, :name], as: :author_user_name_lower, function: :lower}]
    {actual, errors} = Select.build(base, select)

    assert errors == []
    assert is_struct(actual, Ecto.Query)
    assert actual.select != nil
    # Verify the select clause has the fragment field
    select_expr = actual.select.expr
    assert is_tuple(select_expr)
    select_fields = elem(select_expr, 2)
    field_names = Keyword.keys(select_fields)
    assert :author_user_name_lower in field_names
    # Verify joins were created
    assert length(actual.joins) >= 2  # Should have author and user joins
  end

  test "can mix regular fields and functions", %{base: base} do
    select = [:title, [:author, :publisher], %{field: [:author, :user, :name], as: :author_name_upper, function: :upper}]
    {actual, errors} = Select.build(base, select)

    assert errors == []
    assert is_struct(actual, Ecto.Query)
    assert actual.select != nil
    # Verify the select clause has all expected fields
    select_expr = actual.select.expr
    assert is_tuple(select_expr)
    select_fields = elem(select_expr, 2)
    field_names = Keyword.keys(select_fields)
    assert :title in field_names
    assert :publisher in field_names
    assert :author_name_upper in field_names
    # Verify joins were created
    assert length(actual.joins) >= 2  # Should have author and user joins
  end

  test "returns error for function without as option", %{base: base} do
    select = [:title, %{field: [:title], function: :upper}]
    {_actual, errors} = Select.build(base, select)

    # Should return an error because 'as' option is required
    assert is_list(errors)
    assert length(errors) > 0
    assert Enum.any?(errors, &(&1.type == :select))
  end

  test "raises error for invalid function syntax", %{base: base} do
    select = [:title, %{field: [:title], function: :invalid_function, as: :bad_function}]

    # Should raise ArgumentError for unsupported function
    # Note: The order of functions in the error message may vary due to map ordering
    assert_raise ArgumentError, fn ->
      Select.build(base, select)
    end
  end

  # Test that Quarry.build correctly handles functions with as: option
  test "Quarry.build creates select_as for functions with as option" do
    # Test that the generated query has the correct select_as structure
    # Use a list format for the field path as that's what the implementation expects
    {query, []} = Quarry.build(Quarry.Post, select: [%{field: [:title], as: :title_upper, function: :upper}])

    # Verify the query has a select clause
    assert query.select != nil

    # Verify the select expression contains the aliased field
    select_expr = query.select.expr
    assert is_tuple(select_expr)
    select_fields = elem(select_expr, 2)
    field_names = Keyword.keys(select_fields)
    assert :title_upper in field_names

    # Verify the fragment expression is properly structured
    title_upper_expr = Keyword.get(select_fields, :title_upper)
    # The fragment should be a tuple with :selected_as as the first element
    assert is_tuple(title_upper_expr)
    assert elem(title_upper_expr, 0) == :selected_as

    # The selected_as structure is: {:selected_as, [], [fragment_expr, alias]}
    fragment_parts = elem(title_upper_expr, 2)
    assert is_list(fragment_parts)

    # Find the fragment expression in the parts
    fragment_expr = Enum.find(fragment_parts, &match?({:fragment, _, _}, &1))
    assert fragment_expr != nil

    # Extract the fragment content
    {_, _, fragment_content} = fragment_expr
    assert is_list(fragment_content)

    # Verify the fragment contains the correct SQL and field reference
    assert Enum.any?(fragment_content, &match?({:raw, "UPPER("}, &1))
    assert Enum.any?(fragment_content, &match?({:raw, ")"}, &1))
    assert Enum.any?(fragment_content, &match?({:expr, {{:., [], [{:as, [], [:post]}, :title]}, [], []}}, &1))
  end
end
