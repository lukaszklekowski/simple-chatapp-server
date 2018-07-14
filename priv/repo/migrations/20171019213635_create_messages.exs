defmodule Chat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :user_id, references(:users)
      add :conversation_id, references(:conversations)
      add :type, :string
      add :content, :text
      add :read_by, {:array, :integer}
      add :hidden_by, {:array, :integer}

      timestamps()
    end

  end
end
