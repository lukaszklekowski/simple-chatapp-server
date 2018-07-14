defmodule Chat.Modules.Token do
  @moduledoc false
  
  def peek(token) do
    try do
      {:ok, binary} = token
                      |> String.split(".")
                      |> Enum.at(1)
                      |> Base.url_decode64(padding: false)

      %{data: data} = :erlang.binary_to_term(binary)
      data
    rescue
      _ -> :error
    end
  end

  def sign(salt, data) do
    Phoenix.Token.sign(ChatWeb.Endpoint, salt, data)
  end

  def sign(salt, data, ops) do
    Phoenix.Token.sign(ChatWeb.Endpoint, salt, data, ops)
  end

  def verify(salt, token) do
    Phoenix.Token.verify(ChatWeb.Endpoint, salt, token)
  end

  def verify(salt, token, ops) do
    Phoenix.Token.verify(ChatWeb.Endpoint, salt, token, ops)
  end
end
