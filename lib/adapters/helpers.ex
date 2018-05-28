defmodule Spandex.Adapters.Helpers do
  @moduledoc """
  Helper functions and macros for adapters.
  """

  defmacro delegate_to_adapter(name, args) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        adapter = Confex.get_env(:spandex, :adapter)

        if adapter do
          apply(adapter, unquote(name), unquote(args))
        else
          {:error, :no_adapter_configured}
        end
      rescue
        exception ->
          {:error, exception}
      end
    end
  end

  @spec get_first_header(conn :: Plug.Conn.t(), header_name :: binary) :: binary | nil
  def get_first_header(conn, header_name) do
    conn
    |> Plug.Conn.get_req_header(header_name)
    |> List.first()
  end
end
