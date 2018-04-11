defmodule Spandex.Plug.UtilsTest do
  use ExUnit.Case, async: true

  alias Spandex.Plug.Utils

  describe "Utils.trace/2" do
    test "stores value in conn assigns" do
      %Plug.Conn{assigns: assigns} = Utils.trace(%Plug.Conn{}, true)
      assert assigns[:spandex_trace_request?] == true
    end
  end

  describe "Utils.trace?/1" do
    test "checks whenever request is being traced, when `true`" do
      %Plug.Conn{}
      |> Plug.Conn.assign(:spandex_trace_request?, true)
      |> Utils.trace?()
      |> assert
    end

    test "checks whenever request is being traced, when truthy" do
      %Plug.Conn{}
      |> Plug.Conn.assign(:spandex_trace_request?, "true")
      |> Utils.trace?()
      |> refute
    end

    test "checks whenever request is being traced, when nil" do
      %Plug.Conn{}
      |> Utils.trace?()
      |> refute
    end
  end
end
