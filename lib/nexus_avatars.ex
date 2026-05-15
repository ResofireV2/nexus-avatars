defmodule NexusAvatars do
  @moduledoc """
  Nexus Avatars — automatically generates unique avatars for every user.

  Six distinct styles: Mech, Orc, Zombie, Inkblot, Emblem, Snowflake.
  Avatars are generated as 256x256 WebP images via SVG + libvips.
  All generated files are prefixed with `nxa_` for clean flush support.
  """

  use Nexus.Extensions.Behaviour

  require Logger

  @slug "nexus-avatars"

  @impl true
  def manifest do
    %{
      slug:        @slug,
      name:        "Nexus Avatars",
      version:     "1.2.0",
      description: "Automatically generates unique avatars for every user. Six distinct styles: Mech, Orc, Zombie, Inkblot, Emblem and Snowflake.",
      author:      "resofire",
      homepage:    "https://github.com/resofire/nexus-avatars",
      categories:  ["community", "utilities"],
    }
  end

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

  @impl true
  def js_bundle_path, do: "nexus-avatars.js"

  @impl true
  def settings_schema do
    %{
      "enabled_styles" => %{
        "type"    => "string",
        "label"   => "Enabled styles",
        "default" => "mech,feline,canine,inkblot,emblem,snowflake"
      },
      "random" => %{
        "type"    => "boolean",
        "label"   => "Random style assignment",
        "default" => true
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Hook: generate avatar immediately on registration
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("user_registered", %{"user_id" => user_id}, _settings) do
    Task.start(fn ->
      case Nexus.Accounts.get_user(user_id) do
        nil ->
          Logger.warning("NexusAvatars: user_registered fired for unknown user #{user_id}")

        user ->
          settings = load_settings()
          style    = NexusAvatars.Generator.pick_style(user.username, settings)

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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def load_settings do
    ext = Nexus.Extensions.get_extension_by_slug(@slug)
    if ext, do: ext.settings || %{}, else: %{}
  end
end
