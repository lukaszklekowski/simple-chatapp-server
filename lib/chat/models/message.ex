defmodule Chat.Models.Message do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger
  alias Chat.Models.Message, as: Message
  alias Chat.Models.User, as: User
  alias Chat.Models.Conversation, as: Conversation
  alias Chat.Modules.UserInfo, as: UserInfo
  
  schema "messages" do
    field :content, :string
    field :hidden_by, {:array, :integer}, default: []
    field :read_by, {:array, :integer}, default: []
    field :type, :string

    belongs_to :user, User
    belongs_to :conversation, Conversation

    timestamps()
  end

  @doc false
  def changeset(%Message{} = message, attrs) do
    message
    |> cast(attrs, [:type, :content, :read_by, :hidden_by])
    |> validate_required([:type, :content])
    |> validate_length(:content, min: 1, max: 20000)
    |> validate_length(:type, min: 1, max: 255)
  end

  @doc """
  Function for creating new message.

  Parameters:
  `user_id` - ID of author.<br />
  `type` - message type.<br />
  `content` - content of message.<br />
  `conversation_id` ID of conversation for message.<br />

  Return Touple:
  On success: `{:ok, message}`, where message is created message<br />
  On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def new(user_id, type, content, conversation_id) when is_integer(user_id) and is_integer(conversation_id) do
    case Chat.Repo.get(User, user_id) do
      %User{} = user ->
        IO.inspect(user)
        case Chat.Repo.get(Conversation, conversation_id) do
          %Conversation{} = conversation ->
            message = Message.changeset(%Message{}, %{content: content, type: type})
            # message = Chat.Repo.preload(message, [:user, :conversation])
            message = put_assoc(message, :user, user)
            message = put_assoc(message, :conversation, conversation)
            Chat.Repo.update Conversation.changeset(conversation, %{message_count: conversation.message_count + 1})

            try do
              conversation = Chat.Repo.preload(conversation, :users)
              UserInfo.add_friends(user_id, conversation.users |> Enum.map(fn u -> u.id end))
            rescue
              _error ->
                Logger.debug("[#{inspect _error}]")
            end

            Chat.Repo.insert message
          _ -> {:error, :not_found}
        end
      _ -> {:error, :not_found}
    end
  end

  def new(_, _, _, _) do
    {:error, :wrong_parameter}
  end

  @doc """
  Function for setting who read the message.

  We are requesting conversation_id for weryfication.

  Parameters:
  `msg_id` - ID of message.<br />
  `conversation_id` ID of conversation for message.<br />
  `user_id` - ID of user that read message.<br />

  Return Touple:
  On success: `{:ok, message}`, where message is created message<br />
  On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """
  def read_by(msg_id, conversation_id, user_id) when is_integer(msg_id) and is_integer(conversation_id) and is_integer(user_id) do
      msg = Chat.Repo.get_by(Message, %{conversation_id: conversation_id, id: msg_id})
      if msg do
          Conversation.read(conversation_id, user_id, msg_id)
          case msg.read_by do
            nil ->
             Chat.Repo.update Message.changeset(msg, %{read_by: [user_id]})
            _->
              if !(user_id in msg.read_by) do
                Chat.Repo.update Message.changeset(msg, %{read_by: [user_id | msg.read_by]})
              end
          end
          {:ok, msg}
    else
      {:error, :not_found}
    end
  end

  def read_by(_,_,_) do
    {:error, :wrong_parameter}
  end
end
