defmodule Chat.Modules.Google do
  @moduledoc false

  def start_link() do
    Agent.start_link(fn -> [] end, name: :google_keys)
  end

  def get_kid(jwt) when is_binary(jwt) do
    try do
      case JOSE.JWT.peek_protected(jwt) do
        %JOSE.JWS{fields: %{"kid" => kid}} -> {:ok, kid}
        _ -> {:error, {:no_kid}}
      end
    rescue
      _ -> {:error, :invalid}
    end
  end

  def verify(jwt) when is_binary(jwt) do
    data = case get_kid(jwt) do
      {:ok, kid} -> JOSE.JWT.verify(find_secret(kid), jwt)
      _ -> {:error, :ivalid}
    end

    case data do
      {true, %JOSE.JWT{fields: fields}, _} ->
        cond do
          fields["exp"] == nil -> {:error, :invalid}
          System.system_time(:seconds) < fields["exp"] ->
            cond do
              fields["aud"] in Application.get_env(:chat, :google_client_id) ->
                cond do
                  fields["iss"] == "accounts.google.com" -> {:ok, fields}
                  fields["iss"] == "https://accounts.google.com" -> {:ok, fields}
                  true -> {:error, :invalid}
                end
              true -> {:error, :invalid}
            end
          true -> {:error, :expired}
        end
      _ -> {:error, :invalid}
    end
  end

  def update_keys() do
    update_keys(0)
  end

  def update_keys(i) when i <= 5 do
    case HTTPoison.get "https://www.googleapis.com/oauth2/v3/certs" do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Poison.decode(body) do
          {:ok, %{"keys" => keys}} -> Agent.get_and_update(:google_keys, fn _ -> {keys, keys} end)
          _ -> update_keys(i+1)
        end
      _ -> update_keys(i+1)
    end
  end

  def update_keys(i) when i > 5 do
    Agent.get(:google_keys, fn x -> x end)
  end

  def find_secret(kid) do
    keys = Agent.get(:google_keys, fn x -> x end)
    key = Enum.find(keys, fn x -> case x do
                                    %{"kid" => k} -> k == kid
                                    _ -> false
                                  end end)

    case key do
      %{"n" => _} -> key
      _ ->
        key = Enum.find(update_keys(), fn x -> case x do
                                        %{"kid" => k} -> k == kid
                                         _ -> false
                                       end end)
        case key do
          %{"n" => _} -> key
          _ -> %{}
        end
    end
  end

  def get(_) do
    nil
  end

end
