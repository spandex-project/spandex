defmodule Spandex.Datadog.SpanTest do
  use ExUnit.Case, async: true

  alias Spandex.Datadog.Span

  describe "Span.new/1" do
    test "initialize struct with defaults" do
      span =
        Span.new(%Span{}, env: "test", service: :spandex_test, services: [spandex_test: :job])

      refute is_nil(span.id)
      refute is_nil(span.start)
      assert span.env == "test"
      assert span.service == :spandex_test
      assert span.resource == "unknown"
      assert span.type == :job
    end

    test "fallbacks for resource from name" do
      assert Span.new(%Span{name: "ecto.query"}).resource == "ecto.query"
    end

    test "sets unknown type when service is not configured" do
      assert Span.new(%Span{service: :phoenix}).type == "unknown"
    end

    test "merges with given data" do
      started_at = Spandex.Datadog.Utils.now()

      span =
        Span.new(%Span{
          id: 666,
          start: started_at,
          env: "pre-prod",
          service: :phoenix,
          resource: "/dashboard/users",
          type: :http,
          trace_id: 999,
          parent_id: 777
        })

      assert span.id == 666
      assert span.start == started_at
      assert span.parent_id == 777
      assert span.trace_id == 999
      assert span.env == "pre-prod"
      assert span.service == :phoenix
      assert span.type == :http
      assert span.resource == "/dashboard/users"
    end
  end

  describe "Span.stop/1" do
    test "sets new completion_time with now()" do
      %Span{completion_time: finished_at} = Span.stop(%Span{})
      compare = Spandex.Datadog.Utils.now()

      # it's time since epoch in nanoseconds, brief check for 10 milliseconds
      # in test env, as everything is evaluated on the fly, usually it's 10 microseconds
      assert_in_delta compare, finished_at, 10_000_000
    end

    test "doesn't change completion time if it's present" do
      finished_at = 1
      %Span{completion_time: compare} = Span.stop(%Span{completion_time: finished_at})

      assert compare == finished_at
    end
  end

  describe "Span.update/2" do
    test "updates span with given attributes" do
      span = Span.new()

      params = %{
        name: "test_update",
        service: :phoenix,
        resource: "sql query",
        env: "prod",
        trace_id: 1,
        parent_id: 2,
        id: 3,
        meta: %{
          foo: :bar,
          baz: :kaz
        }
      }

      ids_keys = [:id, :trace_id, :parent_id]
      field_keys = params |> Map.drop(ids_keys) |> Map.keys()

      # sanity check
      Enum.each(ids_keys ++ field_keys, fn key ->
        assert Map.get(span, key) != params[key]
      end)

      compare = Span.update(span, params)

      Enum.each(ids_keys, fn key ->
        assert Map.fetch!(compare, key) == Map.fetch!(span, key)
        assert Map.fetch!(compare, key) != params[key]
      end)

      Enum.each(field_keys, fn key ->
        assert Map.fetch!(compare, key) == params[key]
        assert Map.fetch!(compare, key) != Map.fetch!(span, key)
      end)
    end
  end

  describe "Span.child_of/3" do
    test "creates new span based on parent span" do
      parent = %Span{
        id: 1,
        name: "parent",
        resource: "sql.query",
        service: :bar,
        parent_id: 2,
        trace_id: 3,
        start: 5,
        env: "prod"
      }

      span = Span.child_of(parent, "child")

      assert span.id != parent.id
      refute is_nil(span.id)
      assert span.start != parent.start
      assert span.parent_id != parent.parent_id

      assert span.name == "child"
      assert span.trace_id == parent.trace_id
      assert span.parent_id == parent.id
      assert span.env == parent.env
      assert span.resource == parent.resource
      assert span.service == parent.service
    end
  end
end
