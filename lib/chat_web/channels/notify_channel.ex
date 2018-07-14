defmodule ChatWeb.NotifyChannel do
  use ChatWeb, :channel

  def join("notify:" <> user_id, _, socket) do
    case Integer.parse(user_id) do
      {user_id, ""} ->
        if socket.assigns.user_id == user_id do
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      _ -> {:error, %{reason: "wrong user id"}}
    end
  end

  def join(_, _, _) do
    {:error, %{reason: "not found"}}
  end

  def handle_in(_, _, socket) do
    {:reply, {:error, %{reason: "wrong endpoint"}}, socket}
  end
end
