defmodule EctoBoxTest do
  @moduledoc false
  use ExUnit.Case
  import ExUnit.CaptureLog
  import EctoBox

  doctest EctoBox
  doctest EctoBox.Any

  defschema MyBox do
    field(:utc, :utc_datetime)
    field(:naive, :naive_datetime)
    field(:uuid, :binary_id)
    field(:int, :integer)
    field(:float, :float)
    field(:str, :string)
    field(:bool, :boolean)
    field(:any, EctoBox.Any)
  end

  # this schema contains fields with types we don't support
  defschema BadSchema do
    field(:date, :date)
    field(:time, :time)
    field(:utc_datetime_usec, :utc_datetime_usec)
    field(:naive_datetime_usec, :naive_datetime_usec)
    field(:time_usec, :time_usec)
  end

  describe "load!" do
    test "ignores unknown or missing fields" do
      assert MyBox.load!(%{"foo" => "bar", num: 42}) == %MyBox{}
    end

    test "handles :any" do
      assert {:ok, %MyBox{any: 42}} = MyBox.load(%{"any" => 42})
      assert {:ok, %MyBox{any: "42"}} = MyBox.load(%{"any" => "42"})
    end

    test "handles integers" do
      assert {:ok, _} = MyBox.load(%{"int" => nil})
      assert {:ok, _} = MyBox.load(%{"int" => 42})
      assert {:ok, _} = MyBox.load(%{"int" => "42"})

      capture_log(fn ->
        assert :error = MyBox.load(%{"int" => "foobar"})
        assert :error = MyBox.load(%{"int" => []})
      end)
    end

    test "handles floats" do
      assert {:ok, _} = MyBox.load(%{"float" => nil})
      assert {:ok, _} = MyBox.load(%{"float" => 3.14})
      assert {:ok, _} = MyBox.load(%{"float" => 42})

      capture_log(fn ->
        assert :error = MyBox.load(%{"float" => "foobar"})
        assert :error = MyBox.load(%{"int" => "42_foobar"})
        assert :error = MyBox.load(%{"float" => %{}})
      end)
    end

    test "handles strings" do
      assert {:ok, _} = MyBox.load(%{"str" => nil})
      assert {:ok, _} = MyBox.load(%{"str" => "String"})

      capture_log(fn ->
        assert :error = MyBox.load(%{"str" => 42})
        assert :error = MyBox.load(%{"str" => []})
      end)
    end

    test "handles booleans" do
      assert {:ok, %{bool: nil}} = MyBox.load(%{"bool" => nil})
      assert {:ok, %{bool: false}} = MyBox.load(%{"bool" => false})

      capture_log(fn ->
        assert :error = MyBox.load(%{"bool" => "string"})
      end)
    end

    test "handles dates and time" do
      result =
        MyBox.load!(%{
          "utc" => "2015-01-23T23:50:07Z",
          "naive" => "2015-01-23 23:50:07"
        })

      assert %DateTime{} = result.utc
      assert %NaiveDateTime{} = result.naive
      assert result.uuid == nil
    end

    test "converts utc_datetime to UTC" do
      result =
        MyBox.load!(%{
          "utc" => "2015-01-23T12:00:00+01:00"
        })

      assert result.utc.hour == 11
    end

    @uuid "78565896-7201-11eb-9439-0242ac130002"
    test "loads UUID as string - string and atom key" do
      assert MyBox.load!(%{"uuid" => @uuid}) == %MyBox{uuid: @uuid}
      assert MyBox.load!(%{uuid: @uuid}) == %MyBox{uuid: @uuid}
    end

    # TESTS FOR UN-SUPPORTED DATA TYPES
    # :date and :time - let's developers implement own `Iso8601Date` type
    # :xxx_usec - looks like not needed atm

    test "only serializes fields given on the input" do
      assert BadSchema.load!(%{}) == %BadSchema{}
    end

    test "doesn't support :date and :time" do
      assert capture_log(fn ->
               assert BadSchema.load(%{date: "2021-01-01"}) == :error
             end) =~ "Not implemented"

      assert capture_log(fn ->
               assert BadSchema.load(%{time: "12:00:00"}) == :error
             end) =~ "Not implemented"
    end

    test "doesn't support :xxx_usec types" do
      assert capture_log(fn ->
               assert BadSchema.load(%{utc_datetime_usec: "2015-01-23T23:50:07Z"}) == :error
             end) =~ "Not implemented"

      assert capture_log(fn ->
               assert BadSchema.load(%{naive_datetime_usec: "2015-01-23T23:50:07"}) == :error
             end) =~ "Not implemented"

      assert capture_log(fn ->
               assert BadSchema.load(%{time_usec: "12:00:00"}) == :error
             end) =~ "Not implemented"
    end
  end
end
