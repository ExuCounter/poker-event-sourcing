defmodule PokerWeb.UserLive.Confirmation do
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
          <%= if @user.confirmed_at, do: "WELCOME BACK", else: "WELCOME" %>
        </div>
        <h2 class="font-[family-name:var(--pkr-font-display)] text-[36px] leading-none text-[var(--pkr-ink-1)] mb-2">
          <%= if @user.confirmed_at, do: "Take your seat.", else: "You're in." %>
        </h2>
        <p class="text-[var(--pkr-ink-3)] text-[13px] mb-8">{@user.email}</p>

        <!-- Unconfirmed User Form -->
        <.form
          :if={!@user.confirmed_at}
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={~p"/users/log-in?_action=confirmed"}
          phx-trigger-action={@trigger_submit}
          class="space-y-3"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />

          <button
            type="submit"
            name={@form[:remember_me].name}
            value="true"
            phx-disable-with="Confirming..."
            class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
          >
            Confirm &amp; Stay Logged In
          </button>

          <button
            type="submit"
            phx-disable-with="Confirming..."
            class="w-full py-3 rounded-xl text-[13px] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] hover:bg-[var(--pkr-bg-2)] transition-all cursor-pointer"
          >
            Confirm &amp; Log In Only This Time
          </button>
        </.form>

        <!-- Confirmed User Form -->
        <.form
          :if={@user.confirmed_at}
          for={@form}
          id="login_form"
          phx-submit="submit"
          phx-mounted={JS.focus_first()}
          action={~p"/users/log-in"}
          phx-trigger-action={@trigger_submit}
          class="space-y-3"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />

          <%= if @current_scope do %>
            <button
              type="submit"
              phx-disable-with="Logging in..."
              class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
            >
              Log In
            </button>
          <% else %>
            <button
              type="submit"
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Logging in..."
              class="w-full py-3.5 rounded-xl text-sm font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
            >
              Keep Me Logged In
            </button>

            <button
              type="submit"
              phx-disable-with="Logging in..."
              class="w-full py-3 rounded-xl text-[13px] border border-[var(--pkr-line)] text-[var(--pkr-ink-2)] hover:bg-[var(--pkr-bg-2)] transition-all cursor-pointer"
            >
              Log In Only This Time
            </button>
          <% end %>
        </.form>

        <!-- Tip for unconfirmed users -->
        <div :if={!@user.confirmed_at} class="mt-6 px-3.5 py-3 rounded-lg border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)]">
          <p class="text-xs text-[var(--pkr-ink-3)] leading-relaxed">
            If you prefer passwords, you can enable them in your account settings after logging in.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
