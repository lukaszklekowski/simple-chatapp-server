defmodule Chat.Modules.UsersInConversation do
  @moduledoc false
  use GenServer
  require Logger


  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: :users_in_conversation)
  end

  def joined(conversation_id, user_id, socket) do
    GenServer.call(:users_in_conversation, {:joined, conversation_id, user_id, socket})
  end

  def remove(conversation_id, user_id) do
    sockets = GenServer.call(:users_in_conversation, {:lookup, conversation_id, user_id})
    Enum.each(sockets, fn socket ->
      Process.exit(socket.channel_pid, :shutdown) # TODO: Can we do that in more elegant way?
    end)
  end

  def init(:ok) do
    {:ok, {%{}, %{}}}
  end

  def handle_call({:lookup, conversation_id, user_id}, _from, {conversations, _refs} = state) do
    conversation = Map.get_lazy(conversations, conversation_id, fn -> %{} end)
    user = Map.get_lazy(conversation, user_id, fn -> [] end)
    {:reply, user, state}
  end

  def handle_call({:joined, conversation_id, user_id, socket}, _from, {conversations, refs}) do
    ref = Process.monitor(socket.channel_pid)

    conversation = Map.get_lazy(conversations, conversation_id, fn -> %{} end)
    user = [socket | Map.get_lazy(conversation, user_id, fn -> [] end)]
    conversation = Map.put(conversation, user_id, user)
    conversations = Map.put(conversations, conversation_id, conversation)

    refs = Map.put(refs, ref, {conversation_id, user_id})

    {:reply, :ok, {conversations, refs}}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, {conversations, refs}) do
    case Map.pop(refs, ref) do
      {{conversation_id, user_id}, refs} ->
        conversation = Map.get_lazy(conversations, conversation_id, fn -> %{} end)
        user = Map.get_lazy(conversation, user_id, fn -> [] end)
        user = Enum.filter(user, fn socket -> socket.channel_pid != pid end)
        if Enum.empty?(user) do
          conversation = Map.delete(conversation, user_id)
          if Enum.empty?(Map.keys(conversation)) do
            {:noreply, {Map.delete(conversations, conversation_id), refs}}
          else
            {:noreply, {Map.put(conversations, conversation_id, conversation), refs}}
          end
        else
          conversation = Map.put(conversation, user_id, user)
          {:noreply, {Map.put(conversations, conversation_id, conversation), refs}}
        end

      _ -> {:noreply, {conversations, refs}}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

end
