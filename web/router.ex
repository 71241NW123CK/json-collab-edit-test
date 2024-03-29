defmodule JsonCollabEditTest.Router do
  use JsonCollabEditTest.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug JsonCollabEditTest.Auth, repo: JsonCollabEditTest.Repo
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", JsonCollabEditTest do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    resources "/users", UserController
    resources "/sessions", SessionController, only: [:new, :create, :delete]
    resources "/editor_documents", EditorDocumentController
  end

  # Other scopes may use custom stacks.
  # scope "/api", JsonCollabEditTest do
  #   pipe_through :api
  # end
end
