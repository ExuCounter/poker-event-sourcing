import * as PIXI from "pixi.js";
import gsap from "gsap";
import { CardRenderer } from "./CardRenderer.js";
import { ChipsRenderer } from "./ChipsRenderer.js";
import {
  TABLE_WIDTH,
  TABLE_HEIGHT,
  HOLE_CARD_SPACING,
  CARD_OFFSET_X,
  HOOD_WIDTH,
  HOOD_HEIGHT,
  HOOD_BORDER_RADIUS,
  HOOD_PADDING,
  CARD_OVERLAP,
  PARTICIPANT_COLORS,
  ACTION_INDICATOR_COLORS,
  CARD_HEIGHT,
  FONTS,
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

    // Semi-transparent background overlay matching hood shape
    const overlay = new PIXI.Graphics();
    overlay.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    overlay.fill({ color: 0x000000, alpha: 0.88 });
    this.actionIndicatorContainer.addChild(overlay);

    // Action text
    const actionText = new PIXI.Text({
      text: actionType,
      style: {
        fontFamily: FONTS.mono,
        fontSize: 20,
        fontWeight: "bold",
        fill: ACTION_INDICATOR_COLORS[actionType] || 0xffffff,
        letterSpacing: 2,
      },
    });
    actionText.anchor.set(0.5, 0.5);
    actionText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT / 2);
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
    const staggerDelay = 0.08;
    const cards = [...this.holeCardsContainer.children];

    // Animate each card individually with stagger and sideways spread
    const animations = cards.map((card, index) => {
      const spreadX = (index === 0 ? -30 : 30) + (Math.random() * 20 - 10);
      const spreadY = Math.random() * 20 - 10;
      const rotation =
        Math.random() * 0.5 - 0.25 + (index === 0 ? -0.2 : 0.2);

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
    const flipDuration = timing.duration / 1000 / 2;

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
          fontWeight: "600",
          fill: PARTICIPANT_COLORS.text,
          fontFamily: FONTS.mono,
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
    const isAllIn = participant.handStatus === "all_in";

    this.hoodContainer.zIndex = 2;
    this.hoodContainer.position.set(0, CARD_OVERLAP);

    const hood = new PIXI.Graphics();

    // Main background with alpha
    hood.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    hood.fill({
      color: isFolded
        ? PARTICIPANT_COLORS.hoodBgFolded
        : PARTICIPANT_COLORS.hoodBg,
      alpha: isFolded
        ? PARTICIPANT_COLORS.hoodBgFoldedAlpha
        : PARTICIPANT_COLORS.hoodBgAlpha,
    });

    // Border — accent color when it's this player's turn
    const isActive =
      state.currentTurn?.participantId === this.participantId;
    const borderColor = isActive
      ? PARTICIPANT_COLORS.borderActive
      : isFolded
        ? PARTICIPANT_COLORS.borderFolded
        : PARTICIPANT_COLORS.border;

    hood.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    hood.stroke({ color: borderColor, width: isActive ? 1.5 : 1 });

    // Active glow
    if (isActive) {
      const glow = new PIXI.Graphics();
      glow.roundRect(-4, -4, HOOD_WIDTH + 8, HOOD_HEIGHT + 8, HOOD_BORDER_RADIUS + 4);
      glow.fill({ color: PARTICIPANT_COLORS.activeGlow, alpha: PARTICIPANT_COLORS.activeGlowAlpha });
      this.hoodContainer.addChild(glow);
    }

    this.hoodContainer.addChild(hood);

    // Position badge (top-left of hood)
    if (participant.position) {
      this.#renderPositionBadge(participant.position);
    }

    // Action label badge (top-right: FOLD, ALL-IN, SITTING OUT)
    if (isFolded || isAllIn || participant.isSittingOut) {
      this.#renderActionLabel(participant);
    }

    // Centered layout: name on top row, chips on bottom row
    const centerX = HOOD_WIDTH / 2;

    // Name text — centered, auto-shrink to fit
    const maxNameWidth = HOOD_WIDTH - HOOD_PADDING * 2;
    const nameText = new PIXI.Text({
      text: participant.nickname,
      style: {
        fontFamily: FONTS.ui,
        fontSize: 17,
        fontWeight: "600",
        fill: isFolded
          ? PARTICIPANT_COLORS.textFolded
          : PARTICIPANT_COLORS.text,
      },
    });
    // Shrink font if name overflows hood width
    if (nameText.width > maxNameWidth) {
      const scaledSize = Math.max(11, Math.floor(17 * (maxNameWidth / nameText.width)));
      nameText.style.fontSize = scaledSize;
    }
    nameText.anchor.set(0.5, 0.5);
    nameText.position.set(centerX, HOOD_HEIGHT * 0.30);
    this.hoodContainer.addChild(nameText);

    // Divider line
    const divider = new PIXI.Graphics();
    divider.moveTo(HOOD_PADDING + 4, HOOD_HEIGHT * 0.56);
    divider.lineTo(HOOD_WIDTH - HOOD_PADDING - 4, HOOD_HEIGHT * 0.56);
    divider.stroke({ color: PARTICIPANT_COLORS.divider, width: 1 });
    this.hoodContainer.addChild(divider);

    // Chips amount — centered
    const chipsDisplay = isAllIn
      ? "ALL-IN"
      : this.formatChips(participant.chips);
    const chipsText = new PIXI.Text({
      text: chipsDisplay,
      style: {
        fontFamily: FONTS.mono,
        fontSize: 20,
        fontWeight: "700",
        fill: isAllIn
          ? PARTICIPANT_COLORS.allInText
          : isFolded
            ? PARTICIPANT_COLORS.chipsFolded
            : PARTICIPANT_COLORS.chips,
      },
    });
    chipsText.anchor.set(0.5, 0.5);
    chipsText.position.set(centerX, HOOD_HEIGHT * 0.76);
    this.hoodContainer.addChild(chipsText);

    // Render equity badge if available
    this.#renderEquityBadge(participant);

    this.container.addChild(this.hoodContainer);
  }

  #renderPositionBadge(position) {
    const posText = position.toUpperCase();
    const badge = new PIXI.Container();

    const text = new PIXI.Text({
      text: posText,
      style: {
        fontFamily: FONTS.mono,
        fontSize: 13,
        fontWeight: "600",
        fill: PARTICIPANT_COLORS.positionBadgeText,
        letterSpacing: 1.5,
      },
    });

    const paddingX = 8;
    const paddingY = 4;
    const bg = new PIXI.Graphics();
    bg.roundRect(0, 0, text.width + paddingX * 2, text.height + paddingY * 2, 5);
    bg.fill(PARTICIPANT_COLORS.positionBadgeBg);
    bg.stroke({ color: PARTICIPANT_COLORS.positionBadgeBorder, width: 1 });

    text.position.set(paddingX, paddingY);

    badge.addChild(bg);
    badge.addChild(text);
    badge.position.set(10, -12);

    this.hoodContainer.addChild(badge);
  }

  #renderActionLabel(participant) {
    const isFolded = participant.handStatus === "folded";
    const isAllIn = participant.handStatus === "all_in";
    const isSittingOut = participant.isSittingOut;

    const labelText = isFolded
      ? "FOLD"
      : isAllIn
        ? "ALL-IN"
        : "SITTING OUT";

    const paddingX = 8;
    const paddingY = 4;
    const badge = new PIXI.Container();

    const labelTextObj = new PIXI.Text({
      text: labelText,
      style: {
        fontFamily: FONTS.mono,
        fontSize: 13,
        fontWeight: "600",
        fill: isAllIn ? 0x0f0f12 : PARTICIPANT_COLORS.actionLabelText,
        letterSpacing: 1.5,
      },
    });

    const bg = new PIXI.Graphics();
    bg.roundRect(0, 0, labelTextObj.width + paddingX * 2, labelTextObj.height + paddingY * 2, 5);
    bg.fill(
      isAllIn ? PARTICIPANT_COLORS.actionLabelAllIn : PARTICIPANT_COLORS.actionLabelBg,
    );
    if (!isAllIn) {
      bg.stroke({ color: PARTICIPANT_COLORS.actionLabelBorder, width: 1 });
    }

    labelTextObj.position.set(paddingX, paddingY);

    badge.addChild(bg);
    badge.addChild(labelTextObj);
    badge.position.set(HOOD_WIDTH - (labelTextObj.width + paddingX * 2) - 6, -12);

    this.hoodContainer.addChild(badge);
  }

  #renderEquityBadge(participant) {
    if (!participant.equity || participant.equity.win === undefined) return;

    const winPercent = participant.equity.win || 0;
    const tiePercent = participant.equity.tie || 0;
    const totalEquity = winPercent + tiePercent;
    const displayText = `${totalEquity.toFixed(0)}%`;

    const badgeContainer = new PIXI.Container();

    const paddingX = 7;
    const paddingY = 5;
    const fontSize = 16;
    const borderRadius = 6;

    const equityText = new PIXI.Text({
      text: displayText,
      style: {
        fontFamily: FONTS.mono,
        fontSize: fontSize,
        fontWeight: "bold",
        fill: 0xffffff,
      },
    });

    const badgeWidth = equityText.width + paddingX * 2;
    const badgeHeight = equityText.height + paddingY * 2;

    const badge = new PIXI.Graphics();
    badge.roundRect(0, 0, badgeWidth, badgeHeight, borderRadius);
    badge.fill(0x8a2f20); // Oxblood

    badgeContainer.addChild(badge);

    equityText.anchor.set(0.5, 0.5);
    equityText.position.set(badgeWidth / 2, badgeHeight / 2);
    badgeContainer.addChild(equityText);

    badgeContainer.position.set(HOOD_WIDTH - 15, -70);

    this.hoodContainer.addChild(badgeContainer);

    this.equityBadge = badgeContainer;
  }

  // Fixed seat positions for 6-max table (indexed 0-5 for visual positions)
  #getFixedSeatPositions() {
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;
    const sidePadding = 30;
    const topPadding = 20;
    const bottomPadding = -10;

    return [
      { x: 0, y: halfH + bottomPadding },
      { x: halfW + sidePadding, y: halfH * 0.4 },
      { x: halfW + sidePadding, y: -halfH * 0.4 },
      { x: 0, y: -halfH - topPadding },
      { x: -halfW - sidePadding, y: -halfH * 0.4 },
      { x: -halfW - sidePadding, y: halfH * 0.4 },
    ];
  }

  #getVisualPosition() {
    const state = this.getState();
    const participant = state.participants.find(
      (p) => p.id === this.participantId,
    );
    const currentUser = state.participants.find(
      (p) => p.playerId === state.currentUserId,
    );

    const mySeatNumber = participant?.seatNumber || 1;
    const viewerSeatNumber = currentUser?.seatNumber || 1;
    const rotationOffset = viewerSeatNumber - 1;
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

    const betInsetY = 135;
    const betInsetX = 110;
    const sideOffset = 80;
    let betX = pos.x;
    let betY = pos.y;

    if (pos.y > halfH * 0.3) {
      betY = pos.y - betInsetY;
      if (pos.x > 20) {
        betX = pos.x - sideOffset;
      } else if (pos.x < -20) {
        betX = pos.x + sideOffset;
      }
    } else if (pos.y < -halfH * 0.3) {
      betY = pos.y + betInsetY;
      if (pos.x > 20) {
        betX = pos.x - sideOffset;
      } else if (pos.x < -20) {
        betX = pos.x + sideOffset;
      }
    } else if (pos.x > halfW * 0.3) {
      betX = pos.x - betInsetX;
      betY = pos.y + (pos.y > 0 ? -40 : 40);
    } else if (pos.x < -halfW * 0.3) {
      betX = pos.x + betInsetX;
      betY = pos.y + (pos.y > 0 ? -40 : 40);
    }

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
    if (this.progressArc) {
      this.hoodContainer.removeChild(this.progressArc);
      this.progressArc = null;
    }

    const state = this.getState();
    const isActive = state.currentTurn?.participantId === this.participantId;

    if (!isActive || !state.timeoutInfo) return;

    const startedAt = new Date(state.timeoutInfo.startedAt);
    const now = new Date();
    const elapsed = (now - startedAt) / 1000;
    const remaining = Math.max(0, state.timeoutInfo.timeoutSeconds - elapsed);

    const TIMER_SHOW_THRESHOLD = 15;
    if (remaining > TIMER_SHOW_THRESHOLD || remaining <= 0) return;

    const progress = remaining / TIMER_SHOW_THRESHOLD;

    let borderColor;
    if (remaining > 10) {
      borderColor = PARTICIPANT_COLORS.timerGreen;
    } else if (remaining > 5) {
      borderColor = PARTICIPANT_COLORS.timerYellow;
    } else {
      borderColor = PARTICIPANT_COLORS.timerRed;
    }

    const graphics = new PIXI.Graphics();
    const lineWidth = 4;
    const padding = 3;
    const w = HOOD_WIDTH + padding * 2;
    const h = HOOD_HEIGHT + padding * 2;
    const r = HOOD_BORDER_RADIUS + padding;
    const left = -padding;
    const top = -padding;
    const right = left + w;
    const bottom = top + h;

    const straightH = w - 2 * r;
    const straightV = h - 2 * r;
    const cornerLen = (Math.PI / 2) * r;
    const totalPerimeter = 2 * straightH + 2 * straightV + 4 * cornerLen;
    const drawLength = totalPerimeter * progress;

    const halfTop = straightH / 2;

    const cumLengths = [
      halfTop,
      halfTop + cornerLen,
      halfTop + cornerLen + straightV,
      halfTop + 2 * cornerLen + straightV,
      halfTop + 2 * cornerLen + straightV + straightH,
      halfTop + 3 * cornerLen + straightV + straightH,
      halfTop + 3 * cornerLen + 2 * straightV + straightH,
      halfTop + 4 * cornerLen + 2 * straightV + straightH,
      totalPerimeter,
    ];

    const startX = HOOD_WIDTH / 2;
    const startY = top;
    graphics.moveTo(startX, startY);

    let prevCum = 0;

    if (drawLength > 0) {
      const segLen = Math.min(halfTop, drawLength);
      graphics.lineTo(startX + segLen, top);
    }
    prevCum = cumLengths[0];

    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(right - r, top + r, r, -Math.PI / 2, -Math.PI / 2 + angleSpan);
    }
    prevCum = cumLengths[1];

    if (drawLength > prevCum) {
      const segLen = Math.min(straightV, drawLength - prevCum);
      graphics.lineTo(right, top + r + segLen);
    }
    prevCum = cumLengths[2];

    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(right - r, bottom - r, r, 0, angleSpan);
    }
    prevCum = cumLengths[3];

    if (drawLength > prevCum) {
      const segLen = Math.min(straightH, drawLength - prevCum);
      graphics.lineTo(right - r - segLen, bottom);
    }
    prevCum = cumLengths[4];

    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(left + r, bottom - r, r, Math.PI / 2, Math.PI / 2 + angleSpan);
    }
    prevCum = cumLengths[5];

    if (drawLength > prevCum) {
      const segLen = Math.min(straightV, drawLength - prevCum);
      graphics.lineTo(left, bottom - r - segLen);
    }
    prevCum = cumLengths[6];

    if (drawLength > prevCum) {
      const segLen = Math.min(cornerLen, drawLength - prevCum);
      const angleSpan = (segLen / cornerLen) * (Math.PI / 2);
      graphics.arc(left + r, top + r, r, Math.PI, Math.PI + angleSpan);
    }
    prevCum = cumLengths[7];

    if (drawLength > prevCum) {
      const segLen = Math.min(halfTop, drawLength - prevCum);
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
          fill: PARTICIPANT_COLORS.timerRed,
          fontFamily: FONTS.mono,
        },
      });
      this.countdownText.anchor.set(0.5);
      this.countdownText.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT + 32);
      this.hoodContainer.addChild(this.countdownText);
    } else {
      this.countdownText.text = seconds.toString();
    }

    if (shouldPulse && !this.countdownPulseTween) {
      this.countdownPulseTween = gsap.to(this.countdownText.scale, {
        x: 1.3,
        y: 1.3,
        duration: 0.5,
        repeat: -1,
        yoyo: true,
        ease: "power1.inOut",
      });

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
    const audioContext = new (window.AudioContext ||
      window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);

    oscillator.frequency.value = 800;
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
    return text.substring(0, maxLength - 1) + "\u2026";
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
