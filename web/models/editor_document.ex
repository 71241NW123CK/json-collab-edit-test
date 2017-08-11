defmodule JsonCollabEditTest.EditorDocument do
  use JsonCollabEditTest.Web, :model

  schema "editor_documents" do
    field :title, :string
    field :document, :string

    embeds_many :past_user_deltas, JsonCollabEditTest.UserJsonDelta, on_replace: :delete
    embeds_many :future_user_deltas, JsonCollabEditTest.UserJsonDelta, on_replace: :delete
    belongs_to :owner, JsonCollabEditTest.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :document, :owner_id])
    |> cast_embed(:past_user_deltas, with: &user_json_delta_changeset/2)
    |> cast_embed(:future_user_deltas, with: &user_json_delta_changeset/2)
    |> validate_required([:title, :document, :owner_id])
  end

  def user_json_delta_changeset(struct, params) do
    struct
    |> cast(params, [:patch, :inverse, :user_id])
  end
end
