require Logger

defmodule Serverboards.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    Logger.info("Starting Serverboards supervisor")
    database = Serverboards.Config.get( :database )

    children = [
      supervisor(Serverboards.Repo, [database]),
      supervisor(Task.Supervisor, [[name: Serverboards.IO.TaskSupervisor]]),
      supervisor(Serverboards.IO.Cmd.Supervisor, [[name: Serverboards.IO.Cmd.Supervisor]]),
      supervisor(Serverboards.Auth.Supervisor, []),
      supervisor(Serverboards.Issues, [ [name: Serverboards.Issues] ]),

      worker(Serverboards.Settings, [ [name: Serverboards.Settings] ]),
      worker(Serverboards.Plugin.Registry, [ [name: Serverboards.Plugin.Registry] ]),
      worker(Serverboards.Plugin.Runner, [ [name: Serverboards.Plugin.Runner] ]),
      worker(Serverboards.Plugin.Data, [ [name: Serverboards.Plugin.Data] ]),
      worker(Serverboards.Serverboard, [ [name: Serverboards.Serverboard] ]),
      worker(Serverboards.Service, [ [name: Serverboards.Service] ]),
      worker(Serverboards.Event, [ [name: Serverboards.Event] ]),
      worker(Serverboards.Action, [ [name: Serverboards.Action] ]),
      worker(Serverboards.Notifications, [ [name: Serverboards.Notifications] ]),
      worker(Serverboards.Logger.RPC, [ [name: Serverboards.Logger.RPC] ]),

      worker(Task, [Serverboards.IO.TCP, :start_accept, []], restart: :transient),
      worker(Serverboards.IO.HTTP, [ [name: Serverboards.IO.HTTP] ], restart: :transient),

      # this should be the last, as it may use others
      worker(Serverboards.Rules, [ [name: Serverboards.Rules] ]),
    ]

    opts = [strategy: :one_for_one]

    supervise(children, opts)
  end
end
