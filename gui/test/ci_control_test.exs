defmodule CiControl.GuiFailingTest do
  use ExUnit.Case

  test "seeded by the CI control" do
    flunk("seeded by the CI control")
  end
end
