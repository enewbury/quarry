defmodule Quarry.Utils do
  @moduledoc false

  def access_keyword(key, default \\ nil) do
    fn
      :get, data, next ->
        next.(Keyword.get(data, key, default))

      :get_and_update, data, next ->
        value = Keyword.get(data, key, default)

        case next.(value) do
          {get, update} -> {get, Keyword.put(data, key, update)}
          :pop -> {value, Keyword.delete(data, key)}
        end
    end
  end
end
