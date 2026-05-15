defmodule NexusAvatars.Migrations.V20260515000001CreateUserStyles do
  use Ecto.Migration

  def change do
    create table(:nexus_avatars_user_styles) do
      add :user_id, :integer, null: false
      add :style,   :string,  null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:nexus_avatars_user_styles, [:user_id])
  end
end
