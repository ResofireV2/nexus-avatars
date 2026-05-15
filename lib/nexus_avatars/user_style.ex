defmodule NexusAvatars.UserStyle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nexus_avatars_user_styles" do
    # Plain integer — no belongs_to Nexus.Accounts.User (compile-time introspection
    # would fail since Nexus schemas are not available during extension compilation).
    field :user_id, :integer
    field :style,   :string

    timestamps(type: :utc_datetime)
  end

  @valid_styles ~w(mech feline canine inkblot emblem snowflake)

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:user_id, :style])
    |> validate_required([:user_id, :style])
    |> validate_inclusion(:style, @valid_styles)
    |> unique_constraint(:user_id)
  end

  def valid_styles, do: @valid_styles
end
