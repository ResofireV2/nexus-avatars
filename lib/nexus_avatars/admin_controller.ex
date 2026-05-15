defmodule NexusAvatars.AdminController do
  @moduledoc """
  Admin-only endpoints for the Nexus Avatars management panel.

  GET  /admin/stats          — counts for the admin panel display
  POST /admin/flush          — delete all nxa_ avatars and clear user records
  POST /admin/bulk-generate  — enqueue Oban job to generate for all users without avatars
  """

  use Phoenix.Controller, formats: [:json]
  import Plug.Conn

  alias NexusAvatars.Generator

  # ---------------------------------------------------------------------------
  # GET /admin/stats
  # ---------------------------------------------------------------------------

  def stats(conn, _params) do
    conn |> json(%{
      data: %{
        users_without_avatar:  Generator.count_users_without_avatar(),
        generated_avatars:     Generator.count_generated_avatars(),
      }
    })
  end

  # ---------------------------------------------------------------------------
  # POST /admin/flush
  # Deletes all nxa_ files and clears avatar_url where LIKE 'nxa_%'
  # ---------------------------------------------------------------------------

  def flush(conn, _params) do
    result = Generator.flush_all()

    conn |> json(%{
      data: %{
        users_cleared:  result.users_cleared,
        files_deleted:  result.files_deleted,
      }
    })
  end

  # ---------------------------------------------------------------------------
  # POST /admin/bulk-generate
  # Enqueues a background job; returns immediately
  # ---------------------------------------------------------------------------

  def bulk_generate(conn, _params) do
    pending = Generator.count_users_without_avatar()

    if pending == 0 do
      conn |> json(%{data: %{queued: false, message: "All users already have avatars."}})
    else
      case NexusAvatars.Jobs.BulkGenerate.enqueue() do
        {:ok, _job} ->
          conn |> json(%{
            data: %{
              queued:  true,
              pending: pending,
              message: "Job queued. Generating avatars for #{pending} users in the background."
            }
          })

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{error: "Failed to enqueue job: #{inspect(reason)}"})
      end
    end
  end
end
