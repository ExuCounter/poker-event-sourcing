defmodule PokerWeb.UserLive.Registration do
  use PokerWeb, :live_view

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.User

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
            A poker room <em class="text-[var(--pkr-accent)]">built for the hand,</em> not the hype.
          </h1>
          <p class="text-[var(--pkr-ink-2)] text-sm max-w-[420px] leading-relaxed">
            Honest tables, integrated stats. No flashy pop-ups, no juiced rake.
          </p>
        </div>
      </div>

      <!-- Right form -->
      <div class="w-full lg:w-[460px] border-l border-[var(--pkr-line)] flex flex-col justify-center px-10 lg:px-14 py-16">
        <.flash kind={:error} flash={@flash} />
        <.flash kind={:info} flash={@flash} />

        <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2">CREATE ACCOUNT</div>
        <h2 class="font-[family-name:var(--pkr-font-display)] text-[36px] leading-none text-[var(--pkr-ink-1)] mb-6">
          Pull up a chair.
        </h2>

        <.play_now_button divider_label="OR SIGN UP" />

        <!-- Google register -->
        <.link
          href={~p"/auth/google/register"}
          class="w-full flex items-center justify-center gap-2.5 py-3.5 rounded-xl text-[13px] font-medium border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] hover:bg-[var(--pkr-bg-2)] transition-all cursor-pointer"
        >
          <svg viewBox="0 0 24 24" class="w-4 h-4" aria-hidden="true">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.76h3.56c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.56-2.76c-.99.66-2.25 1.05-3.72 1.05-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A11 11 0 0 0 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.1A6.6 6.6 0 0 1 5.5 12c0-.73.13-1.44.34-2.1V7.06H2.18A11 11 0 0 0 1 12c0 1.78.43 3.46 1.18 4.94l3.66-2.84z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84C6.71 7.31 9.14 5.38 12 5.38z"/>
          </svg>
          Sign up with Google
        </.link>

        <!-- Divider -->
        <div class="flex items-center gap-2.5 my-5">
          <div class="flex-1 h-px bg-[var(--pkr-line)]"></div>
          <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">OR</span>
          <div class="flex-1 h-px bg-[var(--pkr-line)]"></div>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate" class="space-y-3">
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">EMAIL</label>
            <.input
              field={@form[:email]}
              type="email"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
              placeholder="you@example.com"
              class="w-full px-3.5 py-3 rounded-lg text-sm bg-[var(--pkr-bg-1)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] transition-colors"
            />
          </div>

          <button type="submit" phx-disable-with="Creating account..." class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer mt-1">
            Create Account
          </button>
        </.form>

        <!-- Info -->
        <div class="mt-5 px-3.5 py-3 rounded-lg border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)]">
          <p class="text-xs text-[var(--pkr-ink-3)] leading-relaxed">
            We'll send you a magic link to log in. No password needed &mdash; you can set one up later in settings.
          </p>
        </div>

        <!-- Login link -->
        <div class="text-xs text-[var(--pkr-ink-3)] text-center mt-8">
          Have an account?
          <.link navigate={~p"/users/log-in"} class="text-[var(--pkr-accent)] hover:underline">
            Sign in
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: PokerWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
