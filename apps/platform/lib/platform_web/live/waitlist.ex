defmodule Platform.Waitlist do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Repo

  schema "waitlist" do
    field :email, :string
    timestamps()
  end

  def changeset(waitlist, attrs) do
    waitlist
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> unique_constraint(:email, name: :waitlist_email_index)
  end

  def new(params) do
    changeset = %__MODULE__{} |> changeset(params)
    Repo.insert(changeset)
  end
end
