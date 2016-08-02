require Logger

defmodule Serverboards.Notifications.InApp do
  @moduledoc """
  This module stores and allow manipulation of database stores notifications.

  This doe snot follow standard notification via plugin to ensure that no
  failure can prevent it from being saved. Also it is a mandatory channel.

  Other that that, stores as a normal Channel would do, and allow quering.
  """
  alias Serverboards.Repo
  alias Serverboards.Notifications.Model

  def setup_eventsourcing(es) do
    EventSourcing.subscribe es, :update, fn
      %{ id: id, tags: tags} = what, me ->
        update_real(id, what, me)
    end
  end

  def notify(email, subject, body, meta) do
    import Ecto.Query
    user_id = Repo.one( from u in Serverboards.Auth.Model.User, where: u.email == ^email, select: u.id )
    #Logger.debug("#{inspect meta}")

    tags = ["new","unread"]
    notification = %{ user_id: user_id, subject: subject, body: body, meta: meta, tags: tags }

    {:ok, notification } = Repo.insert( Model.Notification.changeset(
        %Model.Notification{}, notification
        ) )

    notification = %{ notification | inserted_at: Ecto.DateTime.to_iso8601(notification.inserted_at)}
    Serverboards.Event.emit("notifications.new", %{notification: notification}, %{ user: email, perms: ["notifications.list"] })

    :ok
  end

  def update(id, what, me) do
    EventSourcing.dispatch(
      :notifications, :update,
      %{ id: id } |> Map.merge(what),
      me.email)
  end

  def update_real(id, what, email) do
    me = Serverboards.Auth.User.user_info email, %{email: email}
    model = %Serverboards.Notifications.Model.Notification{}
      |> Map.merge(details(id, me))
      |> Map.put(:user_id, me.id)
    {:ok, notification} = Repo.update(Model.Notification.changeset( model, what ))
    #notification = %{ notification | inserted_at: Ecto.DateTime.to_iso8601(notification.inserted_at)}
    Serverboards.Event.emit("notifications.update", %{notification: notification}, %{ user: email, perms: ["notifications.list"] })
  end

  def list(filter, user) do
    import Ecto.Query
    q=   from m in Model.Notification,
        where: m.user_id == ^user.id,
     order_by: [desc: m.id],
       select: %{ subject: m.subject, tags: m.tags, inserted_at: m.inserted_at, id: m.id }

    # default values
    filter = Map.merge(%{"count" => 50}, filter)

    Logger.debug("#{inspect filter} #{inspect Map.to_list(filter)}")
    q = Enum.reduce(Map.to_list(filter), q, fn
      {"tags", tags}, q -> where(q, [m], fragment("tags @> ?", ^tags))
      {"count", count}, q -> limit(q, ^count)
      {"start", start}, q -> where(q, [m], m.start < ^start )

      {:tags, tags}, q -> where(q, [m], fragment("tags @> ?", ^tags))
      {:count, count}, q -> limit(q, ^count)
      {:start, start}, q -> where(q, [m], m.start < ^start )
    end)

    ret = Repo.all( q )
      |> Enum.map( fn n -> # post processing
        %{ n | inserted_at: Ecto.DateTime.to_iso8601(n.inserted_at)}
      end)

    {:ok, ret}
  end

  def details(id, user) do
    import Ecto.Query
    n = Repo.one(
      from m in Model.Notification,
      where: (m.user_id == ^user.id) and (m.id == ^id),
      select: %{ subject: m.subject, body: m.body, tags: m.tags, meta: m.meta, inserted_at: m.inserted_at, id: m.id }
    )

    # post process
    %{ n | inserted_at: Ecto.DateTime.to_iso8601(n.inserted_at)}
  end

end