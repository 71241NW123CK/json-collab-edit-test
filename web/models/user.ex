defmodule JsonCollabEditTest.User do
  use JsonCollabEditTest.Web, :model

  schema "users" do
    field :username, :string
    field :name, :string
    field :email, :string
    field :profile_image_url, :string
    field :password_hash, :string
    field :password, :string, virtual: true

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:username, :name, :email, :profile_image_url])
    |> validate_required([:username, :name, :email, :profile_image_url])
    |> validate_length(:username, min: 1, max: 64)
  end

  def registration_changeset(struct, params) do
    struct
    |> changeset(params)
    |> cast(params, [:password], [])
    |> validate_length(:password, min: 6, max: 100)
    |> put_pass_hash()
  end

  defp put_pass_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Comeonin.Bcrypt.hashpwsalt(pass))
      _ ->
        changeset
    end
  end
end
