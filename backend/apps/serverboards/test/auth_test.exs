defmodule Serverboards.AuthTest do
  use ExUnit.Case
	alias Test.Client

	test "Basic auth" do

		{:ok, client} = Client.start_link
		Task.async( fn -> Serverboards.Auth.authenticate(client) end)

		Client.expect( client, method: "auth.required" )
		assert Client.call( client, "auth.auth", %{ "type" => "token", "token" => "xxx" }, 1) == false

		user = Client.call( client, "auth.auth", %{ "type" => "token", "token" => "XXX" }, 2)
		assert user != false

	end

end
