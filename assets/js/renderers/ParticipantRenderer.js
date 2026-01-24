import * as PIXI from "pixi.js";
import gsap from "gsap";
import { CardRenderer } from "./CardRenderer.js";
import { ChipsRenderer } from "./ChipsRenderer.js";

// Table dimensions relative to base (not screen!)
const TABLE_RADIUS_X = 450;
const TABLE_RADIUS_Y = 300;

// Layout constants
const HOOD_WIDTH = 140;
const HOOD_HEIGHT = 74;
const HOOD_BORDER_RADIUS = 20;
const HOOD_PADDING = 14;

const CARD_OVERLAP = 50; // How much the hood covers the cards
const CARD_SPACING = 70;
const CARD_OFFSET_X = 0; // Center cards relative to hood

// Colors
const COLORS = {
  hoodBg: 0x1a1a1a,
  hoodBgFolded: 0x2a2a2a,
  border: 0x4a4a4a,
  borderFolded: 0x404040,
  divider: 0x3a3a3a,
  text: 0xffffff,
  textFolded: 0x888888,
  chips: 0x4ade80,
  chipsFolded: 0x666666,
  activeGlow: 0xf4d03f,
  timerGreen: 0x4ade80,
  timerYellow: 0xfbbf24,
  timerRed: 0xef4444,
  timerBg: 0x333333,
};

export class ParticipantRenderer {
  constructor(participantId, tableContainer, getState) {
    this.participantId = participantId;
    this.getState = getState;
    this.tableContainer = tableContainer;

    this.container = new PIXI.Container();
    this.container.sortableChildren = true;

    this.holeCardsContainer = new PIXI.Container();

    this.holeCardsContainer.zIndex = 1;
    this.holeCardsContainer.position.set(CARD_OFFSET_X, 0);

    this.hoodContainer = new PIXI.Container();

    this.betAreaContainer = new PIXI.Container({
      x: 0,
      y: -60,
    });

    this.tableContainer.addChild(this.container);
  }

  render() {
    this.container.removeChildren();

    const position = this.#getPlayerPosition();

    this.container.position.set(position.x, position.y);

    this.#renderHood();
    this.#renderHoleCards();
    this.#renderChips();
  }

  async #flipCard(cardContainer, card) {
    await gsap.to(cardContainer.scale, {
      x: 0,
      duration: 0.2,
      ease: "power2.in",
    });

    const cardRenderer = new CardRenderer();
    const newCardContent = cardRenderer.render(card);

    cardContainer.removeChildren();

    cardContainer.addChild(newCardContent);

    await gsap.to(cardContainer.scale, {
      x: 1,
      duration: 0.2,
      ease: "power2.out",
    });
  }

  async flipHoleCards(holeCards) {
    const flipCardPromises = this.holeCardsContainer.children.map(
      async (cardContainer, idx) =>
        this.#flipCard(cardContainer, holeCards[idx]),
    );

    await Promise.all(flipCardPromises);
  }

  #renderChips() {
    this.betAreaContainer.removeChildren();

    const state = this.getState();

    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );

    const chipsRenderer = new ChipsRenderer();

    const chipsContainer = chipsRenderer.render(participant.betThisRound);

    if (participant.betThisRound > 0) {
      const chipsText = new PIXI.Text({
        text: this.formatChips(participant.betThisRound),
        style: {
          fontFamily: "Arial, sans-serif",
          fontSize: 24,
          fontWeight: "bold",
          fill: "#e2e2e2",
        },
      });

      chipsText.position.set(40, -10);

      this.betAreaContainer.addChild(chipsText);

      chipsText.label = "betChipsText";
    }

    this.betAreaContainer.addChild(chipsContainer);

    this.container.addChild(this.betAreaContainer);
  }

  #renderHoleCards() {
    this.holeCardsContainer.removeChildren();

    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );
    const holeCards = participant.holeCards;

    const cardRenderer = new CardRenderer();
    holeCards.forEach((card, index) => {
      const cardSprite = cardRenderer.render(card);

      cardSprite.position.set(index * CARD_SPACING, 0);

      this.holeCardsContainer.addChild(cardSprite);
    });

    this.container.addChild(this.holeCardsContainer);
  }

  #renderHood() {
    this.hoodContainer.removeChildren();

    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );

    const isFolded = participant.handStatus === "folded";
    const isActive = participant.isActive || false;

    this.hoodContainer.zIndex = 2; // Above cards
    this.hoodContainer.position.set(0, CARD_OVERLAP); // Position below cards top

    const hood = new PIXI.Graphics();

    if (isActive) {
      hood.roundRect(
        -2,
        -2,
        HOOD_WIDTH + 4,
        HOOD_HEIGHT + 4,
        HOOD_BORDER_RADIUS + 2,
      );
      hood.fill({ color: COLORS.activeGlow, alpha: 0.8 });
    }

    // Main background
    hood.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    hood.fill(isFolded ? COLORS.hoodBgFolded : COLORS.hoodBg);

    // Subtle border
    hood.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    hood.stroke({
      color: isFolded ? COLORS.borderFolded : COLORS.border,
      width: 1.5,
    });

    this.hoodContainer.addChild(hood);

    const divider = new PIXI.Graphics();

    divider.moveTo(HOOD_PADDING, HOOD_HEIGHT / 2);
    divider.lineTo(HOOD_WIDTH - HOOD_PADDING, HOOD_HEIGHT / 2);
    divider.stroke({ color: COLORS.divider, width: 1 });

    this.hoodContainer.addChild(divider);

    //     const lobbyUser = this.pokerCanvas.lobbyState.participants.find(
    //       (p) => p.id === participant.player_id,
    //     );

    //     const displayName = this.truncateText(
    //       lobbyUser?.email?.split("@")[0] || "Player",
    //       12,
    //     );

    const displayName = this.truncateText("Player", 12);

    const nameText = new PIXI.Text({
      text: displayName,
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 13,
        fontWeight: "bold",
        fill: isFolded ? COLORS.textFolded : COLORS.text,
      },
    });

    nameText.anchor.set(0.5, 0.5);
    nameText.position.set(HOOD_WIDTH / 2, HOOD_PADDING + 4);

    this.hoodContainer.addChild(nameText);

    // Chips amount
    const chipsText = new PIXI.Text({
      text: this.formatChips(participant.chips),
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 14,
        fontWeight: "bold",
        fill: isFolded ? COLORS.chipsFolded : COLORS.chips,
      },
    });

    chipsText.anchor.set(0.5, 0.5);
    chipsText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT - HOOD_PADDING - 2);

    this.hoodContainer.addChild(chipsText);
    this.container.addChild(this.hoodContainer);
  }

  #getPlayerPosition() {
    const state = this.getState();

    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );

    const participantIndex = state.participants.findIndex(
      (p) => p === participant,
    );

    const currentUserIndex = state.participants.findIndex(
      (p) => p.playerId === state.currentUserId,
    );

    const relativePosition =
      (participantIndex - currentUserIndex + state.participants.length) %
      state.participants.length;

    const radiusX = TABLE_RADIUS_X;
    const radiusY = TABLE_RADIUS_Y;

    const positions = {
      0: { x: -45, y: radiusY + 45 }, // Hero - bottom center
      1: { x: radiusX - 45, y: radiusY * 0.4 }, // Bottom right
      2: { x: radiusX + 60, y: -radiusY * 0.4 }, // Top right
      3: { x: 0, y: -radiusY - 80 }, // Top center
      4: { x: -radiusX - 60, y: -radiusY * 0.4 }, // Top left
      5: { x: -radiusX - 60, y: radiusY * 0.4 }, // Bottom left
    };

    return positions[relativePosition];
  }

  async animateHandGiven(tableContainer, timing) {
    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );
    const timeline = gsap.timeline();

    const globalCenter = tableContainer.toGlobal({
      x: 0,
      y: 0,
    });

    const localStart = this.container.toLocal(globalCenter);

    const cardRenderer = new CardRenderer();
    participant.holeCards.forEach((card, index) => {
      const cardSprite = cardRenderer.render(card);

      cardSprite.position.set(localStart.x - 40, localStart.y - 40);
      cardSprite.alpha = 0;
      cardSprite.zIndex = 1;

      this.container.addChild(cardSprite);

      timeline.to(
        cardSprite,
        {
          x: CARD_OFFSET_X + index * CARD_SPACING,
          y: 0,
          alpha: 1,
          duration: timing.duration / 1000 || 0.25,
          delay: index * 0.15,
          ease: "power2.out",
        },
        0,
      );
    });

    await timeline.then();
  }

  truncateText(text, maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - 1) + "…";
  }

  formatChips(amount) {
    if (amount >= 1000000) {
      return `$${(amount / 1000000).toFixed(1)}M`;
    }
    if (amount >= 10000) {
      return `$${(amount / 1000).toFixed(1)}K`;
    }
    return `$${amount.toLocaleString()}`;
  }

  clearHoleCards() {
    this.holeCardsContainer.removeChildren();
  }

  hideBetAreaChipsText() {
    const chipsText = this.betAreaContainer.getChildByLabel("betChipsText");

    if (chipsText) {
      chipsText.visible = false;
    }
  }

  showBetAreaChipsText() {
    const chipsText = this.betAreaContainer.getChildByLabel("betChipsText");

    if (chipsText) {
      chipsText.visible = true;
    }
  }
}
