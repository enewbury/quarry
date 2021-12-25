defmodule Quarry.UtilsTest do
  use ExUnit.Case
  doctest Quarry.Utils
  import Quarry.Utils

  describe "access_keyword/2" do
    test "can deep insert keyword values" do
      expected = [first: [new: [], second: []]]

      actual =
        put_in([first: [second: []]], [access_keyword(:first, []), access_keyword(:new, [])], [])

      assert expected == actual
    end
  end
end
