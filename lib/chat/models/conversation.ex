defmodule Chat.Models.Conversation do
  @moduledoc """
  Ecto Model for Conversation table.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger
  alias Chat.Models.Conversation, as: Conversation
  alias Chat.Models.User, as: User
  alias Chat.Models.Message, as: Message


  schema "conversations" do
    field :avatar, :string
    field :message_count, :integer, default: 0
    field :name, :string
    field :read_by, :map, default: %{}

    many_to_many :users, User, [join_through: "conversations_users", on_replace: :delete, on_delete: :delete_all]
    has_many :messages, Message

    timestamps()
  end

  @doc """
    Function for creating new conversations.

    Parameters:<br />
    `name` - Name of created conversation. Requires binaary value.<br />
    `users` - Users that will take part in conversation. Requires list.

    Returns Tuple:<br/>
    On success: `{:ok, conversation}`, where conversation is created conversation.<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def new(name, users) when is_list(users) and is_binary(name) do
    c = Conversation.changeset(%Conversation{}, %{name: name})
    users = Enum.filter(users, & is_integer(&1))
            |> Enum.uniq
            |> Enum.map(fn x -> Chat.Repo.get(User, x) end)
            |> Enum.filter(& &1)
    if length(users) > 0 do
      Chat.Repo.insert put_assoc(c, :users, users)
    else
      {:error, :no_users}
    end
  end

  def new(_, _) do
    {:error, :wrong_parameter}
  end

  @doc """
    Function for setting recently readed message for user on conversation.

    Do not allow changing back.

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer<br />
    `user_id` - ID of user. Requires integer<br />
    `message_id` - ID of message. Requires integer

    Returns Tuple:<br/>
    On success: `{:ok, nil}`<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def read(conversation_id, user_id, message_id) when is_integer(conversation_id) and is_integer(user_id) and is_integer(message_id) do
    case Chat.Repo.get(Conversation, conversation_id) do
      %Conversation{} = conversation ->
        read_by = conversation.read_by
        if Map.get_lazy(read_by, user_id, fn -> 0 end) < message_id do
          Chat.Repo.update Conversation.changeset(conversation, %{read_by: read_by})
        end
        {:ok, nil}
      _ -> {:error, :not_found}
    end
  end

  def read(_, _, _) do
    {:error, :wrong_parameter}
  end

  @doc """
    Check if user is in conversation?

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer or binary<br />
    `user_id` - ID of user. Requires integer<br />

    Returns boolean.
  """
  def in_conversation?(conversation_id, user_id) when is_binary(conversation_id) and is_integer(user_id) do
    case Integer.parse(conversation_id) do
      {id, ""} ->
        in_conversation?(id, user_id)
      _ -> false
    end
  end

  def in_conversation?(conversation_id, user_id) when is_integer(conversation_id) and is_integer(user_id) do
    users = get_users(conversation_id) |> Enum.map(fn user -> user.id end)
    user_id in users
  end

  def in_conversation?(_, _) do
    false
  end

  @doc """
    Function for adding user to conversation.

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer<br />
    `user_id` - ID of user. Requires integer

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is added user<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def add_user(conversation_id, user_id) when is_integer(conversation_id) and is_integer(user_id) do
    conversation = Chat.Repo.get(Conversation, conversation_id)
    if conversation do
      try do
        c = Chat.Repo.preload(conversation, :users)
        user = Chat.Repo.get(User, user_id)
        if user != nil do
          if user in c.users do
            {:ok, user}
          else
            Chat.Repo.update put_assoc(Conversation.changeset(c, %{}), :users, [user | c.users])
            {:ok, user}
          end
        else
          {:error, :not_found}
        end
      rescue
        _ -> {:error, :preload}
      end
    else
      {:error, :not_found}
    end
  end

  def add_user(_, _) do
    {:error, :wrong_parameter}
  end

  @doc """
    Function for removing user from conversation.

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer<br />
    `user_id` - ID of user. Requires integer

    Returns Tuple:<br/>
    On success: `{:ok, conversation}`, where conversation is conversation that changed.<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def remove_user(conversation_id, user_id) when is_integer(conversation_id) and is_integer(user_id) do
    conversation = Chat.Repo.get(Chat.Models.Conversation, conversation_id)
    if conversation do
      try do
        c = Chat.Repo.preload(conversation, :users)
        user = Chat.Repo.get(User, user_id)
        if user != nil do
          if user in c.users do
            users = c.users
                    |> Enum.filter(fn u -> u.id != user_id end)
            Chat.Repo.update put_assoc(Conversation.changeset(c, %{}), :users, users)
          else
            {:ok, c}
          end
        else
          {:error, :not_found}
        end
      rescue
        _error ->
          Logger.error("#{inspect _error}")
          {:error, :preload}
      end
    else
      {:error, :not_found}
    end
  end

  def remove_user(_, _) do
    {:error, :wrong_parameter}
  end

  @doc """
    Function for getting messages from conversation for specified user.

    We request user_id, becouse we do not want to show user messages from users that he has blocked.

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer<br />
    `user_id` - ID of user. Requires integer

    Returns list of messages.
  """
  def get_messages(conversation_id, user_id) when is_integer(conversation_id) and is_integer(user_id) do
    from(
      m in Message,
      preload: [:user],
      where: m.conversation_id == ^conversation_id and not (m.user_id in ^Chat.Modules.UserInfo.get_blocked(user_id)),
#      select: %{id: m.id, type: m.type, content: m.content, timestamp: m.inserted_at, author: %{id: m.user_id}, read_by: m.read_by, user: m.user},
      order_by: [desc: m.id],
      limit: 20,
    )
    |> Chat.Repo.all
    |> Enum.map(fn m -> %{id: m.id, type: m.type, content: m.content, timestamp: m.inserted_at, author: %{id: m.user_id, avatar: m.user.avatar, display_name: m.user.display_name}, read_by: m.read_by } end)
  end

  def get_messages(_,_) do
    {:error, :wrong_parameter}
  end

  @doc """
    Function for getting messages from conversation for specified user.

    We request user_id, becouse we do not want to show user messages from users that he has blocked.

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer<br />
    `before_id` - ID of oldest known message. Requires integer<br />
    `count` - Amount of requested messages. Requires integer<br />
    `user_id` - ID of user. Requires integer

    Returns list of messages.
  """
  def get_messages(conversation_id, before_id, count, user_id) when is_integer(conversation_id) and is_integer(before_id) and is_integer(count) and is_integer(user_id) do
    count = max(min(count, 50), 20)
    from(
      m in Message,
      preload: [:user],
      where: m.conversation_id == ^conversation_id and m.id < ^before_id and not (m.user_id in ^Chat.Modules.UserInfo.get_blocked(user_id)),
#      select: %{id: m.id, type: m.type, content: m.content, timestamp: m.inserted_at, author: %{id: m.user_id}, read_by: m.read_by},
      order_by: [desc: m.id],
      limit: ^count
    )
    |> Chat.Repo.all
    |> Enum.map(fn m -> %{id: m.id, type: m.type, content: m.content, timestamp: m.inserted_at, author: %{id: m.user_id, avatar: m.user.avatar, display_name: m.user.display_name}, read_by: m.read_by } end)
  end

  def get_messages(_, _, _, _) do
    {:error, :wrong_parameter}
  end

  @doc """
    Get users of conversations.

    Parameters:<br />
    `conversation_id` - ID of conversation. Requires integer<br />

    Returns list of users.
  """
  def get_users(conversation_id) when is_integer(conversation_id) do
    case Chat.Repo.get(Conversation, conversation_id) do
      %Conversation{} = conversation ->
        conversation = Chat.Repo.preload(conversation, :users)
        conversation.users
        |> Enum.map(fn user ->
          %{id: user.id, display_name: user.display_name, avatar: user.avatar}
        end)
      _ -> []
    end
  end

  def get_users(_) do
    {:error, :wrong_parameter}
  end

  @doc """
    Function for getting amount of messages in conversation.

    Parameters:<br />
    `con_id` - ID of conversation. Requires integer<br />

    Returns message count as integer.
  """
  def get_message_count(con_id) do
    conversation = Chat.Repo.get(Conversation, con_id)
    conversation.message_count
  end

  @doc """
    Function for changing conversation details.


    Parameters:<br />
    `con_id` - ID of conversation. Requires integer<br />
    `%{"id" => c_id, "title" => con_name, "avatar" => con_avatar}`, where id is conversation ID, title is conversation title and avatar is conversation avatar.

    Returns Tuple:<br/>
    On success: `{:ok, conversation}`, where conversation is conversation that changed.<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def change_info(con_id, %{"id" => c_id, "title" => con_name, "avatar" => con_avatar}) when is_integer(con_id) and is_binary(con_name) do
    if con_id != c_id do
      {:error, :wrong_conversation}
    else
      conversation = Chat.Repo.get(Conversation, con_id)
      if conversation do
        conv = Chat.Repo.update Conversation.changeset(conversation, %{name: con_name, avatar: con_avatar})
        case conv do
          {:ok, conv_info} -> {:ok, conv_info}
          _ -> {:error, :wrong_data}
        end
      else
      {:error, :not_found}
      end
    end
  end

  def change_info(_,_) do
    {:error, :wrong_parameter}
  end

  @doc false
  def changeset(%Conversation{} = conversation, attrs) do
    conversation
    |> cast(attrs, [:name, :avatar, :message_count, :read_by])
    |> validate_length(:name, min: 3, max: 255)
  end
end
