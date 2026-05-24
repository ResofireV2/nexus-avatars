defmodule NexusAvatars do
  @moduledoc """
  Nexus Avatars — automatically generates unique avatars for every user.

  Six distinct styles: Mech, Feline, Canine, Inkblot, Emblem, Snowflake.
  Avatars are generated as 256x256 WebP images via SVG + libvips.
  All generated files are prefixed with `nxa_` for clean flush support.

  Identity, settings schema, and all declared surfaces live in manifest.json.
  This module implements only the server-side callbacks.
  """

  use Nexus.Extensions.Behaviour

  require Logger

  @impl true
  def migrations do
    [
      NexusAvatars.Migrations.V20260515000001CreateUserStyles,
    ]
  end

  @impl true
  def routes do
    [{"/", NexusAvatars.ApiRouter, []}]
  end

  # ---------------------------------------------------------------------------
  # Hook: generate avatar immediately on registration
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("user_registered", %{"user_id" => user_id}, settings) do
    Task.start(fn ->
      case Nexus.Accounts.get_user(user_id) do
        nil ->
          Logger.warning("NexusAvatars: user_registered fired for unknown user #{user_id}")

        user ->
          style = NexusAvatars.Generator.pick_style(user.username, settings)

          case NexusAvatars.Generator.generate_for_user(user, style) do
            {:ok, _url} ->
              Logger.info("NexusAvatars: generated #{style} avatar for #{user.username}")

            {:error, reason} ->
              Logger.error("NexusAvatars: failed to generate avatar for #{user.username}: #{inspect(reason)}")
          end
      end
    end)
    :ok
  end

  def handle_event(_event, _payload, _settings), do: :ok

  # ---------------------------------------------------------------------------
  # on_uninstall: clean up all generated files
  # ---------------------------------------------------------------------------

  @impl true
  def on_uninstall do
    NexusAvatars.Generator.flush_all()
    :ok
  end
end
