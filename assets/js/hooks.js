// LiveView Hooks for poker game animations

// Animation timing constants (match server-side AnimationDelays)
const ANIMATION_TIMINGS = {
  ACTION_BOUNCE: 600,
  ACTION_BADGE: 1500,
  PULSE: 600,
  GLOW: 600,
  POT_PULSE: 400,
  POT_WIN: 800,
  CARD_STAGGER: 150,
  CARD_SLIDE_IN: 400,
  CARD_REVEAL: 500,
  CARD_DEAL: 500,
  CARD_DEAL_STAGGER: 50,
  CHIP_APPEAR: 50,
  CHIP_SLIDE: 400,
  CHIP_COLLECT: 400,
  CHIP_STAGGER_PER_PLAYER: 150,
  CHIP_STAGGER_PER_CHIP: 25,
  SHOWDOWN_GLOW: 2000,
  FLASH: 500,
  NEW_HAND_GLOW: 1000,
};

/**
 * Animates element by adding CSS class with animationend tracking
 * @param {HTMLElement} element - Target element
 * @param {string} className - CSS class to add
 * @param {number} duration - Duration in milliseconds
 * @returns {Promise<void>} Resolves when animation completes
 */
async function animateWithClass(element, className, duration) {
  return new Promise((resolve) => {
    element.classList.add(className);

    const handleAnimationEnd = (e) => {
      if (e.target === element) {
        element.removeEventListener("animationend", handleAnimationEnd);
        element.classList.remove(className);
        resolve();
      }
    };

    element.addEventListener("animationend", handleAnimationEnd);
  });
}

/**
 * Run animations sequentially with stagger delay
 * @param {Array} items - Array of items to animate
 * @param {Function} animateFn - Async function that animates one item
 * @param {number} staggerDelay - Delay between each animation start (ms)
 * @returns {Promise<void>} Resolves when all animations complete
 */
async function animateStaggered(items, animateFn, staggerDelay) {
  for (let i = 0; i < items.length; i++) {
    const animationPromise = animateFn(items[i], i);

    if (i < items.length - 1) {
      // Wait for stagger delay or animation completion, whichever comes first
      await Promise.race([
        animationPromise,
        new Promise((resolve) => setTimeout(resolve, staggerDelay)),
      ]);
    } else {
      // Wait for last animation to complete fully
      await animationPromise;
    }
  }
}

/**
 * Create temporary animated element that auto-removes
 * @param {Object} config - Element configuration
 * @returns {Promise<void>} Resolves when animation completes and element is removed
 */
async function createAnimatedElement(config) {
  const {
    tag = "div",
    className,
    styles,
    innerHTML,
    parent = document.body,
    keyframes,
    duration,
    easing = "ease-out",
  } = config;

  const element = document.createElement(tag);
  if (className) element.className = className;
  if (innerHTML) element.innerHTML = innerHTML;
  if (styles) Object.assign(element.style, styles);

  parent.appendChild(element);

  try {
    if (keyframes) {
      const animation = element.animate(keyframes, {
        duration,
        easing,
        fill: "forwards",
      });
      await animation.finished;
    }
  } finally {
    element.remove();
  }
}

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

  async animateNewCards() {
    const cardsContainer = document.querySelector(".community-cards-area");

    const currentCards = cardsContainer.querySelectorAll(".community-card");

    const currentCardCount = currentCards.length;

    if (currentCardCount > this.previousCardCount) {
      const newCards = Array.from(currentCards).slice(this.previousCardCount);

      await animateStaggered(
        newCards,
        async (card) => {
          await animateWithClass(
            card,
            "card-slide-in",
            ANIMATION_TIMINGS.CARD_SLIDE_IN,
          );
        },
        5000,
      );
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
    const duration = delay || 0;
    const animationStart = Date.now();

    console.log(type);

    try {
      // Execute animation (now returns promise)
      switch (type) {
        case "ParticipantHandGiven":
          await this.animateCardDeal(data);
          break;
        case "RoundStarted":
          await this.animateNewCards();
          break;
        case "ParticipantShowdownCardsRevealed":
          await this.animateCardReveal(data.participant_id);
          break;
        case "SmallBlindPosted":
          await this.animateBetChipsAppear(data.participant_id);
          break;
        case "BigBlindPosted":
          await this.animateBetChipsAppear(data.participant_id);
          break;
        case "ParticipantCalled":
          await this.animateBetChipsAppear(data.participant_id);
          break;
        case "ParticipantRaised":
          await this.animateBetChipsAppear(data.participant_id);
          break;
        case "ParticipantWentAllIn":
          await this.animateBetChipsAppear(data.participant_id);
          break;
        case "PotsRecalculated":
          await this.animateChipsToPot();
          break;
        case "PayoutDistributed":
          await this.animatePayoutToWinner(data);
          break;
        default:
          // Unknown event type, no animation
          break;
      }
    } finally {
      // Always notify server that event is processed
      this.pushEvent("event_processed", { event_id: data.event_id });
    }
  },

  async animateCardReveal(participantId) {
    const playerCard = document.querySelector(
      `[data-participant-id="${participantId}"]`,
    );

    if (!playerCard) return;

    const showdownCards = playerCard.querySelector(".showdown-cards");
    if (!showdownCards || showdownCards.children.length === 0) return;

    const cards = Array.from(showdownCards.children);

    await animateStaggered(
      cards,
      async (card) => {
        card.style.opacity = "0";
        card.style.transform = "rotateY(180deg) scale(0.9)";
        await animateWithClass(
          card,
          "card-reveal",
          ANIMATION_TIMINGS.CARD_REVEAL,
        );

        card.style.transform = "rotateY(0deg) scale(1)";
        card.style.opacity = "1";
      },
      100,
    );
  },

  async animatePotUpdate(data) {
    // Subtle pulse on pot amount
    const pot = document.querySelector(".pot-area");
    if (pot) {
      await animateWithClass(
        pot,
        "pot-update-pulse",
        ANIMATION_TIMINGS.POT_PULSE,
      );
    }
  },

  async animateBetChipsAppear(participantId) {
    // Animate chips appearing in bet area with stagger
    const betArea = document.querySelector(
      `[data-bet-area][data-participant-id="${participantId}"]`,
    );

    if (!betArea) return;

    const chips = Array.from(betArea.querySelectorAll(".poker-chip"));

    await animateStaggered(
      chips,
      async (chip) => {
        await animateWithClass(
          chip,
          "chip-appear",
          ANIMATION_TIMINGS.CHIP_APPEAR,
        );
      },
      ANIMATION_TIMINGS.CHIP_STAGGER_PER_CHIP,
    );
  },

  async animateChipsToPot() {
    // Animate chips sliding from bet areas to pot center
    const potArea = document.querySelector("[data-pot-area]");

    if (!potArea) return;

    const betAreas = Array.from(document.querySelectorAll(".bet-area"));

    const potRect = potArea.getBoundingClientRect();

    await animateStaggered(
      betAreas,
      async (betArea) => {
        const chips = Array.from(
          betArea.querySelectorAll(".bet-chips .poker-chip"),
        );

        const betAmount = betArea.querySelector(".bet-amount");

        betAmount.classList.add("!hidden");

        const betRect = betArea.getBoundingClientRect();

        // Calculate delta from bet area to pot center
        const deltaX =
          potRect.left + potRect.width / 2 - (betRect.left + betRect.width / 2);
        const deltaY =
          potRect.top + potRect.height / 2 - (betRect.top + betRect.height / 2);

        // Animate chips within this bet area with stagger
        await animateStaggered(
          chips,
          async (chip) => {
            chip.style.setProperty("--start-x", "0px");
            chip.style.setProperty("--start-y", "0px");
            chip.style.setProperty("--end-x", `${deltaX}px`);
            chip.style.setProperty("--end-y", `${deltaY}px`);

            await animateWithClass(
              chip,
              "chip-slide",
              ANIMATION_TIMINGS.CHIP_SLIDE,
            );

            chip.style.transform = `translateY(${deltaY}px) translateX(${deltaX}px)`;
          },
          ANIMATION_TIMINGS.CHIP_STAGGER_PER_CHIP,
        );

        console.log("ENDDD");
      },
      ANIMATION_TIMINGS.CHIP_STAGGER_PER_PLAYER,
    );
  },

  async animatePayoutToWinner(data) {
    // Animate chips sliding from pot to winner and collecting
    const { participant_id } = data;
    const potArea = document.querySelector("[data-pot-area]");
    const totalPotAmount = document.querySelector(".total-pot-amount");
    const winnerCard = document.querySelector(
      `[data-participant-id="${participant_id}"]`,
    );

    if (!potArea || !winnerCard || !totalPotAmount) return;

    const potRect = potArea.getBoundingClientRect();
    const winnerRect = winnerCard.getBoundingClientRect();

    // Calculate delta from pot to winner
    const deltaX =
      winnerRect.left +
      winnerRect.width / 2 -
      (potRect.left + potRect.width / 2);
    const deltaY =
      winnerRect.top +
      winnerRect.height / 2 -
      (potRect.top + potRect.height / 2);

    const potChips = Array.from(
      potArea.querySelectorAll(".pot-chips .poker-chip"),
    );

    totalPotAmount.remove();

    const gameContainer = document.getElementById("game-container");

    return Promise.all([
      animateWithClass(
        gameContainer,
        "showdown-highlight",
        ANIMATION_TIMINGS.SHOWDOWN_GLOW,
      ),

      animateStaggered(
        potChips,
        async (chip) => {
          chip.style.setProperty("--start-x", "0px");
          chip.style.setProperty("--start-y", "0px");
          chip.style.setProperty("--end-x", `${deltaX}px`);
          chip.style.setProperty("--end-y", `${deltaY}px`);

          await animateWithClass(
            chip,
            "chip-slide",
            ANIMATION_TIMINGS.CHIP_SLIDE,
          );

          chip.style.transform = `translateY(${deltaY}px) translateX(${deltaX}px)`;
        },
        100,
      ),
    ]);
  },

  async animateCardDeal(data) {
    // Animate cards flying from dealer position to participant
    const { participant_id } = data;

    const participantCard = document.querySelector(
      `[data-participant-id="${participant_id}"]`,
    );

    const cardsArea = document.querySelector(
      `[data-participant-id="${participant_id}"] > [data-cards-area]`,
    );

    cardsArea.classList.add("hidden");

    // Find dealer position (center of table/pot area)
    const dealerPosition = document.querySelector(".community-cards-area");

    const dealerRect = dealerPosition.getBoundingClientRect();
    const participantRect = participantCard.getBoundingClientRect();

    // Calculate starting position (dealer) and ending position (participant cards area)
    const startX = dealerRect.left + dealerRect.width / 2;
    const startY = dealerRect.top + dealerRect.height / 2;
    const endX = participantRect.left + participantRect.width / 2;
    const endY = participantRect.top + 10; // Position near top of participant card

    console.log("Card deal animation:", {
      startX,
      startY,
      endX,
      endY,
      dealerRect,
      participantRect,
    });

    // Create and animate 2 flying cards with stagger
    await animateStaggered(
      [0, 1], // Two cards
      async (cardIndex) => {
        await createAnimatedElement({
          className:
            "flying-card bg-blue-900 border-2 border-blue-700 rounded shadow-lg w-16 h-20 flex items-center justify-center",
          styles: {
            position: "fixed",
            left: `${startX - 32}px`,
            top: `${startY - 40}px`,
            zIndex: "1",
            pointerEvents: "none",
          },
          innerHTML: '<span class="text-blue-400 text-2xl">🂠</span>',
          parent: document.body,
          keyframes: [
            {
              left: `${startX - 32}px`,
              top: `${startY - 40}px`,
              transform: "rotate(0deg)",
              offset: 0,
            },
            {
              left: `${endX - 32 + cardIndex * 10}px`,
              top: `${endY - 40}px`,
              transform: "rotate(5deg)",
              offset: 1,
            },
          ],
          duration: ANIMATION_TIMINGS.CARD_DEAL,
          easing: "cubic-bezier(0.25, 0.46, 0.45, 0.94)",
        });

        console.log(`Animated and removed flying card ${cardIndex + 1}`);
      },
      ANIMATION_TIMINGS.CARD_DEAL_STAGGER,
    );

    cardsArea.classList.remove("hidden");
  },
};
