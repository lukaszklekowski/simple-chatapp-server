defmodule ChatWeb.ConversationChannelTest do
  use ChatWeb.ChannelCase

  alias ChatWeb.ConversationChannel

  setup do
    {:ok, _, socket} =
      socket("user_id", %{user_id: 1})
      |> subscribe_and_join(ConversationChannel, "conversation:lobby")

    {:ok, socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push socket, "ping", %{"hello" => "there"}
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to conversation:lobby", %{socket: socket} do
    push socket, "msg", %{"hello" => "all"}
    refute_broadcast "new_msg", %{author: %{id: _}, msg: %{"hello" => "all"}}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from! socket, "broadcast", %{"some" => "data"}
    assert_push "broadcast", %{"some" => "data"}
  end
end
