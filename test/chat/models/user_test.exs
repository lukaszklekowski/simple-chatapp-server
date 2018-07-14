defmodule UserTest do
  use Chat.DataCase
  @moduledoc false

  test "create user" do
    {:ok, user} = Chat.Model.User.get_or_create("test@test.pl", "123", "123", "123")
    assert user.mail == "test@test.pl"
  end

  test "get existing user" do
    Chat.Repo.insert Chat.Model.User.changeset(%Chat.Model.User{}, %{mail: "abc@abc.pl", avatar: "test", display_name: "A", ip: "localhost"})
    {:ok, user} = Chat.Model.User.get_or_create("abc@abc.pl", nil, nil, nil)
    assert user.ip == "localhost"
  end

end
