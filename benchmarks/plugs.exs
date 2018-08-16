Application.put_env(:benchmark, BenchmarkTracer, [
  service: :benchmark_service,
  adapter: Spandex.Adapters.Datadog,
  disabled?: false,
  env: to_string(Mix.env())
])

defmodule BenchmarkTracer do
  use Spandex.Tracer, otp_app: :benchmark
end

defmodule Benchmarks.Plug do

  defmodule BaselineRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    get "/" do
      resp(conn, 200, "OK")
    end
  end

  defmodule StartEndRouter do
    use Plug.Router

    plug Spandex.Plug.StartTrace, tracer: BenchmarkTracer
    plug :match
    plug :dispatch
    plug Spandex.Plug.EndTrace, tracer: BenchmarkTracer

    get "/" do
      resp(conn, 200, "OK")
    end
  end

  defmodule AddContextRouter do
    use Plug.Router

    plug Spandex.Plug.StartTrace, tracer: BenchmarkTracer
    plug :match
    plug :dispatch
    plug Spandex.Plug.AddContext, tracer: BenchmarkTracer
    plug Spandex.Plug.EndTrace, tracer: BenchmarkTracer

    get "/" do
      resp(conn, 200, "OK")
    end
  end

  def baseline(opts \\ []) do
    call(BaselineRouter, :get, "/")
  end

  def start_end(opts \\ []) do
    call(StartEndRouter, :get, "/")
  end

  def addcontext(opts \\ []) do
    call(AddContextRouter, :get, "/")
  end

  defp call(router, method, path) do
    method
    |> Plug.Test.conn(path)
    |> router.call(router.init([]))
  end
end

{:ok, pid} = GenServer.start_link(
  Spandex.Datadog.ApiServer,
  [
    host: "localhost",
    port: 8126,
    batch_size: 1000,
    sync_threshold: 100,
    http: HTTPoison
  ],
  name: Spandex.Datadog.ApiServer
)

HTTPoison.start

Benchee.run(
  %{
    baseline: &Benchmarks.Plug.baseline/1,
    start_finish: &Benchmarks.Plug.start_end/1,
    addcontext: &Benchmarks.Plug.addcontext/1
  },
  time: 10,
  memory_time: 2,
  parallel: 4,
  inputs: %{
    no_sampling: [],
    #sample_rate_100: [sample_rate: 100]
  }
)
