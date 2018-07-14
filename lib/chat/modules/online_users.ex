defmodule Chat.Modules.OnlineUsers do
  @moduledoc false
  use GenServer
  require Logger
  alias Chat.Modules.UserInfo, as: UserInfo


  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: :online_users)
  end


  def logged_in(pid, user_id) do
    GenServer.call(:online_users, {:logged_in, pid, user_id})
  end

  def is_online?(user_id) do
    GenServer.call(:online_users, {:check_online, user_id})
  end

  def init(:ok) do
    refs = %{}
    connections = %{}
    {:ok, {refs, connections}}
  end

  def handle_call({:check_online, user_id}, _from, {_refs, connections} = state) do
    conns = Map.get_lazy(connections, user_id, fn -> 0 end)
    {:reply, conns > 0, state}
  end

  def handle_call({:logged_in, pid, user_id}, _from, {refs, connections}) do
    ref = Process.monitor(pid)
    refs = Map.put(refs, ref, user_id)
    Logger.debug("#{inspect ref} - Triggered log in")
    connections = Map.put(connections, user_id, Map.get_lazy(connections, user_id, fn -> 0 end) + 1)
    ChatWeb.Endpoint.broadcast("user:"<> Integer.to_string(user_id), "logged_in", %{})
    {:reply, :ok, {refs, connections}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {refs, connections}) do
    Logger.debug("#{inspect ref} - Triggered log out")
    {user_id, refs} = Map.pop(refs, ref)
    Logger.debug("#{inspect user_id} - Got user id")
    if user_id != nil do
      conns = Map.get_lazy(connections, user_id, fn -> 1 end) - 1
      if conns == 0 do
        connections = Map.delete(connections, user_id)
        ChatWeb.Endpoint.broadcast("user:"<> Integer.to_string(user_id), "logged_out", %{})
        UserInfo.del_info(user_id)
        {:noreply, {refs, connections}}
      else
        connections = Map.put(connections, user_id, conns)
        {:noreply, {refs, connections}}
      end
    else
      {:noreply, {refs, connections}}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

end
