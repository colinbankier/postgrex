defmodule LoginTest do
  use ExUnit.Case
  alias Postgrex.Connection, as: P
  import Postgrex.TestHelper

  test "login cleartext password" do
    Process.flag(:trap_exit, true)

    opts = [ hostname: "localhost", username: "postgrex_cleartext_pw",
             password: "postgrex_cleartext_pw", database: "postgres" ]
    assert {:ok, pid} = P.start_link(opts)
    assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
    assert :ok = P.stop(pid)
    assert_receive {:EXIT, ^pid, :normal}

    opts = [ hostname: "localhost", username: "postgrex_cleartext_pw",
             password: "wrong_password", database: "postgres" ]

    capture_log fn ->
      assert {:ok, pid} = P.start_link(opts)
      assert_receive {:EXIT, ^pid, %Postgrex.Error{postgres: %{code: code}}}
      assert code in [:invalid_authorization_specification, :invalid_password]
    end
  end

  test "login md5 password" do
    Process.flag(:trap_exit, true)

    opts = [ hostname: "localhost", username: "postgrex_md5_pw",
             password: "postgrex_md5_pw", database: "postgres" ]
    assert {:ok, pid} = P.start_link(opts)
    assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
    assert :ok = P.stop(pid)

    opts = [ hostname: "localhost", username: "postgrex_md5_pw",
             password: "wrong_password", database: "postgres" ]

    capture_log fn ->
      assert {:ok, pid} = P.start_link(opts)
      assert_receive {:EXIT, ^pid, %Postgrex.Error{postgres: %{code: code}}}
      assert code in [:invalid_authorization_specification, :invalid_password]
    end
  end

  test "parameters" do
    opts = [ hostname: "localhost", username: "postgres",
             password: "postgres", database: "postgrex_test" ]

    assert {:ok, pid} = P.start_link(opts)
    assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
    assert String.match? P.parameters(pid)["server_version"], ~R"\d+\.\d+\.\d+"

    if String.match? P.parameters(pid)["server_version"], ~R"9\.\d+\.\d+" do
      assert "" == P.parameters(pid)["application_name"]
      assert :ok = P.stop(pid)

      opts = opts ++ [parameters: [application_name: "postgrex"]]
      assert {:ok, pid} = P.start_link(opts)
      assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
      assert "postgrex" == P.parameters(pid)["application_name"]
      assert :ok = P.stop(pid)
    else
      assert :ok = P.stop(pid)
    end
  end

  @tag :ssl
  test "ssl" do
    opts = [ hostname: "localhost", username: "postgres",
             password: "postgres", database: "postgrex_test",
             ssl: true ]
    assert {:ok, pid} = P.start_link(opts)
    assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
    assert :ok = P.stop(pid)
  end

  test "env var defaults" do
    opts = [ database: "postgrex_test" ]
    assert {:ok, pid} = P.start_link(opts)
    assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
    assert :ok = P.stop(pid)
  end

  test "sync connect" do
    opts = [ database: "postgres", sync_connect: true ]
    assert {:ok, pid} = P.start_link(opts)
    assert {:ok, %Postgrex.Result{}} = P.query(pid, "SELECT 123", [])
    assert :ok = P.stop(pid)
  end

  test "non existant database" do
    Process.flag(:trap_exit, true)

    capture_log fn ->
      opts = [ database: "doesntexist", sync_connect: true ]
      assert {:error, %Postgrex.Error{postgres: %{code: :invalid_catalog_name}}} =
             P.start_link(opts)

      assert_receive {:EXIT, _, %Postgrex.Error{postgres: %{code: :invalid_catalog_name}}}
    end

    capture_log fn ->
      opts = [ database: "doesntexist" ]
      {:ok, pid} = P.start_link(opts)
      assert_receive {:EXIT, ^pid, %Postgrex.Error{postgres: %{code: :invalid_catalog_name}}}
    end
  end
end
