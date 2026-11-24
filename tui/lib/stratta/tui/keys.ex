defmodule Stratta.TUI.Keys do
  @moduledoc """
  Turns raw terminal input into key events.

  `parse/2` takes the bytes of one read and the pending state from the last
  one (a bracketed paste can span reads) and returns `{keys, pending}`.
  """

  @paste_start "\e[200~"
  @paste_end "\e[201~"

  @sequences [
    {"\e[A", :up},
    {"\eOA", :up},
    {"\e[B", :down},
    {"\eOB", :down},
    {"\e[C", :right},
    {"\e[D", :left},
    {"\e[5~", :pgup},
    {"\e[6~", :pgdn},
    {"\e[H", :home},
    {"\e[1~", :home},
    {"\eOH", :home},
    {"\e[F", :end},
    {"\e[4~", :end},
    {"\eOF", :end},
    {"\e[3~", :delete},
    {"\e\r", :alt_enter},
    {"\e\n", :alt_enter},
    {"\r", :enter},
    {"\n", :enter},
    {"\d", :backspace},
    {"\b", :backspace},
    {"\t", :tab},
    {<<3>>, :ctrl_c},
    {<<4>>, :ctrl_d},
    {<<12>>, :ctrl_l},
    {<<19>>, :ctrl_s},
    {<<21>>, :ctrl_u},
    {<<23>>, :ctrl_w}
  ]

  def parse(data, pending \\ nil)

  def parse(data, {:paste, acc}) do
    case String.split(data, @paste_end, parts: 2) do
      [more] ->
        {[], {:paste, acc <> more}}

      [body, rest] ->
        {keys, pending} = parse(rest, nil)
        {[{:paste, acc <> body} | keys], pending}
    end
  end

  def parse(data, nil), do: scan(data, [])

  defp scan("", acc), do: {Enum.reverse(acc), nil}

  defp scan(@paste_start <> rest, acc) do
    case String.split(rest, @paste_end, parts: 2) do
      [body, rest] -> scan(rest, [{:paste, body} | acc])
      [body] -> {Enum.reverse(acc), {:paste, body}}
    end
  end

  for {bytes, key} <- @sequences do
    defp scan(unquote(bytes) <> rest, acc), do: scan(rest, [unquote(key) | acc])
  end

  # An escape sequence we don't use: skip through its final byte.
  defp scan("\e[" <> rest, acc), do: scan(skip_csi(rest), acc)
  defp scan("\e", acc), do: scan("", [:esc | acc])
  # Alt+key: ignore both bytes.
  defp scan("\e" <> rest, acc), do: scan(drop_grapheme(rest), acc)
  defp scan(<<c, rest::binary>>, acc) when c < 32, do: scan(rest, acc)

  defp scan(data, acc) do
    case String.next_grapheme(data) do
      {grapheme, rest} -> scan(rest, [{:char, grapheme} | acc])
      nil -> scan("", acc)
    end
  end

  defp skip_csi(<<c, rest::binary>>) when c in 0x40..0x7E, do: rest
  defp skip_csi(<<_c, rest::binary>>), do: skip_csi(rest)
  defp skip_csi(""), do: ""

  defp drop_grapheme(data) do
    case String.next_grapheme(data) do
      {_grapheme, rest} -> rest
      nil -> ""
    end
  end
end
