defmodule NexusAvatars.Migrations.V1CreateUserStyles do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:nexus_avatars_user_styles) do
      add :user_id, :integer, null: false
      add :style,   :string,  null: false

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists unique_index(:nexus_avatars_user_styles, [:user_id])
  end
end
