defmodule NexusAvatars.ApiRouter do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_query_params
  end

  pipeline :auth do
    plug :require_user
  end

  pipeline :admin do
    plug :require_user
    plug :require_admin
  end

  # Public — preview endpoint (used by the style picker widget)
  scope "/" do
    pipe_through :api
    get "/preview", NexusAvatars.PreviewController, :show
  end

  # Authenticated — save style choice for current user
  scope "/" do
    pipe_through [:api, :auth]
    post "/style",    NexusAvatars.StyleController,   :save
    post "/generate", NexusAvatars.StyleController,   :generate_mine
  end

  # Admin only
  scope "/admin" do
    pipe_through [:api, :admin]
    get  "/stats",          NexusAvatars.AdminController, :stats
    post "/flush",          NexusAvatars.AdminController, :flush
    post "/bulk-generate",  NexusAvatars.AdminController, :bulk_generate
  end

  # ---------------------------------------------------------------------------
  # Auth plugs
  # ---------------------------------------------------------------------------

  defp require_user(conn, _) do
    if conn.assigns[:current_user] do
      conn
    else
      conn |> put_status(401) |> json(%{error: "Unauthorized"}) |> halt()
    end
  end

  defp require_admin(conn, _) do
    case conn.assigns[:current_user] do
      %{role: "admin"} -> conn
      nil -> conn |> put_status(401) |> json(%{error: "Unauthorized"}) |> halt()
      _   -> conn |> put_status(403) |> json(%{error: "Forbidden"})    |> halt()
    end
  end
end
