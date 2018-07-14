defmodule ChatWeb.ConversationChannel do
  use ChatWeb, :channel
  require Logger
  alias Chat.Models.User, as: User
  alias Chat.Models.Conversation, as: Conversation
  alias Chat.Models.Message, as: Message

  intercept ["new_msg", "read"]

  def join("conversation:lobby", _, socket) do
      Logger.debug("#{inspect socket}")
      {:ok,
        User.get_conversations(socket.assigns.user_id)
        |> Enum.map(fn conversation ->
          %{
            id: conversation.id,
            avatar: conversation.avatar,
            name: conversation.name
          }
        end),
      socket}
  end

  def handle_in("create", %{"users" => users, "title" => name}, socket) do
    if socket.topic == "conversation:lobby" do
      case Conversation.new(name, [socket.assigns.user_id | users]) do
        {:ok, conversation} ->
          Enum.each(conversation.users, fn user ->
            ChatWeb.Endpoint.broadcast("notify:"<> Integer.to_string(user.id), "added", %{conversation_id: conversation.id})
          end)
          {:reply, {:ok, %{id: conversation.id, name: conversation.name, avatar: conversation.avatar}}, socket}
        {:error, :no_users} -> {:reply, {:ok, %{reason: "not enough users"}}, socket}
        _ -> {:reply, {:error, %{reason: "not created"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can do that only in lobby"}}, socket}
    end
  end

  def handle_in("create", _, socket) do
    {:reply, {:error, %{reason: "wrong parameters"}}, socket}
  end

  def handle_in("list", _, socket) do
    Logger.debug("#{inspect socket}")
    if socket.topic == "conversation:lobby" do
      {:reply, {:ok, %{conversations:
        Chat.Models.User.get_conversations(socket.assigns.user_id)
        |> Enum.map(fn conversation ->
                      %{
                        id: conversation.id,
                        avatar: conversation.avatar,
                        name: conversation.name
                      }
        end)
      }}, socket}
    else
      {:reply, {:error, %{reason: "you can do that only in lobby"}}, socket}
    end
  end

  def join("conversation:" <> conversation_id, _, socket) do # endwhen Chat.Modules.Commons.is_numeric(conversation_id) do
    case Integer.parse(conversation_id) do
      {conversation_id, ""} ->
        if Conversation.in_conversation?(conversation_id, socket.assigns.user_id) do
          conversation = Chat.Repo.get(Conversation, conversation_id)
          if conversation != nil do
            Chat.Modules.UsersInConversation.joined(conversation_id, socket.assigns.user_id, socket)
            {:ok, %{
              id: conversation.id,
              title: conversation.name,
              user: Conversation.get_users(conversation_id),
              messages: Conversation.get_messages(conversation_id, socket.assigns.user_id)
            }, socket}
          else
            {:error, %{reason: "conversation not found"}}
          end
        else
          {:error, %{reason: "conversation not found or you do not have access to it"}}
        end
      _ -> {:error, %{reason: "wrong conversation id"}}
    end

  end

  def handle_in("change", %{"conversation" => conversation}, socket) do
    if socket.topic != "conversation:lobby" do
      conversation_id = socket.topic
                        |> String.slice(13..-1)
                        |> Integer.parse()
      case conversation_id do
        {cid, ""} ->
          conv = Conversation.change_info(cid, conversation)
          case conv do
            {:ok, conv_info} -> broadcast socket, "changed", %{conversation: %{id: conv_info.id, title: conv_info.name, avatar: conv_info.avatar}}
                                {:reply, :ok, socket}
            {:error, :wrong_parameter} -> {:reply, {:error, %{reason: "wrong payload"}}, socket}
            {:error, :wrong_data} -> {:reply, {:error, %{reason: "wrong data"}}, socket}
            {:error, :not_found} -> {:reply, {:error, %{reason: "conversation not found"}}, socket}
            {:error, :wrong_conversation} -> {:reply, {:error, %{reason: "wrong conversation object"}}, socket}
          end
        _ -> {:reply, {:error, %{reason: "wrong conversation id"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in lobby"}}, socket}
    end
  end

  def handle_in("read", %{"message_id" => msg_id}, socket) do
    if socket.topic != "conversation:lobby" do
      conversation_id = socket.topic
                        |> String.slice(13..-1)
                        |> Integer.parse()
      case conversation_id do
        {cid, ""} ->
          case Message.read_by(msg_id, cid, socket.assigns.user_id) do
            {:ok, _} ->
              broadcast socket, "read", %{user_id: socket.assigns.user_id, message_id: msg_id}
              {:reply, :ok, socket}
            _ -> {:reply, {:error, %{reason: "wrong message id"}}, socket}
          end
        _ -> {:reply, {:error, %{reason: "wrong conversation id"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in lobby"}}, socket}
    end
  end

  def handle_in("more", %{"id" => last_known_message_id}, socket) do
    if socket.topic != "conversation:lobby" do
      conversation_id = socket.topic
                        |> String.slice(13..-1)
                        |> Integer.parse()
      case conversation_id do
        {cid, ""} ->
          {:reply,
          {:ok, %{
                  messages: Conversation.get_messages(cid,last_known_message_id,20,socket.assigns.user_id),
                  count: Conversation.get_message_count(cid)
                 }},
          socket}
         _ -> {:reply, {:error, %{reason: "not found"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in lobby"}}, socket}
    end
  end

  def handle_in("add", %{"user_id" => user_id}, socket) do
    if socket.topic != "conversation:lobby" do
      conversation_id = socket.topic
                        |> String.split(":")
                        |> Enum.at(1)
                        |> Integer.parse()
      case conversation_id do
        {cid, ""} ->
          case Conversation.add_user(cid, user_id) do
            {:ok, user} ->
              broadcast socket, "added", %{user_id: user_id, user: %{id: user.id, display_name: user.display_name, avatar: user.avatar}}
              ChatWeb.Endpoint.broadcast "notify:"<> Integer.to_string(user_id), "added", %{conversation_id: cid}
              {:reply, :ok, socket}
            _ -> {:reply, {:error, %{reason: "cannot add user"}}, socket}
          end
        _ -> {:reply, {:error, %{reason: "not found"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in lobby"}}, socket}
    end
  end

  def handle_in("remove", %{"user_id" => user_id}, socket) do
    if socket.topic != "conversation:lobby" do
      conversation_id = socket.topic
                        |> String.split(":")
                        |> Enum.at(1)
                        |> Integer.parse()
      case conversation_id do
        {cid, ""} ->
          case Conversation.remove_user(cid, user_id) do
            {:ok, _} ->
              broadcast socket, "removed", %{user_id: user_id}
              ChatWeb.Endpoint.broadcast "notify:"<> Integer.to_string(user_id), "removed", %{conversation_id: cid}
              Chat.Modules.UsersInConversation.remove(cid, user_id)
              {:reply, :ok, socket}
            _error ->
              Logger.error("#{inspect _error}")
              {:reply, {:error, %{reason: "cannot remove user"}}, socket}
          end
        _ -> {:reply, {:error, %{reason: "not found"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in lobby"}}, socket}
    end
  end

  def handle_in("msg", %{"type" => type, "content" => content}, socket) do
    if socket.topic != "conversation:lobby" do
      conversation_id = socket.topic
            |> String.split(":")
            |> Enum.at(1)
            |> Integer.parse()
      case conversation_id do
        {cid, ""} ->
          if Conversation.in_conversation?(cid, socket.assigns.user_id) do
            case Message.new(socket.assigns.user_id, type, content, cid) do
              {:ok, msg} ->
                broadcast socket, "new_msg", %{
                  author: %{
                    id: socket.assigns.user_id,
                    display_name: msg.user.display_name,
                    avatar: msg.user.avatar

                  },
                  timestamp: msg.inserted_at,
                  type: type,
                  content: content,
                  read_by: [],
                  id: msg.id
                }
                {:reply, {:ok, %{message_id: msg.id}}, socket}
              _ ->
                {:noreply, socket}
            end
          end
          _ -> {:reply, {:error, %{reason: "wrong conversation id"}}, socket}
      end
    else
      {:reply, {:error, %{reason: "you can not do that in lobby"}}, socket}
    end
  end

  def handle_in(_, _, socket) do
    {:reply, {:error, %{reason: "wrong endpoint"}}, socket}
  end

  def handle_out("new_msg", %{author: %{id: uid}} = msg, socket) do
    Logger.debug("[night] #{inspect uid} #{inspect socket.assigns.user_id}")
    unless Chat.Modules.UserInfo.is_blocked?(socket.assigns.user_id, uid) do
      push socket, "new_msg", msg
    end
    {:noreply, socket}
  end

  def handle_out("read", %{user_id: user_id} = msg, socket) do
    unless Chat.Modules.UserInfo.is_blocked?(socket.assigns.user_id, user_id) do
      push socket, "read", msg
    end
    {:noreply, socket}
  end
end
