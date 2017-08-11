defmodule JsonCollabEditTest.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string
      add :name, :string
      add :email, :string
      add :profile_image_url, :text
      add :password_hash, :string

      timestamps()
    end

    create unique_index(:users, [:username])
  end
end
