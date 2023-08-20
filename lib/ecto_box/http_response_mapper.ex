defmodule EctoBox.HttpResponseMapper do
  @moduledoc """
  Helper which extracts {:ok, body} tuple from %Tesla.Env{} and converts it into struct
  """

  require Logger

  @type status_and_body :: %{status: integer(), body: any()}
  @type http_response :: {:error, any()} | {:ok, status_and_body()}
  @type target :: module() | tuple() | map() | nil

  @doc """
  Extracts body from Req/Tesla's response and wraps it accordingly into :ok / :error tuple

  Depending on the HTTP status code it optionally de-serializes the response into Ecto schemas:
  * HTTP 2xx -> serializes into success_type -> `{:ok, schema}`
  * HTTP 4xx -> serializes into error_type -> `{:error, schema}`
  * _ -> `{:error, <original_response>}`

  Pass `nil` instead of target schema if you don't want to convert the body into Ecto schema
  Use ecto-compatible tuple expression to express arrays / maps in decoding targets

  Examples:

      # assuming response body:   %{"foo" => "bar"}
      extract_body(response)                    # =>  {:ok, %{"foo" => "bar"}}
      extract_body(response, nil, Error)        # =>  {:ok, %{"foo" => "bar"}}
      extract_body(response, Success)           # =>  {:ok, %Success{foo: "bar"}}
      extract_body(response, %{200 => A, 202 => B}, %{400 => C, 404 => D})    # =>  {:ok, %B{...}}
      extract_body(response, Success, Error)    # =>  {:ok, %Success{foo: "bar"}}

      # assuming response body    [%{"foo" => "bar"}]
      extract_body(response, {:array, Success})  # =>  {:ok, [%Success{foo: "bar"}]}

      # assuming response body:   %{"one" => %{"foo" => "bar"}}
      extract_body(response, {:map, Success})  # =>  {:ok, %{"one" => %Success{foo: "bar"}}}

  When dynamic HTTP status mapping is used, it may return `{:error, :unexpected_http_status}`.

  Any Ecto schema mismatches will be logged and `{:error, :conversion_error}` will be returned.
  """

  @spec extract_body(http_response(), target(), target()) :: {:error, any()} | {:ok, any()}
  def extract_body(tuple, success_type \\ nil, error_type \\ nil)
  def extract_body({:error, reason}, _, _), do: {:error, reason}

  def extract_body({:ok, env}, success_types, error_types) do
    case env.status do
      204 ->
        {:ok, nil}

      code when code in 200..299 ->
        parse_body(env, :ok, as: find_type(success_types, code))

      code when code in 400..499 ->
        parse_body(env, :error, as: find_type(error_types, code))

      _code ->
        {:error, env}
    end
  end

  defp parse_body(env, outcome, as: nil), do: {outcome, env.body}

  defp parse_body(_env, _outcome, as: :unexpected_http_status) do
    {:error, :unexpected_http_status}
  end

  defp parse_body(env, outcome, as: type) do
    case Ecto.Type.load(type, env.body) do
      {:ok, result} ->
        {outcome, result}

      :error ->
        Logger.warning("HTTP #{env.status} with body not convertable to #{inspect(type)}")
        {:error, :coversion_error}
    end
  end

  # support for dynamic typing, e.g.:
  # extract_body(response, %{200 => A, 202 => B}, %{400 => C, 404 => D})
  defp find_type(types, code) do
    if is_map(types) do
      Map.get(types, code, :unexpected_http_status)
    else
      types
    end
  end
end
