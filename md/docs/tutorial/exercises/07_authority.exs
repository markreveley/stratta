# Lab 7: rules, grants and a decision record    (tutorial sections 21, 28, 29)
#
# Three small pieces of the planned control plane, none of which exists in
# Stratta yet:
#
#   Lab.Policy      rules that answer a request: first match wins, default ask
#   Lab.Authority   a behaviour with one question, and a local implementation
#   Lab.Answer      an automatic answer that names its rule and its grant
#
# Run:  elixir exercises/07_authority.exs

ExUnit.start()

defmodule Lab.Policy do
  @moduledoc """
  A rule is `%{name: string, match: (request -> boolean), answer: :allow | :deny | :ask}`.
  A request is a map with at least `:tool` and, for file tools, `:path`.
  """

  @doc """
  The first rule that matches answers. No match is `{:ask, "default"}`.
  A rule that raises answers nothing for anyone: `{:ask, "rule-error"}`.
  """
  def decide(_rules, _request), do: raise("not implemented")

  @doc "True when `path`, resolved against `cwd`, is `cwd` itself or below it."
  def inside?(_path, _cwd), do: raise("not implemented")

  @doc "The three rules the policy plan ships, in the order they are tried."
  def shipped(cwd) do
    [
      %{name: "deny-writes-outside", answer: :deny, match: &(&1.tool == :write and not inside?(&1.path, cwd))},
      %{name: "allow-reads-inside", answer: :allow, match: &(&1.tool == :read and inside?(&1.path, cwd))},
      %{name: "ask-shell", answer: :ask, match: &(&1.tool == :shell)}
    ]
  end
end

defmodule Lab.Authority do
  @moduledoc "One question: may this grant answer this request this way?"
  @callback may?(verifier :: term, grant :: map, request :: map, answer :: :allow | :deny) :: boolean
end

defmodule Lab.Authority.Local do
  @moduledoc """
  The cheap implementation: a secret the daemon keeps in a file only its
  owner can read. A grant must carry the secret, and it may be narrowed.

  A grant: `%{id, secret, holder, tools, thread, expires_at}` where
  `tools` is `:any` or a list, `thread` is `:any` or one thread id, and
  `expires_at` is `:never` or a time in seconds.
  """
  @behaviour Lab.Authority

  defstruct [:secret]

  @doc "The root grant: held by the operator, good for everything, for ever."
  def issue(%__MODULE__{secret: secret}),
    do: %{id: "g", secret: secret, holder: :operator, tools: :any, thread: :any, expires_at: :never}

  @doc """
  A weaker grant made from `grant`. Every restriction is intersected with
  what the parent already allowed, so the child can never do more.
  Restrictions: `:holder`, `:tools`, `:thread`, `:expires_at`.
  """
  def narrow(_grant, _restrictions), do: raise("not implemented")

  # True only if: the grant carries the verifier's secret; its holder is not
  # the thread that raised the request; and its tools, thread and expiry
  # all cover the request.
  @impl true
  def may?(_verifier, _grant, _request, _answer), do: raise("not implemented")
end

defmodule Lab.Answer do
  @doc """
  Tries to answer without a person. `{:ok, record}` when a rule answers and
  the grant covers it; otherwise `{:ask, reason}`. The record is
  `%{request: id, answer: answer, rule: name, grant: grant_id, at: now}`.
  """
  def run(_rules, _verifier, _grant, _request), do: raise("not implemented")
end

defmodule Lab.AuthorityTest do
  use ExUnit.Case

  alias Lab.{Answer, Policy}
  alias Lab.Authority.Local

  @cwd "/work/project"
  @verifier %Local{secret: "s3cret"}

  defp request(fields), do: Map.merge(%{id: "2a", thread: "t2", now: 100}, Map.new(fields))

  describe "policy" do
    test "the three shipped rules" do
      rules = Policy.shipped(@cwd)
      assert Policy.decide(rules, request(tool: :read, path: "lib/a.ex")) == {:allow, "allow-reads-inside"}
      assert Policy.decide(rules, request(tool: :shell, command: "mix test")) == {:ask, "ask-shell"}
      assert Policy.decide(rules, request(tool: :write, path: "/etc/hosts")) == {:deny, "deny-writes-outside"}
    end

    test "a path is resolved before it is judged" do
      assert Policy.inside?("lib/a.ex", @cwd)
      assert Policy.inside?("/work/project", @cwd)
      refute Policy.inside?("../other/a.ex", @cwd)
      refute Policy.inside?("lib/../../project-evil/a.ex", @cwd)
      refute Policy.inside?("/work/project-evil/a.ex", @cwd)
    end

    test "what no rule covers is asked" do
      rules = Policy.shipped(@cwd)
      assert Policy.decide(rules, request(tool: :write, path: "lib/a.ex")) == {:ask, "default"}
      assert Policy.decide(rules, request(tool: :read, path: "/etc/passwd")) == {:ask, "default"}
      assert Policy.decide([], request(tool: :read, path: "lib/a.ex")) == {:ask, "default"}
    end

    test "the first match wins, so a later allow cannot widen an earlier deny" do
      rules = Policy.shipped(@cwd) ++ [%{name: "always-allow-writes", answer: :allow, match: &(&1.tool == :write)}]
      assert Policy.decide(rules, request(tool: :write, path: "/etc/hosts")) == {:deny, "deny-writes-outside"}
      assert Policy.decide(rules, request(tool: :write, path: "lib/a.ex")) == {:allow, "always-allow-writes"}
    end

    test "a broken rule set answers nothing" do
      broken = [%{name: "broken", answer: :allow, match: fn request -> request.no_such_field end}]
      assert Policy.decide(broken ++ Policy.shipped(@cwd), request(tool: :read, path: "lib/a.ex")) ==
               {:ask, "rule-error"}
    end
  end

  describe "authority" do
    test "the root grant answers; a forged one does not" do
      root = Local.issue(@verifier)
      assert Local.may?(@verifier, root, request(tool: :read), :allow)
      refute Local.may?(@verifier, %{root | secret: "guess"}, request(tool: :read), :allow)
    end

    test "a narrowed grant covers only what it names" do
      grant = Local.narrow(Local.issue(@verifier), tools: [:read], thread: "t2", expires_at: 200)
      assert Local.may?(@verifier, grant, request(tool: :read), :allow)
      refute Local.may?(@verifier, grant, request(tool: :shell), :allow)
      refute Local.may?(@verifier, grant, request(tool: :read, thread: "t3"), :allow)
      refute Local.may?(@verifier, grant, request(tool: :read, now: 200), :allow)
    end

    test "narrowing again cannot give back what was taken away" do
      reads = Local.narrow(Local.issue(@verifier), tools: [:read], thread: "t2")
      wider = Local.narrow(reads, tools: [:read, :shell], thread: "t3")
      refute Local.may?(@verifier, wider, request(tool: :shell), :allow)
      refute Local.may?(@verifier, wider, request(tool: :read, thread: "t3"), :allow)
      refute Local.may?(@verifier, wider, request(tool: :read, thread: "t2"), :allow)
    end

    test "a thread cannot answer its own request" do
      held = Local.narrow(Local.issue(@verifier), holder: "t2")
      refute Local.may?(@verifier, held, request(tool: :read, thread: "t2"), :allow)
      assert Local.may?(@verifier, held, request(tool: :read, thread: "t3"), :allow)
    end

    test "property: whatever a narrowed grant may answer, its parent may answer too" do
      :rand.seed(:exsss, {1, 2, 3})
      root = Local.issue(@verifier)
      pick = fn list -> Enum.random(list) end
      tools = [:read, :write, :shell]

      for _ <- 1..500 do
        restrict = fn ->
          [
            tools: pick.([:any, [:read], [:read, :write], [:shell], []]),
            thread: pick.([:any, "t1", "t2"]),
            expires_at: pick.([:never, 50, 150]),
            holder: pick.([:operator, "t1", "t2"])
          ]
        end

        parent = Local.narrow(root, restrict.())
        child = Local.narrow(parent, restrict.())
        req = request(tool: pick.(tools), thread: pick.(["t1", "t2", "t3"]), now: pick.([10, 100, 1000]))

        # The holder is who carries the grant, not a limit on it, so compare like with like.
        parent = %{parent | holder: child.holder}

        if Local.may?(@verifier, child, req, :allow) do
          assert Local.may?(@verifier, parent, req, :allow)
        end
      end
    end
  end

  describe "an automatic answer" do
    test "names the rule that fired and the grant it was given under" do
      grant = Local.narrow(Local.issue(@verifier), tools: [:read])

      assert {:ok, record} =
               Answer.run(Policy.shipped(@cwd), @verifier, grant, request(tool: :read, path: "lib/a.ex"))

      assert record == %{request: "2a", answer: :allow, rule: "allow-reads-inside", grant: grant.id, at: 100}
    end

    test "a rule without authority behind it only asks" do
      forged = %{Local.issue(@verifier) | secret: "guess"}

      assert Answer.run(Policy.shipped(@cwd), @verifier, forged, request(tool: :read, path: "lib/a.ex")) ==
               {:ask, "no-authority"}
    end

    test "what the rules leave open still reaches a person" do
      root = Local.issue(@verifier)
      assert Answer.run(Policy.shipped(@cwd), @verifier, root, request(tool: :shell)) == {:ask, "ask-shell"}
    end
  end
end
