import * as PIXI from "pixi.js";
import gsap from "gsap";
import { CardRenderer } from "./CardRenderer.js";
import { ChipsRenderer } from "./ChipsRenderer.js";
import {
  TABLE_WIDTH,
  TABLE_HEIGHT,
  TABLE_BORDER_RADIUS,
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
    this.renderHoleCards();
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

  renderHoleCards() {
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

    const nickname = lobbyUser?.nickname || "??";

    // Render avatar circle
    const avatarRadius = 14;
    const avatarX = HOOD_PADDING + avatarRadius;
    const avatarY = HOOD_HEIGHT / 4 + 2;
    const avatarColor = this.#getAvatarColor(nickname, isFolded);

    const avatar = new PIXI.Graphics();
    avatar.circle(avatarX, avatarY, avatarRadius);
    avatar.fill(avatarColor);

    this.hoodContainer.addChild(avatar);

    // Avatar initials (first 2 letters)
    const initials = nickname.substring(0, 2).toUpperCase();
    const initialsText = new PIXI.Text({
      text: initials,
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 12,
        fontWeight: "bold",
        fill: 0xffffff,
      },
    });
    initialsText.anchor.set(0.5, 0.5);
    initialsText.position.set(avatarX, avatarY);
    this.hoodContainer.addChild(initialsText);

    // Name text (positioned after avatar)
    const displayName = this.truncateText(nickname, 10);
    const nameText = new PIXI.Text({
      text: displayName,
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 16,
        fontWeight: "bold",
        fill: isFolded
          ? PARTICIPANT_COLORS.textFolded
          : PARTICIPANT_COLORS.text,
      },
    });

    nameText.anchor.set(0, 0.5);
    nameText.position.set(avatarX + avatarRadius + 8, avatarY);

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

  #getAvatarColor(nickname, isFolded) {
    if (isFolded) {
      return 0x555555;
    }

    // Generate a consistent hue from nickname string
    let hash = 0;
    for (let i = 0; i < nickname.length; i++) {
      hash = nickname.charCodeAt(i) + ((hash << 5) - hash);
    }

    // Convert hash to hue (0-360)
    const hue = Math.abs(hash % 360);

    // Convert HSL to RGB (saturation: 65%, lightness: 45%)
    return this.#hslToHex(hue, 65, 45);
  }

  #hslToHex(h, s, l) {
    s /= 100;
    l /= 100;

    const c = (1 - Math.abs(2 * l - 1)) * s;
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
    const m = l - c / 2;

    let r, g, b;
    if (h < 60) {
      [r, g, b] = [c, x, 0];
    } else if (h < 120) {
      [r, g, b] = [x, c, 0];
    } else if (h < 180) {
      [r, g, b] = [0, c, x];
    } else if (h < 240) {
      [r, g, b] = [0, x, c];
    } else if (h < 300) {
      [r, g, b] = [x, 0, c];
    } else {
      [r, g, b] = [c, 0, x];
    }

    const toHex = (val) => {
      const hex = Math.round((val + m) * 255).toString(16);
      return hex.length === 1 ? "0" + hex : hex;
    };

    return parseInt(toHex(r) + toHex(g) + toHex(b), 16);
  }

  // Predefined seat positions for rectangular table (relative to table center)
  // Positions are arranged: bottom center, then clockwise
  #getSeatPositions(playerCount) {
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;
    // Different padding for different sides to keep players on screen
    const sidePadding = 30; // Distance from table edge for left/right
    const topPadding = 20; // Distance for top players (closer to table)
    const bottomPadding = -10; // Distance for bottom players (even closer)

    const positions = {
      2: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: 0, y: -halfH - topPadding }, // Top center
      ],
      3: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW + sidePadding, y: 0 }, // Right
        { x: -halfW - sidePadding, y: 0 }, // Left
      ],
      4: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW + sidePadding, y: 0 }, // Right
        { x: 0, y: -halfH - topPadding }, // Top center
        { x: -halfW - sidePadding, y: 0 }, // Left
      ],
      5: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW + sidePadding, y: halfH * 0.4 }, // Bottom right
        { x: halfW + sidePadding, y: -halfH * 0.4 }, // Top right
        { x: -halfW - sidePadding, y: -halfH * 0.4 }, // Top left
        { x: -halfW - sidePadding, y: halfH * 0.4 }, // Bottom left
      ],
      6: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW + sidePadding, y: halfH * 0.4 }, // Bottom right
        { x: halfW + sidePadding, y: -halfH * 0.4 }, // Top right
        { x: 0, y: -halfH - topPadding }, // Top center
        { x: -halfW - sidePadding, y: -halfH * 0.4 }, // Top left
        { x: -halfW - sidePadding, y: halfH * 0.4 }, // Bottom left
      ],
      7: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW + sidePadding, y: halfH * 0.5 }, // Bottom right
        { x: halfW + sidePadding, y: -halfH * 0.2 }, // Right
        { x: halfW * 0.4, y: -halfH - topPadding }, // Top right
        { x: -halfW * 0.4, y: -halfH - topPadding }, // Top left
        { x: -halfW - sidePadding, y: -halfH * 0.2 }, // Left
        { x: -halfW - sidePadding, y: halfH * 0.5 }, // Bottom left
      ],
      8: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW + sidePadding, y: halfH * 0.5 }, // Bottom right
        { x: halfW + sidePadding, y: -halfH * 0.2 }, // Right
        { x: halfW * 0.4, y: -halfH - topPadding }, // Top right
        { x: -halfW * 0.4, y: -halfH - topPadding }, // Top left
        { x: -halfW - sidePadding, y: -halfH * 0.2 }, // Left
        { x: -halfW - sidePadding, y: halfH * 0.5 }, // Bottom left
        { x: halfW * 0.5, y: halfH + bottomPadding }, // Bottom right corner
      ],
      9: [
        { x: 0, y: halfH + bottomPadding }, // Bottom center
        { x: halfW * 0.6, y: halfH + bottomPadding }, // Bottom right
        { x: halfW + sidePadding, y: halfH * 0.3 }, // Right bottom
        { x: halfW + sidePadding, y: -halfH * 0.3 }, // Right top
        { x: halfW * 0.4, y: -halfH - topPadding }, // Top right
        { x: -halfW * 0.4, y: -halfH - topPadding }, // Top left
        { x: -halfW - sidePadding, y: -halfH * 0.3 }, // Left top
        { x: -halfW - sidePadding, y: halfH * 0.3 }, // Left bottom
        { x: -halfW * 0.6, y: halfH + bottomPadding }, // Bottom left
      ],
    };

    return positions[playerCount] || positions[6];
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

    const seatPositions = this.#getSeatPositions(playerCount);
    const pos = seatPositions[relativePosition] || { x: 0, y: 0 };

    return {
      x: pos.x - HOOD_WIDTH / 2,
      y: pos.y - 70,
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

    const seatPositions = this.#getSeatPositions(playerCount);
    const pos = seatPositions[relativePosition] || { x: 0, y: 0 };
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;

    // Calculate bet position - inset from player toward table center
    // But also offset to the side to avoid community cards
    const betInsetY = 130;
    const betInsetX = 100;
    const sideOffset = 80; // Horizontal offset to avoid center
    let betX = pos.x;
    let betY = pos.y;

    // Move bet chips toward center but offset to the side
    if (pos.y > halfH * 0.3) {
      // Bottom players: bet above them, offset based on x position
      betY = pos.y - betInsetY;
      if (pos.x > 20) {
        betX = pos.x - sideOffset; // Right side: offset left
      } else if (pos.x < -20) {
        betX = pos.x + sideOffset; // Left side: offset right
      }
      // Center bottom player keeps x position
    } else if (pos.y < -halfH * 0.3) {
      // Top players: bet below them, offset based on x position
      betY = pos.y + betInsetY;
      if (pos.x > 20) {
        betX = pos.x - sideOffset; // Right side: offset left
      } else if (pos.x < -20) {
        betX = pos.x + sideOffset; // Left side: offset right
      }
      // Center top player keeps x position
    } else if (pos.x > halfW * 0.3) {
      // Right players: bet to their left
      betX = pos.x - betInsetX;
      betY = pos.y + (p3s.y > 0 ? -40 : 40); // Slight vertical offset away from center
    } else if (pos.x < -halfW * 0.3) {
      // Left players: bet to their right
      betX = pos.x + betInsetX;
      betY = pos.y + (pos.y > 0 ? -40 : 40); // Slight vertical offset away from center
    }

    // Player position for relative offset
    const playerX = pos.x;
    const playerY = pos.y;

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
