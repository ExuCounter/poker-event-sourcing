defmodule PokerWeb.UserLive.Onboarding do
  use PokerWeb, :live_view

  alias Poker.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex font-[family-name:var(--pkr-font-ui)]">
      <!-- Left poster -->
      <div class="hidden lg:flex flex-1 relative overflow-hidden bg-[var(--pkr-bg-1)]">
        <div class="absolute inset-0 opacity-60" style="background: radial-gradient(ellipse at 30% 50%, var(--pkr-accent), transparent 65%)"></div>
        <div class="absolute top-8 left-8">
          <div class="font-[family-name:var(--pkr-font-display)] text-[22px] italic flex items-baseline gap-1">
            Poker <span class="text-[var(--pkr-ink-3)] text-[12px] not-italic font-[family-name:var(--pkr-font-mono)]">by Volodymyr Potiichuk</span>
          </div>
        </div>
        <div class="absolute left-14 bottom-14 right-14 flex flex-col gap-3.5">
          <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)]">EST. 2026</div>
          <h1 class="font-[family-name:var(--pkr-font-display)] text-[56px] leading-[0.96] max-w-[480px] text-[var(--pkr-ink-1)]">
            Pick your name. <em class="text-[var(--pkr-accent)]">Take the felt.</em>
          </h1>
          <p class="text-[var(--pkr-ink-2)] text-sm max-w-[420px] leading-relaxed">
            This is how the table will see you. You can change it later in settings.
          </p>
        </div>
      </div>

      <!-- Right form -->
      <div class="w-full lg:w-[460px] border-l border-[var(--pkr-line)] flex flex-col justify-center px-10 lg:px-14 py-16">
        <.flash kind={:error} flash={@flash} />
        <.flash kind={:info} flash={@flash} />

        <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2">ONE LAST THING</div>
        <h2 class="font-[family-name:var(--pkr-font-display)] text-[36px] leading-none text-[var(--pkr-ink-1)] mb-6">
          Choose a nickname.
        </h2>

        <.form for={@form} id="onboarding_form" phx-submit="save" phx-change="validate" class="space-y-3">
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">NICKNAME</label>
            <.input
              field={@form[:nickname]}
              type="text"
              required
              phx-mounted={JS.focus()}
              placeholder="3-16 chars, letters, numbers, underscores"
              class="w-full px-3.5 py-3 rounded-lg text-sm bg-[var(--pkr-bg-1)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] transition-colors"
            />
          </div>
          <button type="submit" phx-disable-with="Saving..." class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer mt-1">
            Continue
          </button>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: %{onboarded_at: stamp}}}} = socket)
      when not is_nil(stamp) do
    {:ok, redirect(socket, to: ~p"/")}
  end

  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user
    changeset = Accounts.change_user_onboarding(user, %{"nickname" => user.nickname})
    return_to = Map.get(session, "user_return_to")

    {:ok, socket |> assign(:return_to, return_to) |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    user = socket.assigns.current_scope.user

    changeset =
      user
      |> Accounts.change_user_onboarding(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.complete_onboarding(user, params) do
      {:ok, _user} ->
        {:noreply, redirect(socket, to: socket.assigns[:return_to] || ~p"/")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end
end
