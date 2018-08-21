[
  "support/adapter.ex",
  "support/sender.ex",
  "support/tracer.ex"
]
|> Enum.each(&Code.load_file(&1, __DIR__))

Application.put_env(
  :benchmark,
  Benchmark.Tracer,
  service: :benchmark_service,
  adapter: Benchmark.Adapter,
  disabled?: false,
  env: to_string(Mix.env())
)

defmodule Benchmarks.Plug do
  defmodule BaselineRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    get "/" do
      resp(conn, 200, "OK")
    end
  end

  defmodule StartEndRouter do
    use Plug.Router

    plug(Spandex.Plug.StartTrace, tracer: Benchmark.Tracer)
    plug(:match)
    plug(:dispatch)
    plug(Spandex.Plug.EndTrace, tracer: Benchmark.Tracer)

    get "/" do
      resp(conn, 200, "OK")
    end
  end

  defmodule AddContextRouter do
    use Plug.Router

    plug(Spandex.Plug.StartTrace, tracer: Benchmark.Tracer)
    plug(:match)
    plug(:dispatch)
    plug(Spandex.Plug.AddContext, tracer: Benchmark.Tracer)
    plug(Spandex.Plug.EndTrace, tracer: Benchmark.Tracer)

    get "/" do
      resp(conn, 200, "OK")
    end
  end

  def baseline do
    call(BaselineRouter, :get, "/")
  end

  def start_end do
    call(StartEndRouter, :get, "/")
  end

  def addcontext do
    call(AddContextRouter, :get, "/")
  end

  defp call(router, method, path) do
    method
    |> Plug.Test.conn(path)
    |> router.call(router.init([]))
  end
end

Benchee.run(
  %{
    baseline: &Benchmarks.Plug.baseline/0,
    start_finish: &Benchmarks.Plug.start_end/0,
    addcontext: &Benchmarks.Plug.addcontext/0
  },
  time: 10,
  memory_time: 2,
  parallel: 4
)
