defmodule Spandex.Test.SpandexTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Spandex.Test.Util

  alias Spandex.{
    Span,
    SpanContext,
    Trace
  }

  defmodule PdictSender do
    def send_trace(trace, _opts \\ []) do
      Process.put(:trace, trace)
    end
  end

  @base_opts [
    adapter: Spandex.TestAdapter,
    strategy: Spandex.Strategy.Pdict,
    env: "test"
  ]

  @span_opts [
    service: :test_service,
    resource: "test_resource"
  ]

  @runtime_error %RuntimeError{message: "something went wrong"}
  @fake_stacktrace [:frame1, :frame2]

  describe "Spandex.start_trace/2" do
    test "creates a new Trace with a root Span with the given name" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert %Span{name: "root_span"} = Spandex.current_span(@base_opts)
    end

    test "returns an error if there is already a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)

      log =
        capture_log(fn ->
          assert {:error, :trace_running} = Spandex.start_trace("duplicate_span", opts)
        end)

      assert String.contains?(log, "[error] Tried to start a trace over top of another trace.")
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.start_trace("root_span", :disabled)
    end

    test "returns an error if invalid options are specified" do
      assert {:error, validation_errors} = Spandex.start_trace("root_span", @base_opts)
      assert {:service, "is required"} in validation_errors
    end
  end

  describe "Spandex.start_span/2" do
    test "creates a new Span under the active Span with the given name" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{} = span} = Spandex.start_span("span_name", opts)
      assert %Span{id: span_id, name: "span_name", parent_id: ^root_span_id} = span
    end

    test "returns an error if there is not a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:error, :no_trace_context} = Spandex.start_span("orphan_span", opts)
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.start_span("root_span", :disabled)
    end

    test "inherits service and resource from parent span if not specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{} = span} = Spandex.start_span("span_name", @base_opts)
      assert %Span{name: "span_name", service: :test_service, resource: "test_resource"} = span
    end

    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} = Spandex.start_span("span_name", @base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.update_span/1" do
    test "modifies the current span" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{} = root_span = Spandex.current_span(@base_opts)
      assert {:ok, %Span{} = span} = Spandex.start_span("span_name", opts)

      updated_opts = Keyword.put(@base_opts, :sql_query, query: "SELECT * FROM users;")
      assert {:ok, %Span{} = span} = Spandex.update_span(updated_opts)
      assert ^span = Spandex.current_span(@base_opts)
      assert %Span{sql_query: [query: "SELECT * FROM users;"]} = span

      Spandex.finish_span(@base_opts)
      assert ^root_span = Spandex.current_span(@base_opts)
      assert root_span.sql_query == nil
    end

    test "returns an error if there is not a trace in progress" do
      assert {:error, :no_trace_context} = Spandex.update_span(@base_opts ++ @span_opts)
    end

    test "returns an error if there is not a span in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: ^root_span_id}} = Spandex.finish_span(@base_opts)
      assert {:error, :no_span_context} = Spandex.update_span(opts)
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.update_span(:disabled)
    end

    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} = Spandex.update_span(@base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.update_span/2" do
    test "with false as the second argument, acts like update_span/1" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{} = root_span = Spandex.current_span(@base_opts)
      assert {:ok, %Span{} = span} = Spandex.start_span("span_name", opts)

      updated_opts = Keyword.put(@base_opts, :sql_query, query: "SELECT * FROM users;")
      assert {:ok, %Span{} = span} = Spandex.update_span(updated_opts)
      assert ^span = Spandex.current_span(@base_opts)
      assert %Span{sql_query: [query: "SELECT * FROM users;"]} = span

      Spandex.finish_span(@base_opts)
      assert ^root_span = Spandex.current_span(@base_opts)
      assert root_span.sql_query == nil
    end

    test "with true as the second argument, acts like update_top_span/1" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      query = [query: "SELECT * FROM users;"]
      updated_opts = Keyword.put(@base_opts, :sql_query, query)
      assert {:ok, %Span{id: ^root_span_id}} = Spandex.update_top_span(updated_opts)
      assert %Span{id: ^span_id, sql_query: nil} = Spandex.current_span(@base_opts)

      Spandex.finish_span(@base_opts)
      assert %Span{id: ^root_span_id, sql_query: ^query} = Spandex.current_span(@base_opts)
    end
  end

  describe "Spandex.update_top_span/1" do
    test "modifies the root span in the trace" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      query = [query: "SELECT * FROM users;"]
      updated_opts = Keyword.put(@base_opts, :sql_query, query)
      assert {:ok, %Span{id: ^root_span_id}} = Spandex.update_top_span(updated_opts)
      assert %Span{id: ^span_id, sql_query: nil} = Spandex.current_span(@base_opts)

      Spandex.finish_span(@base_opts)
      assert %Span{id: ^root_span_id, sql_query: ^query} = Spandex.current_span(@base_opts)
    end

    test "returns an error if there is not a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:error, :no_trace_context} = Spandex.update_top_span(opts)
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.update_top_span(:disabled)
    end

    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} = Spandex.update_top_span(@base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.update_all_spans/1" do
    test "modifies each span in the trace" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      updated_opts = Keyword.put(@base_opts, :service, :updated_service)
      assert {:ok, %Trace{id: ^trace_id}} = Spandex.update_all_spans(updated_opts)
      assert %Span{id: ^span_id, service: :updated_service} = Spandex.current_span(@base_opts)

      Spandex.finish_span(@base_opts)

      assert %Span{id: ^root_span_id, service: :updated_service} = Spandex.current_span(@base_opts)
    end

    test "returns an error if there is not a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:error, :no_trace_context} = Spandex.update_all_spans(opts)
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.update_all_spans(:disabled)
    end

    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} = Spandex.update_all_spans(@base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.finish_trace/1" do
    test "sends all spans to the Adapter's default sender by default" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      assert {:ok, _} = Spandex.finish_trace(@base_opts)
      spans = Util.sent_spans()
      assert length(spans) == 2
      assert Enum.any?(spans, fn span -> span.id == root_span_id end)
      assert Enum.any?(spans, fn span -> span.id == span_id end)

      assert nil == Spandex.current_span_id(@base_opts)
      assert nil == Spandex.current_trace_id(@base_opts)
    end

    test "sends spans to an overridden sender" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      assert {:ok, _} = Spandex.finish_trace(@base_opts ++ [sender: PdictSender])
      %Trace{spans: spans} = Process.get(:trace)
      assert length(spans) == 2
      assert Enum.any?(spans, fn span -> span.id == root_span_id end)
      assert Enum.any?(spans, fn span -> span.id == span_id end)

      assert nil == Spandex.current_span_id(@base_opts)
      assert nil == Spandex.current_trace_id(@base_opts)
    end

    test "ensures all spans have a completion time" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      assert {:ok, _} = Spandex.finish_trace(@base_opts)
      spans = Util.sent_spans()
      assert length(spans) == 2
      assert Enum.all?(spans, fn span -> span.completion_time != nil end)
    end

    test "preserves existing completion times" do
      now = :os.system_time(:nano_seconds)
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)

      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts ++ [start: now - 10])

      assert {:ok, %Span{id: ^span_id}} = Spandex.update_span(@base_opts ++ [completion_time: now - 9])

      assert {:ok, %Span{id: ^span_id}} = Spandex.finish_span(@base_opts)

      assert {:ok, _} = Spandex.finish_trace(@base_opts)
      spans = Util.sent_spans()
      assert length(spans) == 2

      assert Enum.any?(spans, fn span -> span.id == span_id && span.completion_time == now - 9 end)
    end

    test "returns an error if there is not a trace in progress" do
      log =
        capture_log(fn ->
          assert {:error, :no_trace_context} = Spandex.finish_trace(@base_opts)
        end)

      assert String.contains?(log, "[error] Tried to finish a trace without an active trace.")
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.finish_trace(:disabled)
    end

    # TODO: Currently, invalid opts are silently ignored. Should we change that?
    @tag :skip
    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} = Spandex.finish_trace(@base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.finish_span/1" do
    test "sets the parent span as the current span" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      assert {:ok, %Span{id: ^span_id}} = Spandex.finish_span(@base_opts)
      assert root_span_id == Spandex.current_span_id(@base_opts)
      assert trace_id == Spandex.current_trace_id(@base_opts)
    end

    test "does not send the span immediately" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)

      assert {:ok, %Span{id: ^span_id}} = Spandex.finish_span(@base_opts ++ [sender: PdictSender])
      assert nil == Process.get(:spans)
    end

    test "ensures the span has a completion time" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", opts)
      assert {:ok, %Span{} = span} = Spandex.finish_span(@base_opts)
      assert span.id == span_id
      assert span.completion_time != nil
    end

    test "returns an error if there is not a trace in progress" do
      assert {:error, :no_trace_context} = Spandex.finish_span(@base_opts)
    end

    test "returns an error if there is not a span in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert %Span{id: root_span_id} = Spandex.current_span(@base_opts)
      assert {:ok, %Span{id: ^root_span_id}} = Spandex.finish_span(@base_opts)

      log =
        capture_log(fn ->
          assert {:error, :no_span_context} = Spandex.finish_span(@base_opts)
        end)

      assert String.contains?(log, "[error] Tried to finish a span without an active span.")
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.finish_trace(:disabled)
    end

    # TODO: Currently, invalid opts are silently ignored. Should we change that?
    @tag :skip
    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} = Spandex.finish_span(@base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.span_error/3" do
    test "updates the current span with error information" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{}} = Spandex.span_error(@runtime_error, @fake_stacktrace, @base_opts)
      assert %Span{error: error} = Spandex.current_span(@base_opts)
      assert [exception: %RuntimeError{}, stacktrace: stacktrace] = error
      assert [_, _] = stacktrace
    end

    test "returns an error if there is not a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:error, :no_trace_context} = Spandex.span_error(@runtime_error, @fake_stacktrace, opts)
    end

    test "returns an error if there is not a span in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{}} = Spandex.finish_span(@base_opts)
      assert {:error, :no_span_context} = Spandex.span_error(@runtime_error, @fake_stacktrace, @base_opts)
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} = Spandex.span_error(@runtime_error, @fake_stacktrace, :disabled)
    end

    # TODO: Currently, invalid opts are silently ignored. Should we change that?
    @tag :skip
    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)

      assert {:error, validation_errors} =
               Spandex.span_error(
                 @runtime_error,
                 @fake_stacktrace,
                 @base_opts ++ [type: "not an atom"]
               )

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.current_trace_id/1" do
    test "returns the active trace ID if a trace is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert trace_id == Spandex.current_trace_id(@base_opts)
    end

    test "returns nil if no trace is active" do
      assert nil == Spandex.current_trace_id(@base_opts)
    end

    test "returns nil if tracing is disabled" do
      assert nil == Spandex.current_trace_id(:disabled)
    end
  end

  describe "Spandex.current_span_id/1" do
    test "returns the active span ID if a span is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", @base_opts)
      assert span_id == Spandex.current_span_id(@base_opts)
    end

    test "returns nil if no span is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{}} = Spandex.finish_span(@base_opts)
      assert nil == Spandex.current_span_id(@base_opts)
    end

    test "returns nil if no trace is active" do
      assert nil == Spandex.current_span_id(@base_opts)
    end

    test "returns nil if tracing is disabled" do
      assert nil == Spandex.current_span_id(:disabled)
    end
  end

  describe "Spandex.current_span/1" do
    test "returns the active span if a span is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", @base_opts)
      assert %Span{id: ^span_id, name: "span_name"} = Spandex.current_span(@base_opts)
    end

    test "returns nil if no trace is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{}} = Spandex.finish_span(@base_opts)
      assert nil == Spandex.current_span(@base_opts)
    end

    test "returns nil if no span is active" do
      assert nil == Spandex.current_span(@base_opts)
    end

    test "returns nil if tracing is disabled" do
      assert nil == Spandex.current_span(:disabled)
    end
  end

  describe "Spandex.current_context/1" do
    test "returns the active SpanContext if a span is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: trace_id}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{id: span_id}} = Spandex.start_span("span_name", @base_opts)
      assert {:ok, %SpanContext{trace_id: ^trace_id, parent_id: ^span_id}} = Spandex.current_context(@base_opts)
    end

    test "returns an error if no span is active" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      assert {:ok, %Span{}} = Spandex.finish_span(@base_opts)
      assert {:error, :no_span_context} == Spandex.current_context(@base_opts)
    end

    test "returns an error if no trace is active" do
      assert {:error, :no_trace_context} == Spandex.current_context(@base_opts)
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} == Spandex.current_context(:disabled)
    end
  end

  describe "Spandex.continue_trace/3" do
    test "starts a new child span in an existing trace based on a specified name, trace ID and parent span ID" do
      opts = @base_opts ++ @span_opts
      span_context = %SpanContext{trace_id: 123, parent_id: 456}
      assert {:ok, %Trace{id: 123}} = Spandex.continue_trace("root_span", span_context, opts)
      assert %Span{parent_id: 456, name: "root_span"} = Spandex.current_span(@base_opts)
    end

    test "returns an error if there is already a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)

      log =
        capture_log(fn ->
          span_context = %SpanContext{trace_id: 123, parent_id: 456}
          assert {:error, :trace_already_present} = Spandex.continue_trace("span_name", span_context, opts)
        end)

      assert String.contains?(log, "[error] Tried to continue a trace over top of another trace.")
    end

    test "returns an error if tracing is disabled" do
      span_context = %SpanContext{trace_id: 123, parent_id: 456}
      assert {:error, :disabled} == Spandex.continue_trace("span_name", span_context, :disabled)
    end

    test "returns an error if invalid options are specified" do
      opts = @base_opts ++ [type: "not an atom"]
      span_context = %SpanContext{trace_id: 123, parent_id: 456}
      assert {:error, validation_errors} = Spandex.continue_trace("span_name", span_context, opts)

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.continue_trace/4 (DEPRECATED)" do
    test "starts a new child span in an existing trace based on a specified name, trace ID and parent span ID" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{id: 123}} = Spandex.continue_trace("root_span", 123, 456, opts)
      assert %Span{parent_id: 456, name: "root_span"} = Spandex.current_span(@base_opts)
    end

    test "returns an error if there is already a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)

      log =
        capture_log(fn ->
          assert {:error, :trace_already_present} = Spandex.continue_trace("span_name", 123, 456, opts)
        end)

      assert String.contains?(log, "[error] Tried to continue a trace over top of another trace.")
    end

    test "returns an error if tracing is disabled" do
      assert {:error, :disabled} == Spandex.continue_trace("span_name", 123, 456, :disabled)
    end

    test "returns an error if invalid options are specified" do
      assert {:error, validation_errors} =
               Spandex.continue_trace("span_name", 123, 456, @base_opts ++ [type: "not an atom"])

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.continue_trace_from_span/3" do
    test "returns a new trace based on a specified name and existing span" do
      existing_span = %Span{id: 456, trace_id: 123, name: "existing"}

      assert {:ok, %Trace{id: trace_id}} = Spandex.continue_trace_from_span("root_span", existing_span, @base_opts)

      assert trace_id != 123
      assert %Span{parent_id: 456, name: "root_span"} = Spandex.current_span(@base_opts)
    end

    test "returns an error if there is already a trace in progress" do
      opts = @base_opts ++ @span_opts
      assert {:ok, %Trace{}} = Spandex.start_trace("root_span", opts)
      existing_span = %Span{id: 456, trace_id: 123, name: "existing"}

      log =
        capture_log(fn ->
          assert {:error, :trace_already_present} =
                   Spandex.continue_trace_from_span("root_span", existing_span, @base_opts)
        end)

      assert String.contains?(log, "[error] Tried to continue a trace over top of another trace.")
    end

    test "returns an error if tracing is disabled" do
      existing_span = %Span{id: 456, trace_id: 123, name: "existing"}

      assert {:error, :disabled} == Spandex.continue_trace_from_span("root_span", existing_span, :disabled)
    end

    test "returns an error if invalid options are specified" do
      existing_span = %Span{id: 456, trace_id: 123, name: "existing"}

      assert {:error, validation_errors} =
               Spandex.continue_trace_from_span(
                 "span_name",
                 existing_span,
                 @base_opts ++ [type: "not an atom"]
               )

      assert {:type, "must be of type :atom"} in validation_errors
    end
  end

  describe "Spandex.distributed_context/2" do
    test "returns a distributed context representation" do
      conn =
        :get
        |> Plug.Test.conn("/")
        |> Plug.Conn.put_req_header("x-test-trace-id", "1234")
        |> Plug.Conn.put_req_header("x-test-parent-id", "5678")
        |> Plug.Conn.put_req_header("x-test-sampling-priority", "10")

      assert {:ok, %SpanContext{} = span_context} = Spandex.distributed_context(conn, @base_opts)
      assert %SpanContext{trace_id: 1234, parent_id: 5678, priority: 10} = span_context
    end

    test "returns an error if distributed tracing headers are not present" do
      conn = Plug.Test.conn(:get, "/")
      assert {:error, :no_distributed_trace} = Spandex.distributed_context(conn, @base_opts)
    end

    test "returns an error if tracing is disabled" do
      conn = Plug.Test.conn(:get, "/")
      assert {:error, :disabled} == Spandex.distributed_context(conn, :disabled)
    end
  end

  describe "Spandex.inject_context/3" do
    test "Prepends distributed tracing headers to an existing list of headers" do
      span_context = %SpanContext{trace_id: 123, parent_id: 456, priority: 10}
      headers = [{"header1", "value1"}, {"header2", "value2"}]

      result = Spandex.inject_context(headers, span_context, @base_opts)

      assert result == [
               {"x-test-trace-id", "123"},
               {"x-test-parent-id", "456"},
               {"x-test-sampling-priority", "10"},
               {"header1", "value1"},
               {"header2", "value2"}
             ]
    end
  end
end
