defmodule Platform.Repo.Migrations.CreateRequests do
  use Ecto.Migration

  def change do
    create table(:requests, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false
      add :type, :string
      add :params, :map
      add :status, :string
      add :response, :text
      add :tokens, :integer
      add :reward, :integer
      add :time_start, :utc_datetime
      add :time_end, :utc_datetime
      add :requester_id, references(:users, on_delete: :nothing)
      add :worker_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:requests, [:requester_id])
    create index(:requests, [:worker_id])
  end
end
