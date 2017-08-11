defmodule JsonCollabEditTest.UserJsonDelta do
  use Ecto.Schema

  embedded_schema do
    field :patch, :string
    field :inverse, :string
    belongs_to :user, JsonCollabEditTest.User
  end
end
