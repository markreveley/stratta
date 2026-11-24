defmodule Stratta.TUI.KeysTest do
  use ExUnit.Case, async: true

  alias Stratta.TUI.Keys

  test "text, control keys and escape sequences" do
    assert {[{:char, "h"}, {:char, "é"}, :enter], nil} = Keys.parse("hé\r")
    assert {[:up, :pgdn, :end, :alt_enter, :backspace], nil} = Keys.parse("\e[A\e[6~\e[F\e\r\d")
    assert {[:ctrl_c, :ctrl_s, :ctrl_d], nil} = Keys.parse(<<3, 19, 4>>)
    assert {[:esc], nil} = Keys.parse("\e")
  end

  test "unknown sequences are skipped without eating what follows" do
    assert {[{:char, "x"}], nil} = Keys.parse("\e[1;5Rx")
    assert {[{:char, "y"}], nil} = Keys.parse("\ebx" |> String.replace("x", "y"))
  end

  test "a bracketed paste is one key, even across reads" do
    assert {[{:paste, "a\nb"}, {:char, "!"}], nil} = Keys.parse("\e[200~a\nb\e[201~!")
    assert {[{:char, "x"}], {:paste, "first "}} = Keys.parse("x\e[200~first ")
    assert {[], {:paste, "first second "}} = Keys.parse("second ", {:paste, "first "})
    assert {[{:paste, "first second end"}, :enter], nil} = Keys.parse("end\e[201~\r", {:paste, "first second "})
  end
end
