defmodule Serverboards.Issues do
  alias Serverboards.Issues.Model

  def start_link(options \\ []) do
    import Supervisor.Spec
    children = [
      worker(Serverboards.Issues.EventSourcing, [[name: Serverboards.Issues.EventSourcing]]),
      worker(Serverboards.Issues.RPC, [[name: Serverboards.Issues.RPC]])
    ]

    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)
  end

  def decorate_issues_list(i) do
    %{
      id: i.id,
      title: i.title,
      creator: Serverboards.Issues.Issue.decorate_user(i.creator),
    }
  end

  def list() do
    import Ecto.Query

    Serverboards.Repo.all(from i in Model.Issue, preload: [:creator])
     |> Enum.map(&decorate_issues_list/1)
  end

end
