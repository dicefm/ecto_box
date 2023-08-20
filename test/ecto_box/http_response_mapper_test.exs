defmodule EctoBox.HttpResponseMapperTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import EctoBox
  import EctoBox.HttpResponseMapper

  # doctest EctoBox.HttpResponseMapper

  defmodule CustomEctoAtomType do
    use Ecto.Type
    def type, do: __MODULE__
    def cast(_), do: :error

    def load("foo"), do: {:ok, :foo}
    def load("bar"), do: {:ok, :bar}
    def load(_), do: :error

    def dump(_), do: :error
  end

  defschema CrazyCity do
    field(:name, :string)
  end

  defschema CrazySchema do
    field(:foo_bar, CustomEctoAtomType)
    field(:cities, {:map, CrazyCity})
  end

  defschema Error do
    field(:code, :integer)
  end

  @custom_type_200 %{body: "bar", status: 200}
  @valid_200 %{body: %{"name" => "Paris"}, status: 200}
  @malformed_200 %{body: %{"name" => 42}, status: 200}
  @non_json_200 %{body: "non-json", status: 200}
  @non_foo_bar_200 %{body: %{"foo_bar" => "bang"}, status: 200}
  @valid_error_400 %{body: %{"code" => 42}, status: 400}
  @malformed_error_400 %{body: %{"code" => "bang"}, status: 400}
  @textual_400 %{body: "non-json", status: 400}
  @textual_300 %{body: "", status: 300}
  @textual_500 %{body: "non-json", status: 500}

  describe "extract_body/3" do
    test "handles 2xx" do
      assert extract_body({:ok, @valid_200}) == {:ok, %{"name" => "Paris"}}
      assert extract_body({:ok, @valid_200}, CrazyCity) == {:ok, %CrazyCity{name: "Paris"}}
    end

    test "handles dynamic typing (matching)" do
      assert extract_body({:ok, @valid_200}, %{200 => CrazyCity}) ==
               {:ok, %CrazyCity{name: "Paris"}}
    end

    test "handles dynamic typing (non-matching)" do
      # notice the expected HTTP status below doesn't match the actual "200"
      assert {:error, :unexpected_http_status} =
               extract_body({:ok, @valid_200}, %{202 => CrazyCity})
    end

    test "handles Ecto conversion errors" do
      assert {:error, :coversion_error} =
               extract_body({:ok, @non_foo_bar_200}, CustomEctoAtomType)
    end

    test "handles custom type invariant errors" do
      log =
        capture_log(fn ->
          assert {:error, :coversion_error} = extract_body({:ok, @malformed_200}, CrazyCity)
        end)

      assert log =~
               "EctoBox.HttpResponseMapperTest.CrazyCity: cannot load `42` as type :string for field `name`"
    end

    test "handles non-json responses" do
      assert extract_body({:ok, @non_json_200}) == {:ok, "non-json"}

      log =
        capture_log(fn ->
          assert {:error, :coversion_error} = extract_body({:ok, @non_json_200}, CrazyCity)
        end)

      assert log =~ "Conversion error in EctoBox.HttpResponseMapperTest.CrazyCity"
    end

    test "handles 4xx errors" do
      assert extract_body({:ok, @textual_400}) == {:error, "non-json"}
      assert extract_body({:ok, @valid_error_400}) == {:error, %{"code" => 42}}
      assert extract_body({:ok, @valid_error_400}, nil, Error) == {:error, %Error{code: 42}}
    end

    test "handles 3xx and 5xx errors" do
      assert {:error, %{status: 300}} = extract_body({:ok, @textual_300})
      assert {:error, %{status: 500}} = extract_body({:ok, @textual_500})
    end

    test "handles connection errors" do
      assert {:error, :connection_error} = extract_body({:error, :connection_error})
    end

    test "handles conversion errors in 4xx errors" do
      logs =
        capture_log(fn ->
          assert {:error, :coversion_error} =
                   extract_body({:ok, @malformed_error_400}, nil, Error)
        end)

      assert logs =~ ~r/cannot load `"bang"` as type :integer/

      logs =
        capture_log(fn ->
          assert {:error, :coversion_error} = extract_body({:ok, @textual_400}, nil, Error)
        end)

      assert logs =~ "Conversion error in EctoBox.HttpResponseMapperTest.Error"
    end

    test "handles custom types" do
      assert extract_body({:ok, @custom_type_200}, CustomEctoAtomType) == {:ok, :bar}
    end

    # Using all features together

    @complex_200 %{
      body: [
        %{
          "foo" => %{
            "foo_bar" => "bar",
            "cities" => %{"london" => %{name: "London"}}
          }
        }
      ],
      status: 200
    }

    test "understands :map and :array Ecto notations" do
      assert extract_body({:ok, @complex_200}, {:array, {:map, CrazySchema}}) ==
               {:ok,
                [
                  %{
                    "foo" => %EctoBox.HttpResponseMapperTest.CrazySchema{
                      cities: %{
                        "london" => %EctoBox.HttpResponseMapperTest.CrazyCity{name: "London"}
                      },
                      foo_bar: :bar
                    }
                  }
                ]}
    end
  end
end
