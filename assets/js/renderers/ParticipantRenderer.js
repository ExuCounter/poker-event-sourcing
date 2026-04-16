import * as PIXI from "pixi.js";
import gsap from "gsap";
import { CardRenderer } from "./CardRenderer.js";
import { ChipsRenderer } from "./ChipsRenderer.js";
import {
  TABLE_RADIUS_X,
  TABLE_RADIUS_Y,
  HOLE_CARD_SPACING,
  CARD_OFFSET_X,
  HOOD_WIDTH,
  HOOD_HEIGHT,
  HOOD_BORDER_RADIUS,
  HOOD_PADDING,
  CARD_OVERLAP,
  PARTICIPANT_COLORS,
  CARD_HEIGHT,
} from "../constants.js";

export class ParticipantRenderer {
  constructor(participantId, tableContainer, getState) {
    this.participantId = participantId;
    this.getState = getState;
    this.tableContainer = tableContainer;

    this.container = new PIXI.Container();
    this.container.sortableChildren = true;

    this.holeCardsContainer = new PIXI.Container();

    this.hoodContainer = new PIXI.Container();

    this.betAreaContainer = new PIXI.Container();

    this.tableContainer.addChild(this.container);

    // Timeout progress properties
    this.progressArc = null;
    this.countdownText = null;
    this.alertSoundPlayed = false;
    this.countdownPulseTween = null;
    this.arcPulseTween = null;
  }

  getContainer() {
    return this.container;
  }

  render() {
    this.container.removeChildren();

    const participantPosition = this.#getPlayerPosition();
    const betPosition = this.#getBetPosition();

    this.betAreaContainer.position.set(betPosition.x, betPosition.y);

    this.container.position.set(participantPosition.x, participantPosition.y);

    this.#renderHood();
    this.#renderHoleCards();
    this.#renderChips();
  }

  renderHood() {
    this.hoodContainer.removeChildren();
    this.betAreaContainer.removeChildren();

    this.#renderHood();
    this.#renderChips();

    if (!this.container.children.includes(this.hoodContainer)) {
      this.container.addChild(this.hoodContainer);
    }
    if (!this.container.children.includes(this.betAreaContainer)) {
      this.container.addChild(this.betAreaContainer);
    }
  }

  async #flipCard(cardContainer, card) {
    await gsap.to(cardContainer.scale, {
      x: 0,
      duration: 0.2,
      ease: "power2.in",
    });

    const cardRenderer = new CardRenderer();
    const newCardContent = cardRenderer.renderHoleCard(card);

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
          fontSize: 18,
          fontWeight: "bold",
          fill: "#e2e2e2",
        },
      });

      chipsText.position.set(-chipsText.width / 2, chipsText.height + 5);

      this.betAreaContainer.addChild(chipsText);

      chipsText.label = "betChipsText";
    }

    this.betAreaContainer.addChild(chipsContainer);
    this.betAreaContainer.zIndex = 5;

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
      const cardSprite = cardRenderer.renderHoleCard(card);

      cardSprite.position.set(index * HOLE_CARD_SPACING, 0);

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

    const isFolded =
      participant.handStatus === "folded" || participant.isSittingOut;
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
      hood.fill({ color: PARTICIPANT_COLORS.activeGlow, alpha: 0.8 });
    }

    // Main background
    hood.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    hood.fill(
      isFolded ? PARTICIPANT_COLORS.hoodBgFolded : PARTICIPANT_COLORS.hoodBg,
    );

    // Subtle border
    hood.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    hood.stroke({
      color: isFolded
        ? PARTICIPANT_COLORS.borderFolded
        : PARTICIPANT_COLORS.border,
      width: 1.5,
    });

    this.hoodContainer.addChild(hood);

    const divider = new PIXI.Graphics();

    divider.moveTo(HOOD_PADDING, HOOD_HEIGHT / 2);
    divider.lineTo(HOOD_WIDTH - HOOD_PADDING, HOOD_HEIGHT / 2);
    divider.stroke({ color: PARTICIPANT_COLORS.divider, width: 1 });

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
        fontSize: 18,
        fontWeight: "bold",
        fill: isFolded
          ? PARTICIPANT_COLORS.textFolded
          : PARTICIPANT_COLORS.text,
      },
    });

    nameText.anchor.set(0.5, 0.5);
    nameText.position.set(HOOD_WIDTH / 2, HOOD_PADDING + 8);

    this.hoodContainer.addChild(nameText);

    // Chips amount
    const chipsText = new PIXI.Text({
      text: this.formatChips(participant.chips),
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 18,
        fontWeight: "bold",
        fill: isFolded
          ? PARTICIPANT_COLORS.chipsFolded
          : PARTICIPANT_COLORS.chips,
      },
    });

    chipsText.anchor.set(0.5, 0.5);
    chipsText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT - HOOD_PADDING - 6);

    this.hoodContainer.addChild(chipsText);
    this.container.addChild(this.hoodContainer);
  }

  #getPlayerPosition() {
    const state = this.getState();
    const participantIndex = state.participants.findIndex(
      (p) => p.id === this.participantId,
    );
    const currentUserIndex = state.participants.findIndex(
      (p) => p.playerId === state.currentUserId,
    );
    const playerCount = state.participants.length;
    const relativePosition =
      (participantIndex - currentUserIndex + playerCount) % playerCount;

    const radiusX = TABLE_RADIUS_X * 1.07;
    const radiusY = TABLE_RADIUS_Y * 1.07;
    const padding = 40; // Distance from table edge to the outer edge of hood

    // Start from bottom (π/2) and go clockwise
    const angle =
      Math.PI / 2 - (relativePosition * (2 * Math.PI)) / playerCount;

    const cosAngle = Math.cos(angle);
    const sinAngle = Math.sin(angle);

    // Calculate radius at this angle (distance from center to ellipse edge)
    const radiusAtAngle =
      (radiusX * radiusY) /
      Math.sqrt((radiusY * cosAngle) ** 2 + (radiusX * sinAngle) ** 2);

    const containerFarEdgeOffset = 0;
    const targetRadius = radiusAtAngle + padding - containerFarEdgeOffset;

    return {
      x: targetRadius * cosAngle - HOOD_WIDTH / 2,
      y: targetRadius * sinAngle - 70,
    };
  }
  #getBetPosition() {
    const state = this.getState();
    const participantIndex = state.participants.findIndex(
      (p) => p.id === this.participantId,
    );
    const currentUserIndex = state.participants.findIndex(
      (p) => p.playerId === state.currentUserId,
    );
    const playerCount = state.participants.length;
    const relativePosition =
      (participantIndex - currentUserIndex + playerCount) % playerCount;

    const radiusX = TABLE_RADIUS_X;
    const radiusY = TABLE_RADIUS_Y;
    const betInset = 100; // Distance from edge toward center

    const angle =
      Math.PI / 2 - (relativePosition * (2 * Math.PI)) / playerCount;

    const cosAngle = Math.cos(angle);
    const sinAngle = Math.sin(angle);

    // Calculate radius at this angle
    const radiusAtAngle =
      (radiusX * radiusY) /
      Math.sqrt((radiusY * cosAngle) ** 2 + (radiusX * sinAngle) ** 2);

    // Bet position inset from edge
    const betRadius = radiusAtAngle - betInset;
    const betX = betRadius * cosAngle;
    const betY = betRadius * sinAngle;

    // Player position for relative offset
    const playerRadius = radiusAtAngle + 40;
    const playerX = playerRadius * cosAngle;
    const playerY = playerRadius * sinAngle;

    return {
      x: betX - playerX + HOOD_WIDTH / 2,
      y: betY - playerY + CARD_HEIGHT / 2 + 15,
    };
  }

  async animateHandGiven(tableContainer, timing) {
    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );

    if (!participant.holeCards) return;

    const timeline = gsap.timeline();

    const globalCenter = tableContainer.toGlobal({
      x: 0,
      y: 0,
    });

    const localStart = this.container.toLocal(globalCenter);

    const cardRenderer = new CardRenderer();

    participant.holeCards.forEach((card, index) => {
      const cardSprite = cardRenderer.renderHoleCard(card);

      cardSprite.position.set(localStart.x - 40, localStart.y - 40);
      cardSprite.alpha = 0;
      cardSprite.zIndex = 1;

      this.container.addChild(cardSprite);

      timeline.to(
        cardSprite,
        {
          x: CARD_OFFSET_X + index * HOLE_CARD_SPACING,
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

  renderTimeoutProgress() {
    // Remove existing progress arc if any
    if (this.progressArc) {
      this.hoodContainer.removeChild(this.progressArc);
      this.progressArc = null;
    }

    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );

    if (!participant?.isActive || !state.timeoutInfo) return;

    // Calculate time remaining
    const startedAt = new Date(state.timeoutInfo.startedAt);
    const now = new Date();
    const elapsed = (now - startedAt) / 1000; // seconds
    const remaining = Math.max(0, state.timeoutInfo.timeoutSeconds - elapsed);
    const progress = remaining / state.timeoutInfo.timeoutSeconds;

    // Determine arc color based on remaining time (blue → yellow → red)
    let arcColor;
    if (progress > 0.5) {
      arcColor = 0x2563eb; // Blue (primary)
    } else if (progress > 0.25) {
      arcColor = 0xfbbf24; // Yellow/amber
    } else {
      arcColor = 0xef4444; // Red
    }

    // Create circular progress arc
    const graphics = new PIXI.Graphics();
    const radius = 60; // Adjust based on hood size
    const lineWidth = 3;
    const startAngle = -Math.PI / 2; // Start at top
    const endAngle = startAngle + 2 * Math.PI * progress;

    graphics.arc(HOOD_WIDTH / 2, HOOD_HEIGHT / 2, radius, startAngle, endAngle);
    graphics.stroke({ color: arcColor, width: lineWidth });

    this.progressArc = graphics;
    this.hoodContainer.addChild(graphics);

    // Show countdown when < 10s
    if (remaining < 10 && remaining > 0) {
      this.renderCountdown(Math.ceil(remaining), remaining <= 5);
    } else if (this.countdownText) {
      this.hoodContainer.removeChild(this.countdownText);
      this.countdownText = null;
    }

    // Play alert sound at 5 seconds (once)
    if (remaining <= 5 && remaining > 4.9 && !this.alertSoundPlayed) {
      this.playTimeoutAlert();
      this.alertSoundPlayed = true;
    }
    if (remaining > 5) {
      this.alertSoundPlayed = false; // Reset for next timeout
    }
  }

  renderCountdown(seconds, shouldPulse = false) {
    if (!this.countdownText) {
      this.countdownText = new PIXI.Text({
        text: seconds.toString(),
        style: {
          fontSize: 24,
          fontWeight: "bold",
          fill: 0xff0000,
        },
      });
      this.countdownText.anchor.set(0.5);
      this.countdownText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT + 30);
      this.hoodContainer.addChild(this.countdownText);
    } else {
      this.countdownText.text = seconds.toString();
    }

    // Add pulsing animation when <= 5 seconds
    if (shouldPulse && !this.countdownPulseTween) {
      this.countdownPulseTween = gsap.to(this.countdownText.scale, {
        x: 1.3,
        y: 1.3,
        duration: 0.5,
        repeat: -1,
        yoyo: true,
        ease: "power1.inOut",
      });

      // Also pulse the progress arc
      if (this.progressArc && !this.arcPulseTween) {
        this.arcPulseTween = gsap.to(this.progressArc, {
          alpha: 0.5,
          duration: 0.5,
          repeat: -1,
          yoyo: true,
          ease: "power1.inOut",
        });
      }
    }

    // Stop pulsing when time is up or above 5s
    if (!shouldPulse && this.countdownPulseTween) {
      this.countdownPulseTween.kill();
      this.countdownPulseTween = null;
      this.countdownText.scale.set(1, 1);

      if (this.arcPulseTween) {
        this.arcPulseTween.kill();
        this.arcPulseTween = null;
        if (this.progressArc) this.progressArc.alpha = 1;
      }
    }
  }

  playTimeoutAlert() {
    // Play a short beep sound
    const audioContext = new (window.AudioContext ||
      window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.value = 800; // Hz
    oscillator.type = "sine";

    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(
      0.01,
      audioContext.currentTime + 0.3,
    );

    oscillator.start(audioContext.currentTime);
    oscillator.stop(audioContext.currentTime + 0.3);
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
