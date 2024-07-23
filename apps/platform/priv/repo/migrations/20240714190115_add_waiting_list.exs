defmodule Platform.Repo.Migrations.AddWaitingList do
  use Ecto.Migration

  def change do
    create table(:waitlist) do
      add :email, :string, null: false
      timestamps()
    end

    create unique_index(:waitlist, [:email])
  end
end
