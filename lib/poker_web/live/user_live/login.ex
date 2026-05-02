defmodule PokerWeb.UserLive.Login do
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

        <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2">
          <%= if @current_scope, do: "REAUTHENTICATE", else: "WELCOME BACK" %>
        </div>
        <h2 class="font-[family-name:var(--pkr-font-display)] text-[36px] leading-none text-[var(--pkr-ink-1)] mb-6">
          Take your seat.
        </h2>

        <!-- Dev mail info -->
        <div :if={local_mail_adapter?()} class="mb-5 px-3.5 py-3 rounded-lg border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)] text-xs text-[var(--pkr-ink-3)]">
          View sent emails in <.link href="/dev/mailbox" class="text-[var(--pkr-accent)] underline">the mailbox</.link>
        </div>

        <!-- Magic link form -->
        <.form
          for={@form}
          id="login_form_magic"
          action={~p"/users/log-in"}
          phx-submit="submit_magic"
          class="space-y-3"
        >
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">EMAIL</label>
            <.input
              field={@form[:email]}
              type="email"
              autocomplete="username"
              required
              readonly={!!@current_scope}
              phx-mounted={JS.focus()}
              placeholder="you@example.com"
              class="w-full px-3.5 py-3 rounded-lg text-sm bg-[var(--pkr-bg-1)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] transition-colors"
            />
          </div>
          <button type="submit" class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer">
            Send Magic Link
          </button>
        </.form>

        <!-- Divider -->
        <div class="flex items-center gap-2.5 my-5">
          <div class="flex-1 h-px bg-[var(--pkr-line)]"></div>
          <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">OR</span>
          <div class="flex-1 h-px bg-[var(--pkr-line)]"></div>
        </div>

        <!-- Password form -->
        <.form
          for={@form}
          id="login_form_password"
          action={~p"/users/log-in"}
          phx-submit="submit_password"
          phx-trigger-action={@trigger_submit}
          class="space-y-3"
        >
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">EMAIL</label>
            <.input
              field={@form[:email]}
              type="email"
              autocomplete="username"
              required
              readonly={!!@current_scope}
              placeholder="you@example.com"
              class="w-full px-3.5 py-3 rounded-lg text-sm bg-[var(--pkr-bg-1)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] transition-colors"
            />
          </div>
          <div>
            <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">PASSWORD</label>
            <.input
              field={@form[:password]}
              type="password"
              autocomplete="current-password"
              placeholder="••••••••"
              class="w-full px-3.5 py-3 rounded-lg text-sm bg-[var(--pkr-bg-1)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] transition-colors"
            />
          </div>
          <button type="submit" name={@form[:remember_me].name} value="true" class="w-full py-3.5 rounded-xl text-[13px] font-medium border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] hover:bg-[var(--pkr-bg-2)] transition-all cursor-pointer">
            Log in with Password
          </button>
        </.form>

        <!-- Register link -->
        <%= if !@current_scope do %>
          <div class="text-xs text-[var(--pkr-ink-3)] text-center mt-8">
            New here?
            <.link navigate={~p"/users/register"} class="text-[var(--pkr-accent)] hover:underline">
              Create an account
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:poker, Poker.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
