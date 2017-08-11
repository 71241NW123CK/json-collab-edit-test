defmodule JsonCollabEditTest.EditorDocumentController do
  use JsonCollabEditTest.Web, :controller

  alias JsonCollabEditTest.EditorDocument
  alias JsonCollabEditTest.User
  require Logger

  def index(conn, _params) do
    editor_documents = Repo.all(EditorDocument)
    render(conn, "index.html", editor_documents: editor_documents)
  end

  def new(conn, _params) do
    changeset = EditorDocument.changeset(%EditorDocument{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"editor_document" => editor_document_params}) do
    changeset = EditorDocument.changeset(%EditorDocument{}, editor_document_params)
    changeset = Ecto.Changeset.put_embed(changeset, :past_user_deltas, [])
    changeset = Ecto.Changeset.put_embed(changeset, :future_user_deltas, [])
    case Repo.insert(changeset) do
      {:ok, _editor_document} ->
        conn
        |> put_flash(:info, "Editor document created successfully.")
        |> redirect(to: editor_document_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    editor_document = Repo.get!(EditorDocument, id)
    render(conn, "show.html", editor_document: editor_document)
  end

  def edit(conn, %{"id" => id}) do
    editor_document = Repo.get!(EditorDocument, id)
    changeset = EditorDocument.changeset(editor_document)
    render(conn, "edit.html", editor_document: editor_document, changeset: changeset)
  end

  def update(conn, %{"id" => id, "editor_document" => editor_document_params}) do
    editor_document = Repo.get!(EditorDocument, id)
    changeset = EditorDocument.changeset(editor_document, editor_document_params)

    case Repo.update(changeset) do
      {:ok, editor_document} ->
        conn
        |> put_flash(:info, "Editor document updated successfully.")
        |> redirect(to: editor_document_path(conn, :show, editor_document))
      {:error, changeset} ->
        render(conn, "edit.html", editor_document: editor_document, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    editor_document = Repo.get!(EditorDocument, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(editor_document)

    conn
    |> put_flash(:info, "Editor document deleted successfully.")
    |> redirect(to: editor_document_path(conn, :index))
  end

  plug :load_users when action in [:new, :edit, :create]

  def load_users(conn, _) do
    query =
      User
      |> User.alphabetical_by_username
      |> User.usernames_and_ids
    users = Repo.all query
    assign(conn, :users, users)
  end
end
