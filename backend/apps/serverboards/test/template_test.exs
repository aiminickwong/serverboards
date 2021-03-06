require Logger

defmodule Serverboards.TemplateTest do
  use ExUnit.Case
  @moduletag :capture_log

  import Serverboards.Utils.Template

  test "Simple template" do
    {:ok, txt} = render "This is an empty test", []
    assert txt == "This is an empty test"

    # keywords
    {:ok, txt} = render "This is a keyword {{test}}", test: "test"
    assert txt == "This is a keyword test"

    # dicts
    {:ok, txt} = render "This is a map {{test}}", %{ test: "test" }
    assert txt == "This is a map test"

    # dicts with string names, no atoms
    {:ok, txt} = render "This is a map string {{test}}", %{ "test" => "test" }
    assert txt == "This is a map string test"

    # Numbers
    {:ok, txt} = render "This is a number test: {{test}}", %{ "test" => 1 }
    assert txt == "This is a number test: 1"

    # Not found
    {:ok, txt} = render "This is a not found test: {{testx}}", %{ "test" => 1 }
    assert txt == "This is a not found test: {{testx}}"

    # nil
    {:ok, txt} = render "This is a nil test: {{testx}}", nil
    assert txt == "This is a nil test: {{testx}}"

  end

  test "Nested templates" do
    {:ok, txt} = render "This is a nested {{test.a}}", test: [a: "test", b: "notest"]
    assert txt == "This is a nested test"

    {:ok, txt} = render "This is a nested with no leaf {{test}}", test: [a: "test", b: "notest"]
    assert txt == "This is a nested with no leaf [a: \"test\", b: \"notest\"]"

    {:ok, txt} = render "This is a nested with no leaf var {{test.xxx}}", test: [a: "test", b: "notest"]
    assert txt == "This is a nested with no leaf var {{test.xxx}}"
  end
end
