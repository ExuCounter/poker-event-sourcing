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
  constructor(participantId, tableContainer, getState) {
    this.participantId = participantId;
    this.getState = getState;
    this.tableContainer = tableContainer;

    this.container = new PIXI.Container();
    this.container.sortableChildren = true;

    // Separate container for action indicator (not cleared on render)
    this.actionIndicatorOverlay = new PIXI.Container();
    this.actionIndicatorOverlay.sortableChildren = true;
    this.actionIndicatorOverlay.zIndex = 100; // Always on top

    this.holeCardsContainer = new PIXI.Container();

    this.hoodContainer = new PIXI.Container();

    this.betAreaContainer = new PIXI.Container();

    this.equityBadgeContainer = new PIXI.Graphics();

    this.tableContainer.addChild(this.container);
    this.container.addChild(this.actionIndicatorOverlay);

    // Timeout progress properties
    this.progressArc = null;
    this.countdownText = null;
    this.alertSoundPlayed = false;
    this.countdownPulseTween = null;
    this.arcPulseTween = null;

    // Hood text elements for partial updates
    this.balanceText = null;

    // Action indicator properties
    this.actionIndicatorContainer = null;
    this.actionIndicatorTween = null;
  }

  // Action indicator colors
  static ACTION_COLORS = {
    RAISE: 0xfbbf24,
    CALL: 0x4ade80,
    CHECK: 0x60a5fa,
    FOLD: 0xef4444,
    "ALL IN": 0xf97316,
  };

  async showActionIndicator(actionType) {
    // Kill existing tween if running
    if (this.actionIndicatorTween) {
      this.actionIndicatorTween.kill();
      this.actionIndicatorTween = null;
    }

    // Remove old action indicator if exists
    if (this.actionIndicatorContainer) {
      if (
        this.actionIndicatorOverlay.children.includes(
          this.actionIndicatorContainer,
        )
      ) {
        this.actionIndicatorOverlay.removeChild(this.actionIndicatorContainer);
      }
      this.actionIndicatorContainer = null;
    }

    // Create action indicator container
    this.actionIndicatorContainer = new PIXI.Container();
    this.actionIndicatorContainer.zIndex = 10;

    // Position over hood (hood is at y = CARD_OVERLAP)
    this.actionIndicatorContainer.position.set(0, CARD_OVERLAP);

    // Semi-transparent background overlay covering upper half of hood
    const overlay = new PIXI.Graphics();
    overlay.roundRect(
      2,
      2,
      HOOD_WIDTH - 4,
      HOOD_HEIGHT / 2 - 4,
      HOOD_BORDER_RADIUS - 2,
    );
    overlay.fill({ color: 0x000000, alpha: 0.85 });
    this.actionIndicatorContainer.addChild(overlay);

    // Action text
    const actionText = new PIXI.Text({
      text: actionType,
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 22,
        fontWeight: "bold",
        fill: ParticipantRenderer.ACTION_COLORS[actionType] || 0xffffff,
      },
    });
    actionText.anchor.set(0.5, 0.5);
    actionText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT / 4);
    this.actionIndicatorContainer.addChild(actionText);

    this.actionIndicatorContainer.alpha = 0;
    this.actionIndicatorOverlay.addChild(this.actionIndicatorContainer);

    // Animate: fade in, stay, fade out
    return new Promise((resolve) => {
      this.actionIndicatorTween = gsap.timeline({
        onComplete: () => {
          if (
            this.actionIndicatorContainer &&
            this.actionIndicatorOverlay.children.includes(
              this.actionIndicatorContainer,
            )
          ) {
            this.actionIndicatorOverlay.removeChild(
              this.actionIndicatorContainer,
            );
          }
          this.actionIndicatorContainer = null;
          this.actionIndicatorTween = null;
          resolve();
        },
      });

      this.actionIndicatorTween
        .to(this.actionIndicatorContainer, { alpha: 1, duration: 0.15 })
        .to(this.actionIndicatorContainer, { alpha: 1, duration: 1.0 })
        .to(this.actionIndicatorContainer, { alpha: 0, duration: 0.3 });
    });
  }

  async animateFold(tableContainer, timing) {
    // If no cards to animate, skip
    if (this.holeCardsContainer.children.length === 0) {
      return;
    }

    // Get table center position in local coordinates
    const tableCenterGlobal = tableContainer.getGlobalPosition();
    const tableCenterLocal = this.container.toLocal(tableCenterGlobal);

    // Raise zIndex so cards animate above other elements
    const originalZIndex = this.container.zIndex;
    this.container.zIndex = 60;

    const duration = timing.duration / 1000;
    const staggerDelay = 0.08; // Delay between each card
    const cards = [...this.holeCardsContainer.children];

    // Animate each card individually with stagger and sideways spread
    const animations = cards.map((card, index) => {
      // Add sideways spread - first card goes slightly left, second slightly right
      const spreadX = (index === 0 ? -30 : 30) + (Math.random() * 20 - 10);
      const spreadY = Math.random() * 20 - 10;

      // Random rotation for natural throw effect
      const rotation = Math.random() * 0.5 - 0.25 + (index === 0 ? -0.2 : 0.2);

      // Target position (relative to holeCardsContainer)
      const targetX = tableCenterLocal.x - HOOD_WIDTH / 2 + spreadX - card.x;
      const targetY = tableCenterLocal.y - CARD_HEIGHT / 2 + spreadY - card.y;

      return gsap.to(card, {
        x: card.x + targetX,
        y: card.y + targetY,
        alpha: 0,
        rotation: rotation,
        duration: duration,
        delay: index * staggerDelay,
        ease: "power2.in",
      });
    });

    await Promise.all(animations);

    // Restore zIndex and clear cards
    this.container.zIndex = originalZIndex;
    this.holeCardsContainer.removeChildren();
    this.holeCardsContainer.alpha = 1;
    this.holeCardsContainer.position.set(0, 0);
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

    // Re-add action indicator overlay (it persists across renders)
    this.container.addChild(this.actionIndicatorOverlay);
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
          fontSize: 20,
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

    const nickname = participant.nickname;

    // Render avatar circle
    const avatarRadius = 16;
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
        fontSize: 13,
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
        fontSize: 18,
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
        fontSize: 20,
        fontWeight: "bold",
        fill: isFolded
          ? PARTICIPANT_COLORS.chipsFolded
          : PARTICIPANT_COLORS.chips,
      },
    });

    chipsText.anchor.set(0.5, 0.5);
    chipsText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT - HOOD_PADDING - 6);

    this.hoodContainer.addChild(chipsText);

    // Render equity badge if available
    this.#renderEquityBadge(participant);

    this.container.addChild(this.hoodContainer);
  }

  #renderEquityBadge(participant) {
    // Only show if equity data exists and has valid values
    if (!participant.equity || participant.equity.win === undefined) return;

    const winPercent = participant.equity.win || 0;
    const tiePercent = participant.equity.tie || 0;

    // Show combined equity (win + tie share)
    const totalEquity = winPercent + tiePercent;
    const displayText = `${totalEquity.toFixed(0)}%`;

    // Create badge container
    const badgeContainer = new PIXI.Container();

    // Badge dimensions
    const paddingX = 7;
    const paddingY = 5;
    const fontSize = 16;
    const borderRadius = 6;

    // Create text first to measure
    const equityText = new PIXI.Text({
      text: displayText,
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: fontSize,
        fontWeight: "bold",
        fill: 0xffffff,
      },
    });

    const badgeWidth = equityText.width + paddingX * 2;
    const badgeHeight = equityText.height + paddingY * 2;

    // Red-cherry background
    const badge = new PIXI.Graphics();
    badge.roundRect(0, 0, badgeWidth, badgeHeight, borderRadius);
    badge.fill(0xdc2626); // Red-cherry color

    badgeContainer.addChild(badge);

    // Center text in badge
    equityText.anchor.set(0.5, 0.5);
    equityText.position.set(badgeWidth / 2, badgeHeight / 2);
    badgeContainer.addChild(equityText);

    // Position: top-right of hood, close to where right card would be
    // Hood is at y = CARD_OVERLAP, cards are above it
    // Position badge above the hood, to the right side
    badgeContainer.position.set(
      HOOD_WIDTH - 15, // Right side with small margin
      -70, // Above the hood (negative Y since hood is at CARD_OVERLAP)
    );

    this.hoodContainer.addChild(badgeContainer);

    this.equityBadge = badgeContainer;
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

  // Fixed seat positions for 6-max table (indexed 0-5 for visual positions)
  // Position 0 is always at bottom center, then clockwise
  #getFixedSeatPositions() {
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;
    const sidePadding = 30;
    const topPadding = 20;
    const bottomPadding = -10;

    return [
      { x: 0, y: halfH + bottomPadding }, // Visual 0: Bottom center
      { x: halfW + sidePadding, y: halfH * 0.4 }, // Visual 1: Bottom right
      { x: halfW + sidePadding, y: -halfH * 0.4 }, // Visual 2: Top right
      { x: 0, y: -halfH - topPadding }, // Visual 3: Top center
      { x: -halfW - sidePadding, y: -halfH * 0.4 }, // Visual 4: Top left
      { x: -halfW - sidePadding, y: halfH * 0.4 }, // Visual 5: Bottom left
    ];
  }

  // Calculate visual position with rotation so current user is at bottom
  #getVisualPosition() {
    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );
    const currentUser = state.participants.find(
      (p) => p.playerId === state.currentUserId,
    );

    // Get physical seat numbers (1-6)
    const mySeatNumber = participant?.seatNumber || 1;
    const viewerSeatNumber = currentUser?.seatNumber || 1;

    // Calculate rotation offset so viewer's seat appears at visual position 0 (bottom)
    const rotationOffset = viewerSeatNumber - 1;

    // Apply rotation: shift seat numbers so current user is at visual position 0
    // Seat numbers are 1-6, visual positions are 0-5
    const visualPosition = (mySeatNumber - 1 - rotationOffset + 6) % 6;

    return visualPosition;
  }

  #getPlayerPosition() {
    const visualPosition = this.#getVisualPosition();
    const seatPositions = this.#getFixedSeatPositions();
    const pos = seatPositions[visualPosition] || { x: 0, y: 0 };

    return {
      x: pos.x - HOOD_WIDTH / 2,
      y: pos.y - 70,
    };
  }

  #getBetPosition() {
    const visualPosition = this.#getVisualPosition();
    const seatPositions = this.#getFixedSeatPositions();
    const pos = seatPositions[visualPosition] || { x: 0, y: 0 };
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;

    // Calculate bet position - inset from player toward table center
    // But also offset to the side to avoid community cards
    const betInsetY = 135;
    const betInsetX = 110;
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
      betY = pos.y + (pos.y > 0 ? -40 : 40); // Slight vertical offset away from center
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
          fontSize: 27,
          fontWeight: "bold",
          fill: 0xff0000,
        },
      });
      this.countdownText.anchor.set(0.5);
      this.countdownText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT + 32);
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

  clearEquityBadge() {
    this.equityBadgeContainer.clear();
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
