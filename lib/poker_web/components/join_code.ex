defmodule PokerWeb.JoinCodeComponents do
  @moduledoc """
  Reusable "Join with code" form rendered in the dashboard sidebar and on
  the login page. Posts to `JoinController.create/2`, which auto-creates a
  guest session for unauthenticated visitors.
  """

  use Phoenix.Component
  use PokerWeb, :verified_routes

  attr :class, :string, default: ""
  attr :title, :string, default: "JOIN WITH CODE"

  def join_code_form(assigns) do
    ~H"""
    <.form for={%{}} action={~p"/join"} method="post" class={@class}>
      <div
        :if={@title != ""}
        class="font-[family-name:var(--pkr-font-mono)] text-[11px] uppercase tracking-[0.12em] text-[var(--pkr-ink-3)] mb-2"
      >
        {@title}
      </div>
      <div class="flex gap-2">
        <input
          name="code"
          type="text"
          required
          minlength="8"
          maxlength="8"
          autocomplete="off"
          spellcheck="false"
          placeholder="ABCDEFGH"
          style="text-transform: uppercase"
          class="flex-1 min-w-0 px-3 py-2 rounded-lg text-[13px] tracking-[0.15em] font-[family-name:var(--pkr-font-mono)] bg-[var(--pkr-bg-1)] border border-[var(--pkr-line)] text-[var(--pkr-ink-1)] outline-none focus:border-[var(--pkr-accent)] transition-colors"
        />
        <button
          type="submit"
          class="px-3 py-2 rounded-lg text-[13px] font-medium bg-[var(--pkr-accent)] text-[var(--pkr-bg-0)] hover:brightness-110 transition-all cursor-pointer"
        >
          Join
        </button>
      </div>
    </.form>
    """
  end

  @doc """
  Pill rendered on lobby pages showing the game's join code with a
  click-to-copy affordance. Inline JS keeps it usable without a hook.
  """
  attr :code, :string, required: true
  attr :class, :string, default: ""

  def share_code_chip(assigns) do
    ~H"""
    <button
      type="button"
      title="Copy code"
      onclick={"navigator.clipboard.writeText('#{@code}'); this.dataset.copied = '1'; setTimeout(() => delete this.dataset.copied, 1500)"}
      class={[
        "group inline-flex items-center gap-2 px-2.5 py-1 rounded-full text-xs border border-[var(--pkr-line)] bg-[var(--pkr-bg-2)] text-[var(--pkr-ink-2)] font-[family-name:var(--pkr-font-mono)] hover:bg-[var(--pkr-bg-1)] hover:border-[var(--pkr-accent)]/60 transition-all cursor-pointer",
        @class
      ]}
    >
      <span class="text-[var(--pkr-ink-3)] uppercase tracking-[0.12em] text-[9px]">CODE</span>
      <span class="text-[var(--pkr-ink-1)] tracking-[0.15em]">{@code}</span>
      <span class="text-[var(--pkr-ink-3)] group-hover:text-[var(--pkr-accent)]">⧉</span>
    </button>
    """
  end
end
