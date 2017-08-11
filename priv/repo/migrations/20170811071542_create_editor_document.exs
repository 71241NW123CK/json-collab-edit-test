defmodule JsonCollabEditTest.Repo.Migrations.CreateEditorDocument do
  use Ecto.Migration

  def change do
    create table(:editor_documents) do
      add :title, :string
      add :document, :text
      add :past_user_deltas, {:array, :map}, default: []
      add :future_user_deltas, {:array, :map}, default: []
      add :owner_id, references(:users, on_delete: :nothing)

      timestamps()
    end
    create index(:editor_documents, [:owner_id])

  end
end
