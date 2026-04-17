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
  constructor(participantId, tableContainer, getState, getLobbyState) {
    this.participantId = participantId;
    this.getState = getState;
    this.getLobbyState = getLobbyState;
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

    // Hood text elements for partial updates
    this.balanceText = null;
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

  async #flipCard(cardContainer, card, timing) {
    const flipDuration = timing.duration / 1000 / 2; // Half for flip out, half for flip in

    console.log(timing);
    console.log(flipDuration);

    await gsap.to(cardContainer.scale, {
      x: 0,
      duration: flipDuration,
      ease: "power2.in",
    });

    const cardRenderer = new CardRenderer();
    const newCardContent = cardRenderer.renderHoleCard(card);

    cardContainer.removeChildren();

    cardContainer.addChild(newCardContent);

    await gsap.to(cardContainer.scale, {
      x: 1,
      duration: flipDuration,
      ease: "power2.out",
    });
  }

  async flipHoleCards(holeCards, timing) {
    const flipCardPromises = this.holeCardsContainer.children.map(
      async (cardContainer, idx) =>
        this.#flipCard(cardContainer, holeCards[idx], timing),
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

    this.hoodContainer.zIndex = 2; // Above cards
    this.hoodContainer.position.set(0, CARD_OVERLAP); // Position below cards top

    const hood = new PIXI.Graphics();

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

    const lobbyState = this.getLobbyState();
    const lobbyUser = lobbyState.participants.find(
      (p) => p.playerId === participant.playerId,
    );

    const displayName = this.truncateText(lobbyUser?.nickname, 12);

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
          duration: timing.duration / 1000,
          delay: index * (timing.stagger / 1000),
          ease: "power2.out",
        },
        0,
      );
    });

    await timeline.then();
  }

  renderTimeoutProgress() {
    // Remove existing progress border if any
    if (this.progressArc) {
      this.hoodContainer.removeChild(this.progressArc);
      this.progressArc = null;
    }

    const state = this.getState();

    // Check if this participant is the active player (whose turn it is)
    const isActive = state.currentTurn?.participantId === this.participantId;

    if (!isActive || !state.timeoutInfo) return;

    // Calculate time remaining
    const startedAt = new Date(state.timeoutInfo.startedAt);
    const now = new Date();
    const elapsed = (now - startedAt) / 1000; // seconds
    const remaining = Math.max(0, state.timeoutInfo.timeoutSeconds - elapsed);

    // Only show timer when 15 seconds or less remain
    const TIMER_SHOW_THRESHOLD = 15;
    if (remaining > TIMER_SHOW_THRESHOLD || remaining <= 0) return;

    // Progress is based on the 15-second window (full at 15s, empty at 0s)
    const progress = remaining / TIMER_SHOW_THRESHOLD;

    // Determine border color based on remaining time (green → yellow → red)
    // 15-10s: green, 10-5s: yellow, <5s: red
    let borderColor;
    if (remaining > 10) {
      borderColor = 0x4ade80; // Green
    } else if (remaining > 5) {
      borderColor = 0xfbbf24; // Yellow/amber
    } else {
      borderColor = 0xef4444; // Red
    }

    // Draw rounded rectangle border that shrinks with progress
    const graphics = new PIXI.Graphics();
    const lineWidth = 4;
    const padding = 3; // Offset from hood edge
    const w = HOOD_WIDTH + padding * 2;
    const h = HOOD_HEIGHT + padding * 2;
    const r = HOOD_BORDER_RADIUS + padding;
    const left = -padding;
    const top = -padding;
    const right = left + w;
    const bottom = top + h;

    // Calculate perimeter
    const straightH = w - 2 * r;
    const straightV = h - 2 * r;
    const cornerLen = (Math.PI / 2) * r;
    const totalPerimeter = 2 * straightH + 2 * straightV + 4 * cornerLen;
    const drawLength = totalPerimeter * progress;

    // Path points going clockwise from top-center
    const halfTop = straightH / 2;

    // Cumulative lengths at the END of each segment
    const cumLengths = [
      halfTop, // 0: top-right line
      halfTop + cornerLen, // 1: top-right corner
      halfTop + cornerLen + straightV, // 2: right line
      halfTop + 2 * cornerLen + straightV, // 3: bottom-right corner
      halfTop + 2 * cornerLen + straightV + straightH, // 4: bottom line
      halfTop + 3 * cornerLen + straightV + straightH, // 5: bottom-left corner
      halfTop + 3 * cornerLen + 2 * straightV + straightH, // 6: left line
      halfTop + 4 * cornerLen + 2 * straightV + straightH, // 7: top-left corner
      totalPerimeter, // 8: top-left line (back to center)
    ];

    // Start at exact top-center of the hood (not padded area)
    const startX = HOOD_WIDTH / 2;
    const startY = top;
    graphics.moveTo(startX, startY);

    let prevCum = 0;

    // Segment 0: Top edge right half (going right)
    if (drawLength > 0) {
      const segLen = Math.min(halfTop, drawLength);
      graphics.lineTo(startX + segLen, top);
    }
    prevCum = cumLengths[0];

    // Segment 1: Top-right corner
    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(
        right - r,
        top + r,
        r,
        -Math.PI / 2,
        -Math.PI / 2 + angleSpan,
      );
    }
    prevCum = cumLengths[1];

    // Segment 2: Right edge (going down)
    if (drawLength > prevCum) {
      const segLen = Math.min(straightV, drawLength - prevCum);
      graphics.lineTo(right, top + r + segLen);
    }
    prevCum = cumLengths[2];

    // Segment 3: Bottom-right corner
    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(right - r, bottom - r, r, 0, angleSpan);
    }
    prevCum = cumLengths[3];

    // Segment 4: Bottom edge (going left)
    if (drawLength > prevCum) {
      const segLen = Math.min(straightH, drawLength - prevCum);
      graphics.lineTo(right - r - segLen, bottom);
    }
    prevCum = cumLengths[4];

    // Segment 5: Bottom-left corner
    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(
        left + r,
        bottom - r,
        r,
        Math.PI / 2,
        Math.PI / 2 + angleSpan,
      );
    }
    prevCum = cumLengths[5];

    // Segment 6: Left edge (going up)
    if (drawLength > prevCum) {
      const segLen = Math.min(straightV, drawLength - prevCum);
      graphics.lineTo(left, bottom - r - segLen);
    }
    prevCum = cumLengths[6];

    // Segment 7: Top-left corner
    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(left + r, top + r, r, Math.PI, Math.PI + angleSpan);
    }
    prevCum = cumLengths[7];

    // Segment 8: Top edge left half (going right back to center)
    if (drawLength > prevCum) {
      const segLen = Math.min(halfTop, drawLength - prevCum);
      // We're at (left + r, top) after the corner, go right
      graphics.lineTo(left + r + segLen, top);
    }

    graphics.stroke({ color: borderColor, width: lineWidth });

    this.progressArc = graphics;
    this.hoodContainer.addChild(graphics);
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
