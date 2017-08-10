defmodule JsonCollabEditTest.PageController do
  use JsonCollabEditTest.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
