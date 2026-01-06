// LiveView Hooks for poker game animations

export const TableEvents = {
  mounted() {
    // Initialize event queue
    this.eventQueue = [];
    this.isProcessing = false;
    this.previousCardCount = 0;

    // Track initial card count
    const cardsContainer = document.querySelector(".community-cards-area");
    if (cardsContainer) {
      this.previousCardCount =
        cardsContainer.querySelectorAll(".community-card").length;
    }

    this.handleEvent("table_events", ({ events }) => {
      // Add new events to queue
      this.eventQueue.push(...events);
      // Start processing if not already processing
      if (!this.isProcessing) {
        this.processQueue();
      }
    });
  },

  updated() {
    // This runs after LiveView updates the DOM
    const cardsContainer = document.querySelector(".community-cards-area");
    if (!cardsContainer) return;

    const currentCards = cardsContainer.querySelectorAll(".community-card");
    const currentCardCount = currentCards.length;

    // Check if new cards were added
    if (currentCardCount > this.previousCardCount) {
      const newCardCount = currentCardCount - this.previousCardCount;

      // Animate only the newly added cards with stagger
      currentCards.forEach((card, index) => {
        if (index >= this.previousCardCount) {
          // This is a new card
          const delay = (index - this.previousCardCount) * 150;

          // Start invisible
          card.style.opacity = "0";
          card.style.transform = "translateY(-20px) scale(0.9)";

          setTimeout(() => {
            card.classList.add("card-slide-in");
            // Remove inline styles to let animation take over
            card.style.opacity = "";
            card.style.transform = "";

            setTimeout(() => {
              card.classList.remove("card-slide-in");
            }, 400);
          }, delay);
        }
      });
    }

    // Update the count for next comparison
    this.previousCardCount = currentCardCount;
  },

  async processQueue() {
    if (this.eventQueue.length === 0) {
      this.isProcessing = false;
      return;
    }

    this.isProcessing = true;
    const event = this.eventQueue.shift();

    // Animate event and wait for completion
    await this.animateEvent(event);

    // Process next event
    this.processQueue();
  },

  async animateEvent(event) {
    const { type, data, delay } = event;

    // Return a promise that resolves when animation completes
    return new Promise((resolve) => {
      // Use delay from server, default to 0 if not provided
      const duration = delay || 0;

      switch (type) {
        case "RoundStarted":
          this.animateRoundStart(data);
          break;
        case "HandStarted":
          this.animateHandStart(data);
          break;
        case "HandFinished":
          this.animateHandFinish(data);
          break;
        case "ParticipantShowdownCardsRevealed":
          this.animateCardReveal(data.participant_id);
          break;
        case "ParticipantFolded":
          this.animatePlayerAction(data.participant_id, "folded");
          break;
        case "ParticipantCalled":
          this.animatePlayerAction(data.participant_id, "called", data.amount);
          break;
        case "ParticipantChecked":
          console.log(data.participant_id);
          this.animatePlayerAction(data.participant_id, "checked");
          break;
        case "ParticipantRaised":
          this.animatePlayerAction(data.participant_id, "raised", data.amount);
          break;
        case "ParticipantWentAllIn":
          this.animatePlayerAction(data.participant_id, "all-in", data.amount);
          break;
        case "PotsRecalculated":
          this.animatePotUpdate(data);
          break;
        default:
          // Unknown event type, no animation
          break;
      }

      // Resolve after animation duration from server
      setTimeout(() => {
        this.pushEvent("event_processed", { event_id: data.event_id });
        console.log(event.type);
        console.log("animation");
        console.log(duration);
        resolve();
      }, duration);
    });
  },

  animateRoundComplete(data) {
    // Flash the community cards area
    const cards = document.querySelector(".community-cards-area");
    if (cards) {
      cards.classList.add("flash-animation");
      setTimeout(() => cards.classList.remove("flash-animation"), 500);
    }
  },

  animateRoundStart(data) {
    // Cards are now animated in the updated() hook
    // Just add a subtle pulse to container
    const cardsContainer = document.querySelector(".community-cards-area");
    if (cardsContainer) {
      cardsContainer.classList.add("pulse-animation");
      setTimeout(() => cardsContainer.classList.remove("pulse-animation"), 800);
    }
  },

  animateHandStart(data) {
    // Subtle glow animation on the table
    const container = document.getElementById("game-container");
    if (container) {
      container.classList.add("new-hand-glow");
      setTimeout(() => container.classList.remove("new-hand-glow"), 1000);
    }
  },

  animateHandFinish(data) {
    // Celebration animation for pot area
    const pot = document.querySelector(".pot-area");
    if (pot) {
      pot.classList.add("pot-win-animation");
      setTimeout(() => pot.classList.remove("pot-win-animation"), 800);
    }

    // Flash the community cards area to draw attention to showdown
    const cardsArea = document.querySelector(".community-cards-area");
    if (cardsArea) {
      cardsArea.classList.add("flash-animation");
      setTimeout(() => cardsArea.classList.remove("flash-animation"), 500);
    }

    // Add a special showdown highlight effect
    const gameContainer = document.getElementById("game-container");
    if (gameContainer) {
      gameContainer.classList.add("showdown-highlight");
      setTimeout(
        () => gameContainer.classList.remove("showdown-highlight"),
        3000,
      );
    }
  },

  animateCardReveal(participantId) {
    const playerCard = document.querySelector(
      `[data-participant-id="${participantId}"]`,
    );

    if (!playerCard) return;

    const showdownCards = playerCard.querySelector(".showdown-cards");
    if (showdownCards && showdownCards.children.length > 0) {
      Array.from(showdownCards.children).forEach((card, index) => {
        card.style.opacity = "0";
        card.style.transform = "rotateY(180deg) scale(0.9)";

        setTimeout(() => {
          card.classList.add("card-reveal");
          setTimeout(() => {
            card.classList.remove("card-reveal");
          }, 500);
        }, index * 100);
      });
    }
  },

  animatePlayerAction(participantId, action, amount = null) {
    // Find the player card by participant ID
    const playerCard = document.querySelector(
      `[data-participant-id="${participantId}"]`,
    );

    if (!playerCard) return;

    // Add action-specific animation class
    playerCard.classList.add(`action-${action}`);

    console.log(playerCard);

    // Show action badge
    this.showActionBadge(playerCard, action, amount);

    // Remove animation class after it completes
    setTimeout(() => {
      playerCard.classList.remove(`action-${action}`);
    }, 600);
  },

  showActionBadge(playerCard, action, amount) {
    // Create temporary badge element
    const badge = document.createElement("div");
    badge.className = "action-badge";

    let badgeText = action.toUpperCase();
    if (amount) {
      badgeText += ` ${amount}`;
    }

    badge.textContent = badgeText;
    badge.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 8px 16px;
      border-radius: 8px;
      font-weight: bold;
      font-size: 14px;
      z-index: 100;
      animation: fadeInOut 1.5s ease-in-out;
    `;

    // Make parent relative if it isn't
    const position = window.getComputedStyle(playerCard).position;
    if (position === "static") {
      playerCard.style.position = "relative";
    }

    console.log(badge);

    playerCard.appendChild(badge);

    // Remove badge after animation
    setTimeout(() => {
      badge.remove();
    }, 1500);
  },

  animatePotUpdate(data) {
    // Subtle pulse on pot amount
    const pot = document.querySelector(".pot-area");
    if (pot) {
      pot.classList.add("pot-update-pulse");
      setTimeout(() => pot.classList.remove("pot-update-pulse"), 400);
    }
  },
};
