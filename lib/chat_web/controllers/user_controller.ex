defmodule ChatWeb.UserController do
  use ChatWeb, :controller
  alias Chat.Models.User, as: User
  alias Chat.Modules.Google, as: Google

  def login_google(conn, _) do
    {status, data} = case get_req_header(conn, "authorization") do
      [t] ->
        case Google.verify(t) do
          {:ok, fields} ->
            User.get_or_create(
              fields["email"],
              fields["name"],
              fields["picture"],
              Enum.join(Tuple.to_list(conn.remote_ip), ".")
            )
          _ -> {:error, :wrong_token}
        end
      _ -> {:error, :not_found}
    end

    case status do
      :ok ->
        case User.get_tokens(data) do
          {:ok, response} -> render(conn, "login.json", response)
          _ -> render(conn, "error.json", %{code: 500, message: "Internal server error."})
        end
      :error ->
        case data do
          :wrong_token -> render(conn, "error.json", %{code: 401, message: "Wrong Google Token."})
          :not_found -> render(conn, "error.json", %{code: 400, message: "Token is required!"})
          _ -> render(conn, "error.json", %{code: 500, message: "Internal server error."})
        end
      _ -> render(conn, "error.json", %{code: 500, message: "Internal server error."})
    end
  end

  def refresh_access_token(conn, _) do
    case get_req_header(conn, "authorization") do
      [token] ->
        case User.verify_refresh_token(token) do
          {:ok, user} ->
            if (NaiveDateTime.diff(NaiveDateTime.add(user.token_issued_at, 259200, :second), NaiveDateTime.utc_now) <= 0) do
              case User.gen_access_token(user) do
                {:ok, u} ->
                  case User.get_access_token(u) do
                    {:ok, access_token} -> render(conn, "token.json", %{token: access_token})
                    _ -> render(conn, "error.json", %{code: 500, message: "Internal server error"})
                  end
                _ -> render(conn, "error.json", %{code: 500, message: "Internal server error"})

              end
            else
              case User.get_access_token(user) do
                {:ok, access_token} -> render(conn, "token.json", %{token: access_token})
                _ -> render(conn, "error.json", %{code: 500, message: "Internal server error"})
              end
            end
          _ -> render(conn, "error.json", %{code: 401, message: "Wrong token"})
        end
      _ -> render(conn, "error.json", %{code: 404, message: "Token not found"})
    end
  end
end
