defmodule PlatformWeb.LandingLive do
  use PlatformWeb, :live_view
  alias Platform.Waitlist
  import PlatformWeb.Components.{Hero, GradientBlob}

  def mount(_params, _session, socket) do
    form = Waitlist.changeset(%Waitlist{}, %{}) |> to_form()

    {:ok, assign(socket, form: form)}
  end

  def handle_event("register_interest", params, socket) do
    socket =
      case Waitlist.new(params) do
        {:ok, _} ->
          socket
          |> assign(form: Waitlist.changeset(%Waitlist{}, %{}) |> to_form())
          |> put_flash(:info, "Thank you for subscribing")

        {:error, changeset} ->
          assign(socket, form: changeset |> to_form())
      end

    {:noreply, socket}
  end
end
