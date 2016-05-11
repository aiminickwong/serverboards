require Logger

defmodule Serverboards.AuthUserTest do
  use ExUnit.Case
  @moduletag :capture_log

  doctest Serverboards.Auth.Permission

  alias Serverboards.Auth.{User, Group, UserGroup, GroupPerms, Permission}
  alias Serverboards.Repo
  import Ecto.Query

  setup_all do
    me = User.user_info("dmoreno@serverboards.io", %{ email: "dmoreno@serverboards.io" })
    #Ecto.Adapters.SQL.restart_test_transaction(Serverboards.Repo, [])
    :ok = User.user_add(%{
      email: "dmoreno+a@serverboards.io",
      first_name: "David",
      last_name: "Moreno",
      is_active: true,
      }, me)
    user = User.user_info("dmoreno+a@serverboards.io", me)

    :ok = User.user_add(%{
      email: "dmoreno+b@serverboards.io",
      first_name: "David",
      last_name: "Moreno B",
      is_active: true,
      }, me)
    userb = User.user_info("dmoreno+b@serverboards.io", me)
    admin = User.user_info("dmoreno@serverboards.io", me)

    #{:ok, group} = Repo.insert(%Group{ name: "admin" })
    :ok = Group.group_add("admin+a", me)

    {:ok, %{ user: user, userb: userb, admin: admin }}
  end

  test "Set password", %{ user: user, userb: userb } do
    {:error, _} = User.Password.password_set(user, "", user)
    {:error, _} = User.Password.password_set(user, "1234", user)
    {:error, _} = User.Password.password_set(user, "1234567", user)

    password = "12345678"
    :ok = User.Password.password_set(user, password, user)

    #Logger.debug("Check password t #{User.Password.check_password(user, password)}")
    assert User.Password.password_check(user, password, user)
    #Logger.debug("Check password f #{User.Password.check_password(user, password <> "1")}")
    assert User.Password.password_check(user, password <> "1", user) == false

    # Cant change other users password
    {:error, :not_allowed} = User.Password.password_set(user, password, userb)

  end

  test "Authenticate with password", %{ user: user, admin: admin } do
    password = "abcdefgh"
    :ok = User.Password.password_set(user, password, user)

    userb = User.Password.auth("dmoreno+a@serverboards.io", password)
    assert userb.id == user.id
    Logger.debug("Permissions: #{inspect user.perms}")

    User.user_update user.email, %{is_active: false}, admin
    userb = User.Password.auth("dmoreno+a@serverboards.io", password)
    assert userb == false

    User.user_update user.email, %{is_active: true}, admin
    #Logger.debug("Permissions: #{inspect user.perms}")
  end

  test "Authenticate with token", %{ user: user } do
    _token = case User.Token.create(user) do
      {:error, _} -> flunk "Error creating token!"
      t           -> t
    end

    token = case User.Token.create(user) do
      {:error, _} -> flunk "Error creating second token!"
      t           -> t
    end


    userb = User.Token.auth(token)
    assert userb.id == user.id

    assert User.Token.auth("garbage") == false

    # manual set time_limit to 1 min ago
    tk = Repo.get_by(Serverboards.Auth.User.Model.Token, token: token)
    tl = Timex.to_erlang_datetime( Timex.shift( Timex.DateTime.now, minutes: -1 ) )
    {:ok, tl} = Ecto.DateTime.cast tl
    #cs = tk |> Ecto.Changeset.cast( %{ time_limit: tl}, [:token, :user_id], [:time_limit] )

    case Repo.update( Ecto.Changeset.cast( tk, %{time_limit: tl}, [:token, :user_id, :time_limit], [] ) ) do
      {:ok, _} -> :ok
      msg -> flunk (inspect msg)
    end

    # now is invalid, expired
    assert User.Token.auth(token) == false

  end


  test "Groups and permissions", %{ user: user, userb: userb, admin: admin } do
    groups = Group.group_list user
    Logger.info(inspect groups)
    assert Enum.member? groups, "admin+a"

    users = Group.user_list "admin+a", user
    assert users == []

    Group.user_add("admin+a", user.email, admin)

    users = Group.user_list "admin+a", user
    assert (hd users) == user.email

    Group.user_add("admin+a", userb.email, admin)

    users = Group.user_list "admin+a", user
    assert Enum.sort(users)  == Enum.sort([user.email, userb.email])

    # Readding is ok
    Group.user_add("admin+a", userb.email, admin)
    Group.user_add("admin+a", userb.email, admin)

    Group.perm_add("admin+a", "auth.modify_self", admin)
    Group.perm_add("admin+a", "debug", admin)

    perms = (User.user_info (user)).perms
    assert "auth.modify_self" in perms
  end
end
