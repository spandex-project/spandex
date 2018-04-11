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

  def build_level_precedence_map(levels) do
    Enum.reduce(levels, %{}, fn level, acc ->
      Map.put(
        acc,
        level,
        Enum.into(levels, %{}, fn comparing_level ->
          {comparing_level, should_send?(level, comparing_level, levels)}
        end)
      )
    end)
  end

  def should_send?(configured_level, span_level, levels) do
    configured_level_position = Enum.find_index(levels, &Kernel.==(&1, configured_level))
    span_level_position = Enum.find_index(levels, &Kernel.==(&1, span_level))

    configured_level_position <= span_level_position
  end
end
