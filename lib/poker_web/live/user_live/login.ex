defmodule PokerWeb.UserLive.Login do
  use PokerWeb, :live_view

  alias Poker.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800 py-12 px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-md w-full">
        <!-- Main Card -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-5 bg-gradient-to-r from-emerald-500 to-teal-500">
            <h1 class="text-2xl font-bold text-white text-center">
              <%= if @current_scope do %>
                Reauthentication Required
              <% else %>
                Welcome Back
              <% end %>
            </h1>
            <p class="text-emerald-50 text-center text-sm mt-1">
              <%= if @current_scope do %>
                Please verify your identity to continue
              <% else %>
                Log in to your poker account
              <% end %>
            </p>
          </div>

          <div class="p-6 space-y-6">
            <!-- Info Alert -->
            <div :if={local_mail_adapter?()} class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
              <div class="flex gap-3">
                <svg class="w-5 h-5 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div class="text-sm text-blue-800 dark:text-blue-300">
                  <p class="font-medium">Local Mail Adapter Active</p>
                  <p class="mt-1">
                    View sent emails in <.link href="/dev/mailbox" class="underline hover:text-blue-900 dark:hover:text-blue-200">the mailbox</.link>
                  </p>
                </div>
              </div>
            </div>

            <!-- Magic Link Login -->
            <div>
              <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                <svg class="w-5 h-5 text-emerald-600 dark:text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                Log in with Magic Link
              </h2>

              <.form
                :let={f}
                for={@form}
                id="login_form_magic"
                action={~p"/users/log-in"}
                phx-submit="submit_magic"
                class="space-y-4"
              >
                <div>
                  <.input
                    readonly={!!@current_scope}
                    field={f[:email]}
                    type="email"
                    label="Email"
                    autocomplete="username"
                    required
                    phx-mounted={JS.focus()}
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <.button class="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 px-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 flex items-center justify-center gap-2">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                  Send Magic Link
                </.button>
              </.form>
            </div>

            <!-- Divider -->
            <div class="relative">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-slate-300 dark:border-slate-600"></div>
              </div>
              <div class="relative flex justify-center text-sm">
                <span class="px-4 bg-white dark:bg-slate-800 text-slate-500 dark:text-slate-400 font-medium">
                  or continue with password
                </span>
              </div>
            </div>

            <!-- Password Login -->
            <div>
              <h2 class="text-lg font-semibold text-slate-900 dark:text-white mb-4 flex items-center gap-2">
                <svg class="w-5 h-5 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
                Log in with Password
              </h2>

              <.form
                :let={f}
                for={@form}
                id="login_form_password"
                action={~p"/users/log-in"}
                phx-submit="submit_password"
                phx-trigger-action={@trigger_submit}
                class="space-y-4"
              >
                <div>
                  <.input
                    readonly={!!@current_scope}
                    field={f[:email]}
                    type="email"
                    label="Email"
                    autocomplete="username"
                    required
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <div>
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="Password"
                    autocomplete="current-password"
                    class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                  />
                </div>

                <div class="space-y-3">
                  <.button class="w-full bg-gradient-to-r from-blue-500 to-indigo-500 hover:from-blue-600 hover:to-indigo-600 text-white font-semibold py-3 px-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 flex items-center justify-center gap-2" name={@form[:remember_me].name} value="true">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    </svg>
                    Log in and Stay Logged In
                  </.button>

                  <.button class="w-full bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 font-medium py-2.5 px-4 rounded-lg border border-slate-300 dark:border-slate-600 transition-colors">
                    Log in Only This Time
                  </.button>
                </div>
              </.form>
            </div>
          </div>
        </div>

        <!-- Sign up Link -->
        <%= if !@current_scope do %>
          <p class="mt-6 text-center text-sm text-slate-600 dark:text-slate-400">
            Don't have an account?
            <.link
              navigate={~p"/users/register"}
              class="font-semibold text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-300 transition-colors"
            >
              Create one now
            </.link>
          </p>
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
