defmodule JsonCollabEditTest.EditorDocumentTest do
  use JsonCollabEditTest.ModelCase

  alias JsonCollabEditTest.EditorDocument

  @valid_attrs %{document: "some content", title: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = EditorDocument.changeset(%EditorDocument{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = EditorDocument.changeset(%EditorDocument{}, @invalid_attrs)
    refute changeset.valid?
  end
end
