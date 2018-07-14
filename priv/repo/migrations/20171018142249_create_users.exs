defmodule Chat.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :mail, :string, size: 254, null: false
      add :display_name, :string, size: 255, null: false
      add :type, :string, size: 255, null: false, default: "google"
      add :password, :string, size: 128, null: true
      add :salt, :string, size: 16, null: true
      add :token, :string, size: 256, null: true
      add :token_salt, :string, size: 16, null: true
      add :token_issued_at, :naive_datetime
      add :refresh_token, :string, size: 256, null: true
      add :refresh_token_salt, :string, size: 16, null: true
      add :password_token, :string, null: true
      add :avatar, :string, size: 512, null: true
      add :friends, {:array, :integer}
      add :blocked_users, {:array, :integer}
      add :last_online, :naive_datetime
      add :ip, :string, null: false

      timestamps()
    end

    create unique_index(:users, [:mail])

  end
end
