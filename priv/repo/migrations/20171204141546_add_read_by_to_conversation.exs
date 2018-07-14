defmodule Chat.Repo.Migrations.AddReadByToConversation do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :read_by, :map, null: false, default: %{}
    end
  end
end
