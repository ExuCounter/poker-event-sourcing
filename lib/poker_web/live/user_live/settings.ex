defmodule PokerWeb.UserLive.Settings do
  use PokerWeb, :live_view

  on_mount {PokerWeb.UserAuth, :require_sudo_mode}

  alias Poker.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col font-[family-name:var(--pkr-font-ui)]">
      <!-- Top bar -->
      <div class="h-14 flex items-center px-5 border-b border-[var(--pkr-line)]">
        <.link
          navigate={~p"/"}
          class="font-[family-name:var(--pkr-font-mono)] text-xs text-[var(--pkr-ink-3)] hover:text-[var(--pkr-ink-2)] transition-all mr-4"
        >
          &larr; Back
        </.link>
        <.link
          navigate={~p"/"}
          class="font-[family-name:var(--pkr-font-display)] text-[22px] italic flex items-baseline gap-1"
        >
          Poker
          <span class="text-[var(--pkr-ink-3)] text-[12px] not-italic font-[family-name:var(--pkr-font-mono)]">
            by Volodymyr Potiichuk
          </span>
        </.link>
        <div class="flex-1"></div>
      </div>

      <.flash kind={:error} flash={@flash} />
      <.flash kind={:info} flash={@flash} />

      <div class="flex-1 flex justify-center py-10 px-6">
        <div class="w-full max-w-lg space-y-8">
          <!-- Header -->
          <div>
            <div class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-1.5">
              ACCOUNT
            </div>
            <h1 class="font-[family-name:var(--pkr-font-display)] text-[36px] leading-none text-[var(--pkr-ink-1)]">
              Settings
            </h1>
            <p class="text-[var(--pkr-ink-3)] text-[13px] mt-1.5">Manage your email and password</p>
          </div>
          
    <!-- Nickname form -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
            <div class="px-5 py-3 border-b border-[var(--pkr-line)]">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                CHANGE NICKNAME
              </div>
            </div>
            <.form
              for={@nickname_form}
              id="nickname_form"
              phx-submit="update_nickname"
              phx-change="validate_nickname"
              class="p-5 space-y-4"
            >
              <div>
                <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">
                  NICKNAME
                </label>
                <input
                  type="text"
                  name={@nickname_form[:nickname].name}
                  id={@nickname_form[:nickname].id}
                  value={Phoenix.HTML.Form.normalize_value("text", @nickname_form[:nickname].value)}
                  required
                  class="w-full px-3 py-2 rounded-lg text-[14px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)] transition-colors"
                />
                <%= if @nickname_form[:nickname].errors != [] do %>
                  <p class="mt-1 text-xs text-[var(--pkr-danger)]">
                    {translate_error(hd(@nickname_form[:nickname].errors))}
                  </p>
                <% end %>
              </div>
              <button
                type="submit"
                phx-disable-with="Saving..."
                class="px-4 py-2.5 rounded-lg text-[13px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
              >
                Save Nickname
              </button>
            </.form>
          </div>
          
    <!-- Email form -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
            <div class="px-5 py-3 border-b border-[var(--pkr-line)]">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                CHANGE EMAIL
              </div>
            </div>
            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
              class="p-5 space-y-4"
            >
              <div>
                <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">
                  EMAIL
                </label>
                <input
                  type="email"
                  name={@email_form[:email].name}
                  id={@email_form[:email].id}
                  value={Phoenix.HTML.Form.normalize_value("email", @email_form[:email].value)}
                  autocomplete="username"
                  required
                  class="w-full px-3 py-2 rounded-lg text-[14px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)] transition-colors"
                />
                <%= if @email_form[:email].errors != [] do %>
                  <p class="mt-1 text-xs text-[var(--pkr-danger)]">
                    {translate_error(hd(@email_form[:email].errors))}
                  </p>
                <% end %>
              </div>
              <button
                type="submit"
                phx-disable-with="Changing..."
                class="px-4 py-2.5 rounded-lg text-[13px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
              >
                Change Email
              </button>
            </.form>
          </div>
          
    <!-- Password form -->
          <div class="rounded-xl border border-[var(--pkr-line)] bg-[var(--pkr-bg-1)] overflow-hidden">
            <div class="px-5 py-3 border-b border-[var(--pkr-line)]">
              <div class="font-[family-name:var(--pkr-font-mono)] text-[10px] uppercase tracking-[0.1em] text-[var(--pkr-ink-3)]">
                CHANGE PASSWORD
              </div>
            </div>
            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
              class="p-5 space-y-4"
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                autocomplete="username"
                value={@current_email}
              />
              <div>
                <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">
                  NEW PASSWORD
                </label>
                <input
                  type="password"
                  name={@password_form[:password].name}
                  id={@password_form[:password].id}
                  value={
                    Phoenix.HTML.Form.normalize_value("password", @password_form[:password].value)
                  }
                  autocomplete="new-password"
                  required
                  class="w-full px-3 py-2 rounded-lg text-[14px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)] transition-colors"
                />
                <%= if @password_form[:password].errors != [] do %>
                  <p class="mt-1 text-xs text-[var(--pkr-danger)]">
                    {translate_error(hd(@password_form[:password].errors))}
                  </p>
                <% end %>
              </div>
              <div>
                <label class="block text-[11px] text-[var(--pkr-ink-3)] font-[family-name:var(--pkr-font-mono)] mb-1.5 uppercase tracking-wide">
                  CONFIRM PASSWORD
                </label>
                <input
                  type="password"
                  name={@password_form[:password_confirmation].name}
                  id={@password_form[:password_confirmation].id}
                  value={
                    Phoenix.HTML.Form.normalize_value(
                      "password",
                      @password_form[:password_confirmation].value
                    )
                  }
                  autocomplete="new-password"
                  class="w-full px-3 py-2 rounded-lg text-[14px] bg-[var(--pkr-bg-2)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] font-[family-name:var(--pkr-font-mono)] transition-colors"
                />
                <%= if @password_form[:password_confirmation].errors != [] do %>
                  <p class="mt-1 text-xs text-[var(--pkr-danger)]">
                    {translate_error(hd(@password_form[:password_confirmation].errors))}
                  </p>
                <% end %>
              </div>
              <button
                type="submit"
                phx-disable-with="Saving..."
                class="px-4 py-2.5 rounded-lg text-[13px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
              >
                Save Password
              </button>
            </.form>
          </div>
          
    <!-- Log out -->
          <div class="pt-2">
            <.link
              href={~p"/users/log-out"}
              method="delete"
              class="inline-block px-4 py-2.5 rounded-lg text-[13px] text-[var(--pkr-danger)] border border-[var(--pkr-danger)]/40 hover:bg-[var(--pkr-danger)]/10 transition-all"
            >
              Log out
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)
    nickname_changeset = Accounts.change_user_nickname(user, %{}, validate_unique: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:nickname_form, to_form(nickname_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_nickname", %{"user" => user_params}, socket) do
    nickname_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_nickname(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, nickname_form: nickname_form)}
  end

  def handle_event("update_nickname", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_nickname(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:nickname_form, to_form(Accounts.change_user_nickname(updated_user)))
         |> put_flash(:info, "Nickname updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, nickname_form: to_form(changeset, action: :insert))}
    end
  end
end
