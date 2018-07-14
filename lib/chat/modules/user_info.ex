defmodule Chat.Modules.UserInfo do
  use GenServer
  require Logger
  alias Chat.Models.User, as: User
  @moduledoc false

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: :user_info)
  end

  def get_friends(user_id) do
    {friends, _blocked} = get_info(user_id)
    friends
  end

  def get_blocked(user_id) do
    {_friends, blocked} = get_info(user_id)
    blocked
  end

  def add_friends(user_id, friends) do
    {f,b} = get_info(user_id)
    friends = Enum.uniq(friends)
    friends = Enum.filter(friends, fn x -> !Enum.member?(f, x) && is_integer(x) && x > 0 end)
    unless Enum.empty?(friends) do
      case User.add_friends(user_id, friends) do
        {:ok, user} -> add_info(user_id, user.friends, b)
        _error ->
          Logger.error("#{inspect _error}")
          :error
      end
    end
  end

  def del_friend(user_id, friend_id) do
    {f,b} = get_info(user_id)

    if friend_id in f do
      case User.del_friend(user_id, friend_id) do
        {:ok, user} ->add_info(user_id, user.friends, b)
        _error ->
          Logger.error("#{inspect _error}")
          :error
      end
    end
  end

  def block_user(user_id, block_id) do
    if user_id != block_id do
      {f,b} = get_info(user_id)
      b = [block_id | b]
      add_info(user_id, f ,b)
    end
  end

  def unblock_user(user_id, block_id) do
    {f,b} = get_info(user_id)
    b = Enum.filter(b, fn x -> x != block_id end)
    add_info(user_id, f ,b)
  end

  def is_blocked?(user_id, uid) do
    {f,b} = get_info(user_id)
    Logger.debug("[night] #{inspect b}")
    Enum.member?(b, uid)
  end

  def add_info(user_id, friends, blocked) when is_list(friends) and is_list(blocked) do
    GenServer.call(:user_info, {:add_info, user_id, friends, blocked})
  end

  def add_info(user_id, friends, _) when is_list(friends) do
    GenServer.call(:user_info, {:add_info, user_id, friends, []})
  end

  def add_info(user_id, _, blocked) when is_list(blocked) do
    GenServer.call(:user_info, {:add_info, user_id, [], blocked})
  end

  def add_info(user_id, _, _) do
    GenServer.call(:user_info, {:add_info, user_id, [], []})
  end

  def del_info(user_id) do
    GenServer.call(:user_info, {:del_info, user_id})
  end

  defp get_info(user_id) do
    GenServer.call(:user_info, {:get_info, user_id})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:add_info, user_id, friends, blocked}, _from, info) do
    info = Map.put(info, user_id, {friends, blocked})
    {:reply, :ok, info}
  end

  def handle_call({:get_info, user_id}, _from, state) do
    info = Map.get_lazy(state, user_id, fn -> {[], []} end)
    {:reply, info, state}
  end

  def handle_call({:del_info, user_id}, _from, state) do
    state = Map.delete(state, user_id)
    {:reply, :ok, state}
  end

end
