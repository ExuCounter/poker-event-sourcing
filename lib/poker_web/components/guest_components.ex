defmodule PokerWeb.GuestComponents do
  @moduledoc """
  UI building blocks for the guest-account flow: the "Play now as a guest"
  CTA shown on auth pages, the guest badge shown next to a guest's nickname,
  and the topbar conversion prompt for already-logged-in guests.
  """

  use Phoenix.Component
  use PokerWeb, :verified_routes

  alias Poker.Accounts
  alias Poker.Accounts.Schemas.User

  @doc """
  Primary "Play now as a guest" call-to-action — a CSRF-protected POST form
  to `/guests/sign-in`, a short caption, and a labelled divider below.
  """
  attr :class, :string, default: ""
  attr :divider_label, :string, default: "OR SIGN IN"

  def play_now_button(assigns) do
    ~H"""
    <div class={@class}>
      <.form for={%{}} action={~p"/guests/sign-in"} method="post" class="mb-3">
        <button
          type="submit"
          class="w-full py-4 rounded-xl text-[15px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
        >
          Play now as a guest
        </button>
      </.form>
      <p class="text-[11px] text-[var(--pkr-ink-3)] text-center leading-relaxed mb-6">
        No account, no email. Guest sessions last 3 days.
      </p>
      <div class="flex items-center gap-2.5 mb-5">
        <div class="flex-1 h-px bg-[var(--pkr-line)]"></div>
        <span class="font-[family-name:var(--pkr-font-mono)] text-[11px] text-[var(--pkr-ink-3)]">
          {@divider_label}
        </span>
        <div class="flex-1 h-px bg-[var(--pkr-line)]"></div>
      </div>
    </div>
    """
  end

  @doc """
  Small "GUEST" pill rendered next to a guest user's nickname so other
  players know they're playing against an unregistered account.
  """
  attr :class, :string, default: ""

  def guest_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-1.5 py-0.5 rounded font-[family-name:var(--pkr-font-mono)] text-[9px] uppercase tracking-[0.1em] border border-[var(--pkr-line)] text-[var(--pkr-ink-3)] bg-[var(--pkr-bg-2)]",
      @class
    ]}>
      Guest
    </span>
    """
  end

  @doc """
  Compact prompt shown in the topbar for logged-in guest users, linking to
  the upgrade page so they don't lose their wallet/history when their
  session expires.
  """
  attr :user, User, required: true
  attr :class, :string, default: ""

  def save_account_button(assigns) do
    ~H"""
    <.link
      :if={Accounts.guest?(@user)}
      navigate={~p"/guests/save-account"}
      class={[
        "px-3 py-1.5 rounded-md text-xs font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all",
        @class
      ]}
    >
      Save my account
    </.link>
    """
  end

  @doc """
  Sticky banner shown to every logged-in guest, urging them to convert their
  account before they lose their wallet and history. Renders nothing for
  registered users.
  """
  attr :user, User, required: true

  def expiry_banner(assigns) do
    ~H"""
    <div
      :if={Accounts.guest?(@user)}
      class="px-5 py-2.5 flex items-center justify-between gap-4 bg-[var(--pkr-accent)]/15 border-b border-[var(--pkr-accent)]/40"
    >
      <span class="text-[12px] text-[var(--pkr-ink-1)]">
        You're playing as a guest. Save your account now or your wallet and hand history will be wiped after 3 days of inactivity.
      </span>
      <.save_account_button user={@user} class="whitespace-nowrap" />
    </div>
    """
  end
end
