defmodule Quarry.Select do
  @moduledoc false
  require Ecto.Query
  require Quarry.Fragments

  alias Quarry.{Join, From}

  @type select :: atom() | [atom() | [atom()]] | select_map()
  @type select_map :: %{field: [atom()], as: atom(), function: atom() | function_with_args()}
  @type function_with_args :: %{function: atom(), args: keyword()}

  @spec build({Ecto.Query.t(), [Quarry.error()]}, select(), [atom()]) ::
          {Ecto.Query.t(), [Quarry.error()]}
  def build({query, errors}, select_params, load_path \\ []) do
    root_binding = From.get_root_binding(query)
    schema = From.get_root_schema(query)

    select_fields({query, errors}, select_params,
      binding: root_binding,
      schema: schema,
      path: [],
      load_path: load_path
    )
  end

  defp select_fields(acc, select_params, state) do
    select_params
    |> List.wrap()
    |> Enum.reduce(acc, &maybe_select_field(&2, &1, state))
  end

  defp maybe_select_field({query, errors}, field_name, state) when is_atom(field_name) do
    fields = state[:schema].__schema__(:fields)

    if field_name in fields do
      select_field({query, errors}, field_name, state)
    else
      {query, [build_error(field_name, state) | errors]}
    end
  end

  defp maybe_select_field({query, errors}, [field_name], state) when is_atom(field_name) do
    # Handle single field in list format like [:author_id]
    maybe_select_field({query, errors}, field_name, state)
  end

  defp maybe_select_field({query, errors}, [association, field_name], state) when is_atom(association) and is_atom(field_name) do
    # Handle nested field like [:author, :id]
    associations = state[:schema].__schema__(:associations)

    if association in associations do
      select_nested_field({query, errors}, association, field_name, state)
    else
      {query, [build_error(association, state) | errors]}
    end
  end

  defp maybe_select_field({query, errors}, [association | rest], state) when is_atom(association) and is_list(rest) do
    # Handle deeply nested field like [:author, :user, :name]
    associations = state[:schema].__schema__(:associations)

    if association in associations do
      child_schema = state[:schema].__schema__(:association, association).related
      child_state = Keyword.put(state, :schema, child_schema)
      child_state = Keyword.update!(child_state, :path, &[association | &1])

      maybe_select_field({query, errors}, rest, child_state)
    else
      {query, [build_error(association, state) | errors]}
    end
  end

  defp maybe_select_field({query, errors}, %{field: field_path, as: as_name, function: %{function: function_atom, args: args}}, state) when is_atom(function_atom) do
    # Handle function with args like %{field: [:age], as: :age_bucket, function: %{function: :width_bucket, args: [start: 0, end: 100, num_buckets: 10]}}
    select_function({query, errors}, field_path, as_name, function_atom, state, args)
  end

  defp maybe_select_field({query, errors}, %{field: field_path, as: as_name, function: function_atom}, state) when is_atom(function_atom) do
    # Handle function with field path like %{field: [:author, :name], as: :author_name_upper, function: :upper}
    select_function({query, errors}, field_path, as_name, function_atom, state)
  end

  defp maybe_select_field({query, errors}, %{field: _field_path, function: _function_atom}, state) do
    # Handle function without required :as option
    {query, [build_function_error("Missing required :as option", state) | errors]}
  end

  defp maybe_select_field({query, errors}, %{as: _as_name, function: _function_atom}, state) do
    # Handle function without required :field option
    {query, [build_function_error("Missing required :field option", state) | errors]}
  end

  defp maybe_select_field({query, errors}, %{field: _field_path, as: _as_name, function: %{function: _function_atom}}, state) do
    # Handle function object without required :args option
    {query, [build_function_error("Function object requires :args option", state) | errors]}
  end

  defp maybe_select_field({query, errors}, %{field: _field_path, as: _as_name, function: %{args: _args}}, state) do
    # Handle function object without required :function option
    {query, [build_function_error("Function object requires :function option", state) | errors]}
  end

  defp maybe_select_field({query, errors}, field_name, state) do
    {query, [build_error(field_name, state) | errors]}
  end

  defp build_error(field_name, state) do
    field_name_str = if is_list(field_name), do: inspect(field_name), else: to_string(field_name)

    %{
      type: :select,
      path: Enum.reverse([field_name | state[:path]]),
      load_path: Enum.reverse(state[:load_path]),
      message: "Quarry couldn't find field \"#{field_name_str}\" on Ecto schema \"#{state[:schema]}\""
    }
  end

  defp build_function_error(message, state) do
    %{
      type: :select,
      path: Enum.reverse(state[:path]),
      load_path: Enum.reverse(state[:load_path]),
      message: message
    }
  end

  defp select_field({query, errors}, field_name, state) do
    {query, join_binding} = Join.join_dependencies(query, state[:binding], state[:path])

    # Check if query already has a select clause
    query = if has_select?(query) do
      Ecto.Query.select_merge(query, %{^field_name => field(as(^join_binding), ^field_name)})
    else
      Ecto.Query.select(query, %{^field_name => field(as(^join_binding), ^field_name)})
    end

    {query, errors}
  end

  defp select_nested_field({query, errors}, association, field_name, state) do
    child_schema = state[:schema].__schema__(:association, association).related
    child_fields = child_schema.__schema__(:fields)

    if field_name in child_fields do
      {query, join_binding} = Join.join_dependencies(query, state[:binding], [association | state[:path]])

      # Check if query already has a select clause
      query = if has_select?(query) do
        Ecto.Query.select_merge(query, %{^field_name => field(as(^join_binding), ^field_name)})
      else
        Ecto.Query.select(query, %{^field_name => field(as(^join_binding), ^field_name)})
      end

      {query, errors}
    else
      {query, [build_error(field_name, state) | errors]}
    end
  end

  defp select_function({query, errors}, field_path, as_name, function_atom, state, args \\ []) do
    # Process the field path to get the final field and schema
    case process_field_path(field_path, state) do
      {:ok, final_field, final_schema, final_path} ->
        # Validate that the field exists
        fields = final_schema.__schema__(:fields)
        if final_field in fields do
          # Get the join binding for the field path
          {query, join_binding} = Join.join_dependencies(query, state[:binding], final_path)

          query = if has_select?(query) do
            query
          else
            Ecto.Query.select(query, %{})
          end

          # Create the function expression based on the atom
          query = case function_atom do
            :upper ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("UPPER(?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :lower ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("LOWER(?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :concat ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("CONCAT(?, ' - ', ?)", field(as(^join_binding), ^final_field), field(as(^join_binding), ^final_field)), ^as_name)})
            :date_trunc_day ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("date_trunc('day', ?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :date_trunc_week ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("date_trunc('week', ?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :date_trunc_month ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("date_trunc('month', ?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :date_trunc_year ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("date_trunc('year', ?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :count ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("COUNT(?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :sum ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("SUM(?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :average ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("AVG(?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :median ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :percentile ->
              percentile_value = Keyword.get(args, :value, 0.5)
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("PERCENTILE_CONT(?) WITHIN GROUP (ORDER BY ?)", ^percentile_value, field(as(^join_binding), ^final_field)), ^as_name)})
            :max ->
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("MAX(?)", field(as(^join_binding), ^final_field)), ^as_name)})
            :width_bucket ->
              start_val = Keyword.get(args, :start)
              end_val = Keyword.get(args, :end)
              num_buckets = Keyword.get(args, :num_buckets)
              Ecto.Query.select_merge(query, %{^as_name => selected_as(fragment("WIDTH_BUCKET(?, ?, ?, ?)", field(as(^join_binding), ^final_field), ^start_val, ^end_val, ^num_buckets), ^as_name)})
            _ ->
              # For unsupported functions
              raise ArgumentError, "Unsupported function '#{function_atom}'. Use one of: :upper, :lower, :concat, :date_trunc_day, :date_trunc_week, :date_trunc_month, :date_trunc_year, :count, :sum, :average, :median, :p90, :p95, :percentile, :max, :width_bucket"
          end

          {query, errors}
        else
          {query, [build_error(final_field, state) | errors]}
        end
      {:error, error_field, error_state} ->
        {query, [build_error(error_field, error_state) | errors]}
    end
  end


  defp process_field_path([field_name], state) when is_atom(field_name) do
    fields = state[:schema].__schema__(:fields)
    if field_name in fields do
      {:ok, field_name, state[:schema], state[:path]}
    else
      # Field doesn't exist on current schema, check if it exists through associations
      associations = state[:schema].__schema__(:associations)
      case find_field_through_associations(field_name, associations, state) do
        {:ok, schema, path} -> {:ok, field_name, schema, path}
        :error -> {:error, field_name}
      end
    end
  end

  defp process_field_path([association, field_name], state) when is_atom(association) and is_atom(field_name) do
    associations = state[:schema].__schema__(:associations)

    if association in associations do
      child_schema = state[:schema].__schema__(:association, association).related
      child_fields = child_schema.__schema__(:fields)

      if field_name in child_fields do
        # Field exists directly on the associated schema
        {:ok, field_name, child_schema, [association | state[:path]]}
      else
        # Field doesn't exist on the associated schema - this is an error
        # We don't automatically search through nested associations for two-level paths
        {:error, field_name, state}
      end
    else
      {:error, association, state}
    end
  end

  defp process_field_path([association | rest], state) when is_atom(association) and is_list(rest) do
    associations = state[:schema].__schema__(:associations)

    if association in associations do
      child_schema = state[:schema].__schema__(:association, association).related
      child_state = Keyword.put(state, :schema, child_schema)
      child_state = Keyword.update!(child_state, :path, &[association | &1])

      process_field_path(rest, child_state)
    else
      {:error, association, state}
    end
  end

  defp process_field_path(field_path, state) do
    {:error, field_path, state}
  end

  defp find_field_through_associations(field_name, associations, state) do
    Enum.find_value(associations, :error, fn association ->
      child_schema = state[:schema].__schema__(:association, association).related
      child_fields = child_schema.__schema__(:fields)

      if field_name in child_fields do
        {:ok, child_schema, [association | state[:path]]}
      else
        # Check if the field exists through nested associations
        child_associations = child_schema.__schema__(:associations)
        child_state = Keyword.put(state, :schema, child_schema)
        child_state = Keyword.update!(child_state, :path, &[association | &1])

        case find_field_through_associations(field_name, child_associations, child_state) do
          {:ok, schema, path} -> {:ok, schema, path}
          :error -> nil
        end
      end
    end)
  end

  defp has_select?(%Ecto.Query{select: nil}), do: false
  defp has_select?(%Ecto.Query{}), do: true

end
