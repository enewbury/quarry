defmodule Quarry.UtilsTest do
  use ExUnit.Case
  doctest Quarry.Utils
  import Quarry.Utils

  describe "access_keyword/2" do
    test "can get deep keyword values" do
      path = [access_keyword(:first, []), access_keyword(:second, :default)]
      assert :hello = get_in([first: [second: :hello]], path)
      assert :default = get_in([first: []], path)
    end

    test "can deep insert keyword values" do
      expected = [first: [new: [], second: []]]
      path = [access_keyword(:first, []), access_keyword(:new, [])]
      assert expected == put_in([first: [second: []]], path, [])
    end

    test "can deep delete keyword values" do
      path = [access_keyword(:first, []), access_keyword(:second, :default)]
      assert {:hello, [first: []]} = pop_in([first: [second: :hello]], path)
      assert {:default, [first: []]} = pop_in([first: []], path)
      assert {:default, [first: []]} = pop_in([], path)
    end
  end
end
