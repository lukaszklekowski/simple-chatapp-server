defmodule ChatWeb.UserSocket do
  use Phoenix.Socket
  alias Chat.Modules.OnlineUsers, as: OnlineUsers
  alias Chat.Modules.UserInfo, as: UserInfo
  alias Chat.Models.User, as: User

  ## Channels
  # channel "room:*", ChatWeb.RoomChannel
  channel "notify:*", ChatWeb.NotifyChannel
  channel "conversation:*", ChatWeb.ConversationChannel
  channel "user:*", ChatWeb.UserChannel

  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket
  transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"token" => token}, socket) do
    case User.verify_access_token(token) do
      {:ok, user} ->
        IO.inspect(socket.transport_pid)
        OnlineUsers.logged_in(socket.transport_pid, user.id)
        UserInfo.add_info(user.id, user.friends, user.blocked_users)
        {:ok, assign(socket, :user_id, user.id)}
      _ -> :error
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     ChatWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
