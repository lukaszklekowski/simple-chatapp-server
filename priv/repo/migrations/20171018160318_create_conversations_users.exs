defmodule Chat.Repo.Migrations.CreateConversationsUsers do
  use Ecto.Migration

  def change do
    create table(:conversations_users) do
      add :user_id, references(:users)
      add :conversation_id, references(:conversations)
    end
  end
end
