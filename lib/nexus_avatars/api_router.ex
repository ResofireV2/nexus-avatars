defmodule NexusAvatars.ApiRouter do
  @moduledoc """
  Plug.Router handling all API routes for the Nexus Avatars extension.

  Mounted at "/" by routes/0, so full paths relative to the extension root are:
    GET  /preview              — SVG preview (public)
    POST /style                — save style choice (authenticated)
    POST /generate             — lazy generate for current user (authenticated)
    GET  /admin/stats          — avatar counts (admin)
    POST /admin/flush          — delete all nxa_ avatars (admin)
    POST /admin/bulk-generate  — enqueue bulk generation job (admin)
  """

  use Plug.Router

  import Plug.Conn

  plug :fetch_query_params
  plug :match
  plug :dispatch

  # ---------------------------------------------------------------------------
  # Public
  # ---------------------------------------------------------------------------

  get "/preview" do
    NexusAvatars.PreviewController.show(conn, conn.params)
  end

  # ---------------------------------------------------------------------------
  # Authenticated
  # ---------------------------------------------------------------------------

  post "/style" do
    case require_user(conn) do
      {:ok, conn} -> NexusAvatars.StyleController.save(conn, conn.params)
      {:error, conn} -> conn
    end
  end

  post "/generate" do
    case require_user(conn) do
      {:ok, conn} -> NexusAvatars.StyleController.generate_mine(conn, conn.params)
      {:error, conn} -> conn
    end
  end

  # ---------------------------------------------------------------------------
  # Admin
  # ---------------------------------------------------------------------------

  get "/admin/stats" do
    case require_admin(conn) do
      {:ok, conn} -> NexusAvatars.AdminController.stats(conn, conn.params)
      {:error, conn} -> conn
    end
  end

  post "/admin/flush" do
    case require_admin(conn) do
      {:ok, conn} -> NexusAvatars.AdminController.flush(conn, conn.params)
      {:error, conn} -> conn
    end
  end

  post "/admin/bulk-generate" do
    case require_admin(conn) do
      {:ok, conn} -> NexusAvatars.AdminController.bulk_generate(conn, conn.params)
      {:error, conn} -> conn
    end
  end

  match _ do
    send_resp(conn, 404, ~s({"error":"not found"}))
  end

  # ---------------------------------------------------------------------------
  # Auth helpers
  # ---------------------------------------------------------------------------

  defp require_user(conn) do
    if conn.assigns[:current_user] do
      {:ok, conn}
    else
      conn = conn |> put_resp_content_type("application/json") |> send_resp(401, ~s({"error":"Unauthorized"})) |> halt()
      {:error, conn}
    end
  end

  defp require_admin(conn) do
    case conn.assigns[:current_user] do
      %{role: "admin"} ->
        {:ok, conn}

      nil ->
        conn = conn |> put_resp_content_type("application/json") |> send_resp(401, ~s({"error":"Unauthorized"})) |> halt()
        {:error, conn}

      _ ->
        conn = conn |> put_resp_content_type("application/json") |> send_resp(403, ~s({"error":"Forbidden"})) |> halt()
        {:error, conn}
    end
  end
end
