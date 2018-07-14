defmodule Chat.Models.User do
  @moduledoc """
  Ecto Model for User table.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Chat.Models.User, as: User
  alias Chat.Models.Conversation, as: Conversation
  alias Chat.Models.Message, as: Message
  alias Chat.Modules.Token, as: Token

  schema "users" do
    field :avatar, :string
    field :blocked_users, {:array, :integer}
    field :display_name, :string
    field :friends, {:array, :integer}
    field :ip, :string
    field :last_online, :naive_datetime
    field :mail, :string
    field :password, :string
    field :password_token, :string
    field :salt, :string
    field :refresh_token, :string
    field :refresh_token_salt, :string
    field :token, :string
    field :token_salt, :string
    field :token_issued_at, :naive_datetime
    field :type, :string, default: "google"

    many_to_many :conversations, Conversation, [join_through: "conversations_users", on_replace: :delete, on_delete: :delete_all]
    has_many :messages, Message

    timestamps()
  end

  @doc false
  def changeset(%User{} = user, attrs) do
    user
    |> cast(attrs, [:mail, :display_name, :type, :password, :salt, :token, :token_salt, :token_issued_at, :refresh_token, :refresh_token_salt, :password_token, :avatar, :friends, :blocked_users, :last_online, :ip])
    |> validate_required([:mail, :display_name, :ip])
#    |> validate_required([:mail, :type, :google_token, :password, :salt, :token, :token_valid_time, :refresh_token, :password_token, :password_token_valid_time, :avatar, :friends, :blocked_users, :last_online, :ip])
    |> validate_format(:mail, ~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/)
    |> validate_length(:display_name, min: 3, max: 255)
    |> unique_constraint(:mail)
    |> unique_constraint(:token)
    |> unique_constraint(:password_token)
    |> unique_constraint(:refresh_token)
  end

  @doc """
  Function creates users in database.

    Parameters:<br/>
    `mail` - user's mail. Requires string.<br/>
    `display_name` - user's nickname.  Requires string.<br/>
    `avatar` - URL to avatar.  Requires string.<br/>
    `ip` - user's ip.  Requires string.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is inserted or updated user.

  """

  def get_or_create(mail, display_name, avatar, ip) do
    u = Chat.Repo.get_by(User, mail: mail)
    case u do
      nil ->
        Chat.Repo.insert User.changeset(%User{}, %{mail: mail, display_name: display_name, avatar: avatar, ip: ip})
      _ ->
        Chat.Repo.update User.changeset(u, %{ip: ip})
    end
  end

  @doc """
  Function generates refresh token.

    Parameters:<br/>
    `user` - user data from database in ecto schema.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is user with inserted refresh token and refresh token salt.

  """

  def gen_refresh_token(user) do
    Chat.Repo.update User.changeset(user, %{
      refresh_token: :crypto.strong_rand_bytes(128) |> Base.url_encode64,
      refresh_token_salt: :crypto.strong_rand_bytes(12) |> Base.url_encode64 |> binary_part(0, 16)
    })
  end

  @doc """
  Function generates access token.

    Parameters:<br/>
    `user` - user data from database in ecto schema.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is user with inserted token and token salt.

  """
  def gen_access_token(user) do
    Chat.Repo.update User.changeset(user, %{
      token: :crypto.strong_rand_bytes(128) |> Base.url_encode64,
      token_salt: :crypto.strong_rand_bytes(12) |> Base.url_encode64 |> binary_part(0, 16),
      token_issued_at: NaiveDateTime.utc_now
    })
  end


  def get_refresh_token(user) do
    response = cond do
      user.refresh_token == nil ->
        gen_refresh_token(user)
      true ->
        {:ok, user}
    end

    case response do
      {:ok, user} ->
        {:ok, Token.sign(user.refresh_token_salt, %{user_id: user.id, refresh_token: user.refresh_token})}
      {:error, _} ->
        {:error}
    end
  end

  def get_access_token(user) do
    response = cond do
      user.token == nil ->
        gen_access_token(user)
      true ->
        {:ok, user}
    end

    case response do
      {:ok, user} ->
        {:ok, Token.sign(
          user.token_salt,
          %{user_id: user.id, token: user.token},
          signed_at: user.token_issued_at
                     |> DateTime.from_naive!("Etc/UTC")
                     |> DateTime.to_unix
        )}
      {:error, _} ->
        {:error}
    end
  end

  @doc """
  Function gets user's tokens.

    Parameters:<br/>
    `user` - user data from database in ecto schema.

    Returns Tuple:<br/>
    On success: `{:ok, tokens}`, where tokens are user's tokens.
    On fail: `{:error}.
  """

  def get_tokens(user) do
    case User.get_refresh_token(user) do
      {:ok, refresh_token} ->
        case User.get_access_token(user) do
          {:ok, token} -> {:ok, %{refresh_token: refresh_token, token: token}}
          _ -> {:error}
        end
      _ -> {:error}
    end
  end

  @doc """
  Function verifys user's refresh token.

    Parameters:<br/>
    `token` - user's token.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user with veryfied token.
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """

  def verify_refresh_token(token) do
    try do
      %{user_id: user_id} = Token.peek(token)

      user = Chat.Repo.get(User, user_id)

      if user do
        salt = user.refresh_token_salt
        case Token.verify(salt, token) do
          {:ok, %{refresh_token: refresh, user_id: uid}} ->
            if user.id == uid && user.refresh_token == refresh do
              {:ok, user}
            else
              {:error, :invalid}
            end
          _ -> {:error, :invalid}
        end
      else
        {:error, :invalid}
      end

    rescue
      e -> {:error, e}
#      e -> {:error, :internal}
    end
  end

  @doc """
  Function verifys user's access token.

    Parameters:<br/>
    `token` - user's token.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user with veryfied token.
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """

  def verify_access_token(token) do
    try do
      %{user_id: user_id} = Token.peek(token)

      user = Chat.Repo.get(User, user_id)

      if user do
        salt = user.token_salt
        case Token.verify(salt, token, max_age: 604800 * 100) do
          {:ok, %{token: access, user_id: uid}} ->
            if user.id == uid && user.token == access do
              {:ok, user}
            else
              {:error, :invalid}
            end
          _ -> {:error, :invalid}
        end
      else
        {:error, :invalid}
      end
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Function gets user's conversations.

    Parameters:<br/>
    `usr_id` - user's id. Requires integer.

    Returns Tuple:<br/>
    On success: list of conversations.
  """

  def get_conversations(user_id) do
    case Chat.Repo.get(User, user_id) do
      %User{} = user ->
        try do
          user = Chat.Repo.preload(user, :conversations)
          user.conversations
          |> Enum.sort(fn c1,c2 -> NaiveDateTime.diff(c1.updated_at,c2.updated_at, :microseconds) >= 0 end)
        rescue
           _ -> []
        end
      _ -> []
    end
  end
  @doc """
  Function finds users in database.

    Parameters:<br/>
    `q` - String that represents user to find.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is list of found users.<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """

  def find(q) when is_binary(q) do
    q1 = q |> String.replace(~r/\s+/, " ")
           |> String.trim()
           |> String.replace("_", "")
           |> String.replace("%","")
    if String.length(q1 |> String.replace(" ", ""))>=3 do
      q = q1 |> String.replace(" ", "%")
      q = "%" <> q <> "%"
      user = from u in User,
                where: ilike(u.display_name,^q) or ilike(u.mail, ^q),
                select: %{id: u.id, display_name: u.display_name, avatar: u.avatar},
                limit: 10
      Chat.Repo.all(user)
    else
      {:error, :wrong_query}
    end
  end

  def find(_) do
    {:error, :wrong_parameter}
  end

  @doc """
  Function adds user's id to block_list.

    Parameters:<br/>
    `user_id` - id user who is blocking. Requires integer.<br />
    `blocked_user_id` - id of blocked user. Requires integer.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is user with updated block_list.<br />
    On fail:`false`.
  """

  def block_user(user_id, blocked_user_id) when is_integer(user_id) and is_integer(blocked_user_id) do
    user = Chat.Repo.get(User, user_id)
    if !is_blocked(user.blocked_users, blocked_user_id) && user_id != blocked_user_id do
      case user.blocked_users do
        nil ->
          Chat.Repo.update User.changeset(user, %{blocked_users: [blocked_user_id]})
        _->
          Chat.Repo.update User.changeset(user, %{blocked_users: [blocked_user_id | user.blocked_users]})
      end
    else
      false
    end
  end

  def block_user(_,_) do
    {:error, :wrong_parameter}
  end

  @doc """
  Function removes user's id from block_list.

    Parameters:<br/>
    `user_id` - id user who is unblocking. Requires integer.<br />
    `blocked_user_id` - id of unblocked user. Requires integer.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is user with updated block_list.<br />
    On fail: `false`.
  """

  def delete_blocked_user(user_id, blocked_user_id) when is_integer(user_id) and is_integer(blocked_user_id) do
    user = Chat.Repo.get(User, user_id)
    if(is_blocked(user.blocked_users, blocked_user_id)) do
      new_list = List.delete(user.blocked_users,blocked_user_id)
      Chat.Repo.update User.changeset(user, %{blocked_users: new_list})
    else
      false
    end
  end

  def delete_blocked_user(_,_) do
    {:error, :wrong_parameter}
  end

  @doc """
  Function checks if user is blocked.

    Parameters:<br/>
    `blocked_users` - List of blocked users.<br />
    `blocked_user_id` - id of blocked user. Requires integer.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is user with updated block_list.<br />
    On fail: `false`.
  """

  def is_blocked(blocked_users, blocked_user_id) do
    if blocked_users != nil do
      Enum.member?(blocked_users, blocked_user_id)
    else
      false
    end
  end

  @doc """
  Function changes user's info.

    Parameters:<br/>
    `u_id` - user's id. Requires integer.<br />
    `%{"id" => user_id, "username" => dis_name, "avatar_url" => avatar}` - id is user's id, username is user's nickname and avatar_url is URL of user's avatar.

    Returns Tuple:<br/>
    On success: `{:ok, u_info}`, where u_info is user with changes.<br />
    On fail: `{:error, reason}`, where reason is atom representing reason for failing.
  """

  def change_info(u_id, %{"id" => user_id, "username" => dis_name, "avatar_url" => avatar}) when is_integer(u_id) and is_integer(user_id) and is_binary(dis_name) and is_binary(avatar) do
    if u_id != user_id do
      {:error, :wrong_user_object}
    else
      user = Chat.Repo.get(User, user_id)
      if user do
        uinfo =  Chat.Repo.update User.changeset(user, %{display_name: dis_name, avatar: avatar})
        case uinfo do
          {:ok, u_info} -> {:ok, u_info}
          _ -> {:error, :wrong_data}
        end
      else
        {:error, :not_found}
      end
    end
  end

  def change_info(_, _) do
    {:error, :wrong_parameter}
  end


  @doc """
  Function adds friends into friendlist.

    Parameters:<br/>
    `user_id` - user's id. Requires integer.<br />
    `friends` - list of friends. Requires list.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is updated user.<br />
    On fail: `:error`
  """

  def add_friends(user_id, friends) when is_integer(user_id) and is_list(friends) do
    user = Chat.Repo.get(User, user_id)
    if user != nil do
      Chat.Repo.update User.changeset(user, %{friends: user.friends ++ friends})
    else
      :error
    end
  end

  @doc """
  Function delete friends from friendlist.

    Parameters:<br/>
    `user_id` - user's id. Requires integer.<br />
    `friend_id` - friend's list. Requires list.

    Returns Tuple:<br/>
    On success: `{:ok, user}`, where user is updated user.<br />
    On fail: `:error`
  """

  def del_friend(user_id, friend_id) when is_integer(user_id) and is_list(friend_id) do
    user = Chat.Repo.get(User, user_id)
    if user != nil do
      Chat.Repo.update User.changeset(user, %{friends: Enum.filter(user.friends, fn x -> x != friend_id end)})
    else
      :error
    end
  end

end