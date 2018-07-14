defmodule ChatWeb.UserChannel do
  use ChatWeb, :channel
  alias Chat.Models.User, as: User
  alias Chat.Modules.UserInfo, as: UserInfo

  def join("user:lobby", _, socket) do
    case Chat.Repo.get(User, socket.assigns.user_id) do
      %User{} = user ->
        {:ok, %{
          id: user.id,
          display_name: user.display_name,
          avatar: user.avatar,
          blocked: UserInfo.get_blocked(user.id),
          friends: UserInfo.get_friends(user.id)
        }, socket}
      _ -> {:error, %{reason: "not found"}}
    end
  end

  def handle_in("change", %{"user" => user}, socket) do
    if socket.topic == "user:lobby" do
      user = User.change_info(socket.assigns.user_id, user)
      case user do
        {:ok, user_info} ->
              ChatWeb.Endpoint.broadcast "user:"<>Integer.to_string(socket.assigns.user_id), "changed", %{user: %{
                id: user_info.id,
                username: user_info.display_name,
                avatar_url: user_info.avatar
              }}
              {:reply,:ok, socket}
        {:error, :wrong_parameter} -> {:reply, {:error, %{reason: "wrong payload"}}, socket}
        {:error, :wrong_user_object} -> {:reply, {:error, %{reason: "wrong user object"}}, socket}
        {:error, :wrong_data} -> {:reply, {:error, %{reason: "wrong data"}}, socket}
        {:error, :not_found} -> {:reply, {:error, %{reason: "user not found"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "wrong endpoint"}}, socket}
    end
  end

  def handle_in("find", %{"search" => q}, socket) do
    if socket.topic == "user:lobby" do
      users = User.find(q)
      case users do
        {:error, :wrong_query} -> {:reply,{:error, %{reason: "wrong query or query too short"}}, socket}
        {:error, :wrong_parameter} -> {:reply, {:error, %{reason: "wrong data"}}, socket}
        _ -> {:reply, {:ok, %{users: User.find(q)}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in this channel"}}, socket}
    end
  end

  def join("user:" <> user_id, _, socket) do
    case Integer.parse(user_id) do
      {id, ""} ->
        case Chat.Repo.get(User, id) do
          %User{} = user ->
            {:ok, %{
              id: user.id,
              display_name: user.display_name,
              avatar: user.avatar,
              is_online: Chat.Modules.OnlineUsers.is_online?(id)
            }, socket}
          _ -> {:error, %{reason: "not found"}}
        end
      _ -> {:error, %{reason: "wrong id"}}
    end
  end

  def handle_in("block", _, socket) do
    if(socket.topic != "user:lobby") do
      user_id = socket.topic
                |> String.slice(5..-1)
                |> Integer.parse()
      case user_id do
        {uid, ""} ->
          if uid != socket.assigns.user_id do
          case User.block_user(socket.assigns.user_id, uid) do
            {:ok, _} ->
              Chat.Modules.UserInfo.block_user(socket.assigns.user_id, uid)
              ChatWeb.Endpoint.broadcast "notify:"<> Integer.to_string(socket.assigns.user_id), "blocked", %{user_id: uid}
              {:reply, :ok, socket}
            false ->
              {:reply, {:error, %{reason: "this user is already blocked or you cannot block yourself"}}, socket}
            {:error, :wrong_parameter} ->  {:reply, {:error, %{reason: "wrong data"}}, socket}
          end
        else
            {:reply, {:error, %{reason: "You can not block yourself!"}}, socket}
        end
        _ -> {:reply, {:error, %{reason: "wrong id"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "wrong endpoint"}}, socket}
    end
  end

  def handle_in("unblock", _, socket) do
    if (socket.topic != "user:lobby") do
      user_id = socket.topic
                |> String.slice(5..-1)
                |> Integer.parse()
      case user_id do
        {uid, ""} ->
          case User.delete_blocked_user(socket.assigns.user_id, uid) do
            {:ok, _} ->
              Chat.Modules.UserInfo.unblock_user(socket.assigns.user_id, uid)
              ChatWeb.Endpoint.broadcast "notify:"<> Integer.to_string(socket.assigns.user_id), "unblocked", %{user_id: uid}
              {:reply, :ok, socket}
            false ->
              {:reply, {:error, %{reason: "this user is not blocked"}}, socket}
            {:error, :wrong_parameter} ->  {:reply, {:error, %{reason: "wrong data"}}, socket}
          end
        _ -> {:reply, {:error, %{reason: "wrong id"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "wrong endpoint"}}, socket}
    end
  end

  def handle_in(_, _, socket) do
    {:reply, {:error, %{reason: "wrong endpoint"}}, socket}
  end
end
