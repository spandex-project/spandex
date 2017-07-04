defmodule Spandex.Datadog.SpanTest do
  use ExUnit.Case, async: true

  alias Spandex.Datadog.Span

  describe "Span.new/1" do
    test "initialize struct with defaults" do
      span = Span.new(%{})

      assert not is_nil(span.id)
      assert span.env == "test"
      assert span.service == :spandex_test
      assert span.resource == "unknown"
      assert span.type == :web
    end

    test "fallbacks for resource from name" do
      assert Span.new(%{name: "ecto.query"}).resource == "ecto.query"
    end

    test "fallbacks for type from service in config" do
      assert Span.new(%{service: :ecto}).type == :sql
    end

    test "sets unknown type when service is not configured" do
      assert Span.new(%{service: :phoenix}).type == "unknown"
    end

    test "merges with given data" do
      %Span{id: id, parent_id: pid, trace_id: tid, env: env, service: service, type: type, resource: resource} = Span.new(%{
        id: 666,
        env: "pre-prod",
        service: :phoenix,
        resource: "/dashboard/users",
        type: :http,
        trace_id: 999,
        parent_id: 777,
      })

      assert id == 666
      assert pid == 777
      assert tid == 999
      assert env == "pre-prod"
      assert service == :phoenix
      assert type == :http
      assert resource == "/dashboard/users"
    end
  end
end
