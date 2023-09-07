defmodule EctoBox do
  @moduledoc """
  Ecto schemas with `load` capability.

      import EctoBox

  Find more details in [Overview](./overview.html) and [live example](./ecto_box.livemd).
  """

  defmodule Loaders do
    @moduledoc false
    def loaders(:utc_datetime, type), do: [&load_utc_datetime/1, type]
    def loaders(:naive_datetime, type), do: [&load_naive_datetime/1, type]
    def loaders(:uuid, type), do: [&load_binary/1, type]
    def loaders(:binary, type), do: [&load_binary/1, type]
    def loaders(:integer, type), do: [&load_integer/1, type]

    # implement other types as needed:
    def loaders(:date, _), do: raise("Not implemented")
    def loaders(:time, _), do: raise("Not implemented")
    def loaders(:utc_datetime_usec, _), do: raise("Not implemented")
    def loaders(:naive_datetime_usec, _), do: raise("Not implemented")
    def loaders(:time_usec, _), do: raise("Not implemented")

    # standard Ecto types
    def loaders(_base, type), do: [type]

    defp load_utc_datetime(str) do
      case DateTime.from_iso8601(str) do
        {:ok, datetime, _} -> {:ok, datetime}
        _ -> :error
      end
    end

    defp load_naive_datetime(str) do
      case NaiveDateTime.from_iso8601(str) do
        {:ok, datetime} -> {:ok, datetime}
        _ -> :error
      end
    end

    defp load_binary(b) when is_binary(b), do: {:ok, b}
    defp load_binary(_), do: :error

    defp load_integer(b) when is_binary(b) do
      case Integer.parse(b) do
        {i, ""} -> {:ok, i}
        _any -> :error
      end
    end

    defp load_integer(_), do: :error
  end

  defmodule Any do
    @moduledoc """
    Equivalent of :any Ecto type, just not virtual

        defschema UserMeta do
          field :meta, EctoBox.Any
        end

        iex> UserMeta.load(%{meta: %{foo: "bar"}})
        {:ok, %UserMeta{meta: %{foo: "bar"}}}
    """
    use Ecto.Type
    @impl true
    def type, do: :any
    @impl true
    def cast(_), do: :error
    @impl true
    def dump(_), do: :error
    @impl true
    def load(value), do: {:ok, value}
  end

  @doc """
  Defines an ecto schema with `load/1` and `load!/1` functions.

  The bang version `load!` may raise `FunctionClauseError` or `ArgumentError` from Ecto's internals.

      defschema User do
        field :id, :integer
        field :name, :string
      end

      iex> User.load(%{id: 1, name: "Alice"})
      {:ok, %User{id: 1, name: "Alice"}}

      iex> User.load!(%{id: 1, name: "Alice"})
      %User{id: 1, name: "Alice"}

      iex> User.load(:not_a_map)
      :error

      iex> User.load(%{id: "foobar"})
      :error
  """
  defmacro defschema(name, opts \\ [], do: block) do
    quote do
      defmodule unquote(name) do
        @moduledoc false
        use TypedEctoSchema
        require Logger

        if unquote(opts)[:derive] do
          @derive unquote(opts)[:derive]
        end

        @primary_key false

        embedded_schema do
          unquote(block)
        end

        # @spec load!(map() | struct()) :: __MODULE__.t() | no_return()
        def load!(data) do
          Ecto.Repo.Schema.load(EctoBox.Loaders, __MODULE__, data)
        end

        # @spec load(map() | struct()) :: {:ok, __MODULE__.t()} | :error
        def load(data) do
          {:ok, load!(data)}
        rescue
          ex ->
            Logger.warning("Conversion error in #{inspect(__MODULE__)}: #{Exception.message(ex)}")
            :error
        end

        def type, do: __MODULE__
      end
    end
  end
end
