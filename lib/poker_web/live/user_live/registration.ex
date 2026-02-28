defmodule PokerWeb.UserLive.Registration do
  use PokerWeb, :live_view

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.User

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-slate-50 to-slate-100 dark:from-slate-900 dark:to-slate-800 py-12 px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-md w-full">
        <!-- Main Card -->
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
          <!-- Header -->
          <div class="px-6 py-5 bg-gradient-to-r from-emerald-500 to-teal-500">
            <h1 class="text-2xl font-bold text-white text-center">Create Your Account</h1>
            <p class="text-emerald-50 text-center text-sm mt-1">
              Join the poker action today
            </p>
          </div>

          <div class="p-6">
            <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                  <div class="flex items-center gap-2">
                    <svg class="w-4 h-4 text-slate-500 dark:text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                    Email Address
                  </div>
                </label>
                <.input
                  field={@form[:email]}
                  type="email"
                  label=""
                  autocomplete="username"
                  required
                  phx-mounted={JS.focus()}
                  class="w-full input input-bordered bg-white dark:bg-slate-700 border-slate-300 dark:border-slate-600"
                />
              </div>

              <.button
                phx-disable-with="Creating account..."
                class="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 px-4 rounded-lg shadow-md hover:shadow-lg transition-all duration-200 flex items-center justify-center gap-2"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                </svg>
                Create Account
              </.button>
            </.form>

            <!-- Info Box -->
            <div class="mt-6 p-4 bg-slate-50 dark:bg-slate-750 rounded-lg border border-slate-200 dark:border-slate-600">
              <div class="flex gap-3">
                <svg class="w-5 h-5 text-emerald-600 dark:text-emerald-400 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div class="text-sm text-slate-600 dark:text-slate-400">
                  <p class="font-medium text-slate-900 dark:text-white">Email-based Authentication</p>
                  <p class="mt-1">We'll send you a magic link to log in. No password needed unless you set one up later.</p>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Login Link -->
        <p class="mt-6 text-center text-sm text-slate-600 dark:text-slate-400">
          Already have an account?
          <.link
            navigate={~p"/users/log-in"}
            class="font-semibold text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-300 transition-colors"
          >
            Log in here
          </.link>
        </p>
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
