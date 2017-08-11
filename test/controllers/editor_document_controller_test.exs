defmodule JsonCollabEditTest.EditorDocumentControllerTest do
  use JsonCollabEditTest.ConnCase

  alias JsonCollabEditTest.EditorDocument
  @valid_attrs %{document: "some content", title: "some content"}
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, editor_document_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing editor documents"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, editor_document_path(conn, :new)
    assert html_response(conn, 200) =~ "New editor document"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, editor_document_path(conn, :create), editor_document: @valid_attrs
    assert redirected_to(conn) == editor_document_path(conn, :index)
    assert Repo.get_by(EditorDocument, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, editor_document_path(conn, :create), editor_document: @invalid_attrs
    assert html_response(conn, 200) =~ "New editor document"
  end

  test "shows chosen resource", %{conn: conn} do
    editor_document = Repo.insert! %EditorDocument{}
    conn = get conn, editor_document_path(conn, :show, editor_document)
    assert html_response(conn, 200) =~ "Show editor document"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, editor_document_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    editor_document = Repo.insert! %EditorDocument{}
    conn = get conn, editor_document_path(conn, :edit, editor_document)
    assert html_response(conn, 200) =~ "Edit editor document"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    editor_document = Repo.insert! %EditorDocument{}
    conn = put conn, editor_document_path(conn, :update, editor_document), editor_document: @valid_attrs
    assert redirected_to(conn) == editor_document_path(conn, :show, editor_document)
    assert Repo.get_by(EditorDocument, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    editor_document = Repo.insert! %EditorDocument{}
    conn = put conn, editor_document_path(conn, :update, editor_document), editor_document: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit editor document"
  end

  test "deletes chosen resource", %{conn: conn} do
    editor_document = Repo.insert! %EditorDocument{}
    conn = delete conn, editor_document_path(conn, :delete, editor_document)
    assert redirected_to(conn) == editor_document_path(conn, :index)
    refute Repo.get(EditorDocument, editor_document.id)
  end
end
