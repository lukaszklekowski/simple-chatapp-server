defmodule Chat.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :name, :string, size: 256, null: true
      add :avatar, :string, size: 128, null: true
      add :message_count, :integer

      timestamps()
    end

  end
end
