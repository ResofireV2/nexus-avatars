defmodule NexusAvatars.Jobs.BulkGenerate do
  @moduledoc """
  Oban worker that generates avatars for all users who currently have no
  avatar_url set. Runs in batches of 50 to avoid blocking the media queue.

  Enqueued by the admin panel "Generate" button. Reports progress via a
  simple counter stored in the extension settings so the JS panel can poll.
  """

  use Oban.Worker, queue: :media, max_attempts: 3

  require Logger

  import Ecto.Query

  alias Nexus.Repo
  alias Nexus.Accounts.User
  alias NexusAvatars.Generator

  @batch_size 50

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    settings = NexusAvatars.load_settings()

    users =
      from(u in User,
        where: is_nil(u.avatar_url),
        select: %{id: u.id, username: u.username},
        order_by: [asc: u.id]
      )
      |> Repo.all()

    total     = length(users)
    succeeded = ref_counter()
    failed    = ref_counter()

    Logger.info("NexusAvatars.BulkGenerate: generating avatars for #{total} users")

    users
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      Enum.each(batch, fn %{id: id, username: username} ->
        style = Generator.pick_style(username, settings)

        if is_nil(style) do
          # No enabled styles — skip
          :ok
        else
          case Repo.get(User, id) do
            nil ->
              :ok

            user ->
              case Generator.generate_for_user(user, style) do
                {:ok, _url} ->
                  increment(succeeded)

                {:error, reason} ->
                  increment(failed)
                  Logger.warning("NexusAvatars.BulkGenerate: failed for #{username}: #{inspect(reason)}")
              end
          end
        end
      end)
    end)

    s = get_count(succeeded)
    f = get_count(failed)
    Logger.info("NexusAvatars.BulkGenerate: complete — #{s} succeeded, #{f} failed")

    :ok
  end

  # ---------------------------------------------------------------------------
  # Enqueue helper — called from the admin controller
  # ---------------------------------------------------------------------------

  def enqueue do
    %{}
    |> NexusAvatars.Jobs.BulkGenerate.new()
    |> Oban.insert()
  end

  # ---------------------------------------------------------------------------
  # Simple process-local counter via Agent
  # ---------------------------------------------------------------------------

  defp ref_counter do
    {:ok, pid} = Agent.start_link(fn -> 0 end)
    pid
  end

  defp increment(pid), do: Agent.update(pid, &(&1 + 1))
  defp get_count(pid),  do: Agent.get(pid, & &1)
end
