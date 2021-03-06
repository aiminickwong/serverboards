require Logger

defmodule Serverboards.Plugin.RPC do
  alias MOM.RPC
  alias Serverboards.Plugin

  def has_perm_for_plugin(context, plugin) do
    perms = RPC.Context.get(context, :user).perms
    cond do
      plugin == :any -> Enum.any?(perms, &(String.starts_with?(&1, "plugin[") or &1 == "plugin"))
      "plugin" in perms -> true
      "plugin[#{plugin}]" in perms -> true
      true -> false
    end
  end
  def check_perm_for_plugin_data(context) do
    user = RPC.Context.get(context, :user)
    context_plugin = RPC.Context.get(context, :plugin)
    #Logger.debug("Plugin dataA #{inspect context_plugin}")
    case context_plugin do
      nil -> # not called from plugin, error
        false
      %{ plugin_id: plugin } -> # called from plugin, allow only to myself
        {plugin, user}
    end
  end
  def check_perm_for_plugin_data(context, plugin) do
    user = RPC.Context.get(context, :user)
    context_plugin = RPC.Context.get(context, :plugin)
    #Logger.debug("Plugin dataB #{inspect context_plugin}")
    case context_plugin do
      nil -> # not called from plugin, check permissions
        perms = user.perms
        cond do
          "plugin.data" in perms -> {plugin, user}
          "plugin.data[#{plugin}]" in perms -> {plugin, user}
          true -> false
        end
      %{ plugin_id: ^plugin } -> # called from plugin, allow only to myself
        {plugin, user}
      %{ plugin_id: plugin_id } -> # error on others
        Logger.error("Plugin #{inspect plugin_id} does not have access to plugin data from #{inspect plugin}")
        false
    end
  end

  def start_link do
    {:ok, method_caller} = RPC.MethodCaller.start_link name: Serverboards.Plugin.RPC
    Serverboards.Utils.Decorators.permission_method_caller method_caller

    RPC.MethodCaller.add_method method_caller, "plugin.start", fn [plugin_component_id], context ->
      if has_perm_for_plugin(context, plugin_component_id) do
        user = RPC.Context.get(context, :user)
        Plugin.Runner.start plugin_component_id, user.email
      else
        {:error, :unknown_method}
      end
    end, context: true

    RPC.MethodCaller.add_method method_caller, "plugin.stop", fn [uuid], context ->
      if has_perm_for_plugin(context, :any) do
        Plugin.Runner.stop uuid
      else
        {:error, :unknown_method}
      end
    end, context: true

    RPC.MethodCaller.add_method method_caller, "plugin.kill", fn [uuid_or_id], context ->
      if has_perm_for_plugin(context, :any) do
        user = RPC.Context.get(context, :user)
        uuid = case UUID.info(uuid_or_id) do
          {:ok, _info} -> uuid_or_id
          _ ->
            case Plugin.Runner.get_by_component_id(uuid_or_id) do
              {:ok, uuid} -> uuid
              _ -> nil
            end
        end
        if uuid do
          Logger.warn("Plugin #{inspect uuid_or_id} killed by #{inspect user.email}", plugin_uuid: uuid, user: user.email)
          Plugin.Runner.kill uuid
        else
          {:error, :not_running}
        end
      else
        {:error, :unknown_method}
      end
    end, context: true

    RPC.MethodCaller.add_method method_caller, "plugin.call", fn
      [id, method, params] ->
        Plugin.Runner.call id, method, params
      [id, method] ->
        Plugin.Runner.call id, method, []
    end, [required_perm: "plugin"]

    RPC.MethodCaller.add_method method_caller, "plugin.alias", fn
      [id, newalias], context ->
        case Plugin.Runner.get(id) do
          :not_found ->
            {:error, :not_found}
          %{ pid: pid } ->
            RPC.Context.update context, :plugin_aliases, [{ newalias, pid }]
            true
          end
    end, [required_perm: "plugin", context: true]

    RPC.MethodCaller.add_method method_caller, "plugin.is_running", fn
      [id], context ->
        if has_perm_for_plugin(context, :any) do
          Plugin.Runner.status(id) == :running
        else
          {:error, :unknown_method}
        end
    end, [required_perm: "plugin", context: true]

    RPC.MethodCaller.add_method method_caller, "plugin.ps", fn
      [] -> Plugin.Runner.ps()
    end, [required_perm: "plugin"]

    RPC.MethodCaller.add_method method_caller, "plugin.catalog", fn
      [] ->
        Serverboards.Plugin.Registry.list
      %{} ->
        Serverboards.Plugin.Registry.list
    end, [required_perm: "plugin"]
    RPC.MethodCaller.add_method method_caller, "plugin.install", fn
      [url] ->
        Serverboards.Plugin.Installer.install(url)
    end, [required_perm: "plugin.install"]

    RPC.MethodCaller.add_method(method_caller, "plugin.data.update", fn
      [ key, value ], context ->
        case check_perm_for_plugin_data( context ) do
          {plugin, user} ->
            Plugin.Data.data_set(plugin, key, value, user)
          _ ->
            {:error, :not_allowed}
        end
      [ plugin, key, value ], context ->
        case check_perm_for_plugin_data( context, plugin ) do
          {plugin, user} ->
            Plugin.Data.data_set(plugin, key, value, user)
          _ ->
            {:error, :not_allowed}
        end
      end,
      context: true)

    RPC.MethodCaller.add_method(method_caller, "plugin.data.get", fn
      [ key ], context ->
        case check_perm_for_plugin_data( context ) do
          {plugin, _user} ->
            {:ok, Plugin.Data.data_get(plugin, key)}
          _ ->
            {:error, :not_allowed}
        end
      [ plugin, key ], context ->
        case check_perm_for_plugin_data( context, plugin ) do
          {plugin, _user} ->
            {:ok, Plugin.Data.data_get(plugin, key)}
          _ ->
            {:error, :not_allowed}
        end
      end,
      context: true)

    RPC.MethodCaller.add_method method_caller, "plugin.data.list", fn
      [ plugin, keyprefix ], context ->
        case check_perm_for_plugin_data( context, plugin ) do
          {plugin, _user} ->
            {:ok, Plugin.Data.data_keys(plugin, keyprefix)}
          _ ->
            {:error, :not_allowed}
        end
      [ keyprefix ], context ->
        case check_perm_for_plugin_data( context ) do
          {plugin, _user} ->
            {:ok, Plugin.Data.data_keys(plugin, keyprefix)}
          _ ->
            {:error, :not_allowed}
        end
    end, context: true
    RPC.MethodCaller.add_method method_caller, "plugin.data.items", fn
      [ plugin, keyprefix ], context ->
        case check_perm_for_plugin_data( context, plugin ) do
          {plugin, _user} ->
            {:ok, Plugin.Data.data_items(plugin, keyprefix)}
          _ ->
            {:error, :not_allowed}
        end
      [ keyprefix ], context ->
        case check_perm_for_plugin_data( context ) do
          {plugin, _user} ->
            {:ok, Plugin.Data.data_items(plugin, keyprefix)}
          _ ->
            {:error, :not_allowed}
        end
    end, context: true

    RPC.MethodCaller.add_method method_caller, "plugin.data.delete",
        fn [ plugin, key ], context ->
      user = RPC.Context.get context, :user
      perms = user.perms
      can_data = (
        ("plugin.data" in perms) or
        ("plugin.data[#{plugin}]" in perms)
        )
      if can_data do
        {:ok, Plugin.Data.data_remove(plugin, key, user)}
      else
        Logger.debug("Perms #{inspect perms}, not plugin.data, nor plugin.data[#{plugin}]")
        {:error, :not_allowed}
      end
    end, context: true


    RPC.MethodCaller.add_method method_caller, "plugin.component.catalog", fn
      [] ->
        []
          |> Serverboards.Plugin.Registry.filter_component
          |> Serverboards.Utils.clean_struct
      [ filter ] ->
        Serverboards.Utils.keys_to_atoms_from_list(filter, ~w"type id trait traits")
          |> Serverboards.Plugin.Registry.filter_component
          |> Serverboards.Utils.clean_struct
      %{} = filter ->
        Serverboards.Utils.keys_to_atoms_from_list(filter, ~w"type id trait traits")
          |> Serverboards.Plugin.Registry.filter_component
          |> Serverboards.Utils.clean_struct
    end

    # Catches all [UUID].method calls and do it. This is what makes call plugin by uuid work.
    RPC.MethodCaller.add_method_caller method_caller, &call_with_uuid(&1),
      [required_perm: "plugin", name: :call_with_uuid]

    # Catches all [alias].method calls and do it. Alias are stores into the context
    RPC.MethodCaller.add_method_caller method_caller, &call_with_alias(&1),
      [required_perm: "plugin", name: :call_with_alias]

    {:ok, method_caller}
  end


  # Method caller function UUID.method.
  def call_with_uuid(%MOM.RPC.Message{ method: method, params: params, context: _context}) do
    #Logger.debug("Try to call #{inspect msg}")
    if method == "dir" do
      {:ok, []} # Do not return it as it can lead to show of opaque pointers. Use alias.
    else
      case Regex.run(~r/(^[-0-9a-f]{36})\.(.*)$/, method) do
        [_, id, method] ->
          res = Plugin.Runner.call id, method, params
          #Logger.debug("UUID result #{inspect res}")
          res
        _ -> :nok
      end
    end
  end

  def call_with_alias(%MOM.RPC.Message{ method: method, params: params, context: context}) do
    if method == "dir" do
      {:ok, alias_dir(context)}
    else
      case Regex.run(~r/(^[^.]+)\.(.*)$/, method) do
        [_, alias_, method] ->
          aliases = RPC.Context.get context, :plugin_aliases, %{}
          cmd = Map.get aliases, alias_
          #Logger.debug("Call with alias #{inspect alias_}")
          cond do
            cmd == nil ->
              #Logger.debug("Not alias")
              :nok
            Process.alive? cmd ->
              ret=Serverboards.IO.Cmd.call cmd, method, params
              Logger.debug("Alias result #{inspect ret}")
              ret
            true ->
              # not running anymore, remove it
              Logger.debug("Plugin not running anymore")
              RPC.Context.update context, :plugin_aliases, [{ alias_, nil }]
              :nok
          end
        _ -> :nok
      end
    end
  end

  # returns a list of all known methods that use alias
  defp alias_dir(context) do
    aliases = RPC.Context.get context, :plugin_aliases, %{}
    ret = aliases
      |> Enum.flat_map(fn {alias_, cmd} ->
        try do
          if Process.alive? cmd do
            {:ok, res} = Serverboards.IO.Cmd.call cmd, "dir", []
            res |> Enum.map(fn d ->
                #Logger.debug("Got function #{alias_} . #{d}")
                "#{alias_}.#{d}"
              end)
          else
            # remove from aliases
            RPC.Context.update context, :plugin_aliases, [{alias_, nil}]
            []
          end
        rescue
          e ->
            Logger.error("Plugin with alias #{alias_} #{inspect cmd} does not implement dir. Fix it.\n#{inspect e}\n#{Exception.format_stacktrace}")
            []
        end
      end)
    #Logger.debug("Alias methods are: #{inspect ret}")
    ret
  end

end
