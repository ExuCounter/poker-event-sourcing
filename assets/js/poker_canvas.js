import * as PIXI from "pixi.js";
import gsap from "gsap";
import { Howl } from "howler";
import { ParticipantRenderer } from "./renderers/ParticipantRenderer.js";
import { CommunityCardsRenderer } from "./renderers/CommunityCardsRenderer.js";
import { TotalPotRenderer } from "./renderers/TotalPotRenderer.js";
import { ChipsRenderer } from "./renderers/ChipsRenderer.js";
import { TableInfoRenderer } from "./renderers/TableInfoRenderer.js";
import { DealerButtonRenderer } from "./renderers/DealerButtonRenderer.js";
import { EmptySeatRenderer } from "./renderers/EmptySeatRenderer.js";
import {
  BASE_WIDTH,
  BASE_HEIGHT,
  TABLE_RADIUS_X,
  TABLE_RADIUS_Y,
  TABLE_WIDTH,
  TABLE_HEIGHT,
  TABLE_BORDER_RADIUS,
  TABLE_COLORS,
} from "./constants.js";

export const PokerCanvas = {
  async mounted() {
    const serverState = JSON.parse(this.el.dataset.state);
    const currentUserId = this.el.dataset.currentUserId;
    const mode = this.el.dataset.mode || "live";

    this.app = new PIXI.Application();

    this.containers = {};
    this.state = serverState;
    this.currentUserId = currentUserId;
    this.isReplayMode = mode === "replay";
    this.timeoutAnimationFrame = null;

    await this.app.init({
      canvas: this.el,
      backgroundColor: TABLE_COLORS.roomBg,
      resizeTo: window,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
      antialias: true,
    });

    console.log(this.state);

    this.renderers = {
      communityCards: null,
      totalPot: null,
      tableInfo: null,
      participants: new Map(),
      emptySeats: new Map(), // Seat number (1-6) -> EmptySeatRenderer
    };

    this.handleEvent(
      "table_event",
      async ({ event: event, new_state: serverState }) => {
        this.state = serverState;

        console.log(event);
        console.log(serverState);

        await this.runAnimation(event);

        if (!this.isReplayMode) {
          this.pushEvent("event_processed", {
            streamVersion: event.streamVersion || event.stream_version,
          });
        }
      },
    );

    this.handleEvent("rebuild_state", async ({ state }) => {
      this.state = state;
      await this.rebuildCanvas();
    });

    this.loadSounds();
    await this.createTable();
    this.renderCommunityCards();

    window.addEventListener("resize", () => this.resize());

    this.resize();

    // Start timeout animation if there's an active turn on page load
    if (this.state.currentTurn && this.state.timeoutInfo) {
      this.startTimeoutAnimation();
    }
  },

  loadSounds() {
    this.sounds = {
      raise: new Howl({ src: ["/sounds/raise.mp3"], volume: 0.5 }),
    };
  },

  async runAnimation(event) {
    console.log(event);
    // Skip animation when backend signals instant jump (queue >= 20 events)
    if (event.skipAnimation) {
      return;
    }

    const timing = event.timing;

    switch (event.type) {
      case "ParticipantJoined": {
        // Create renderer for new participant (event.id is the participant ID)
        const participantRenderer = new ParticipantRenderer(
          event.id,
          this.containers.tableContainer,
          () => ({ ...this.state, currentUserId: this.currentUserId }),
        );
        this.renderers.participants.set(event.id, participantRenderer);
        participantRenderer.render();
        // Re-render empty seats (the joined seat is now occupied)
        this.renderEmptySeats();
        break;
      }
      case "ParticipantRaised":
        this.stopTimeoutAnimation();
        this.sounds.raise.play();
        this.showActionIndicator(event.participantId, "RAISE");
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "RoundStarted":
        await this.wait(timing.duration);
        await this.animateCommunityCardsAppear(event, timing);

        this.state.participants.forEach((p) => {
          const renderer = this.renderers.participants.get(p.id);
          renderer?.render();
        });

        break;
      case "ParticipantHandGiven":
        await this.animateParticipantHandGiven(event, timing);
        // Update dealer button after hand is given (positions are now assigned)
        this.renderers.dealerButton?.render();
        break;
      case "ParticipantFolded":
        this.stopTimeoutAnimation();
        this.showActionIndicator(event.participantId, "FOLD");
        await this.animateFoldCards(event, timing);
        await this.wait(timing.duration / 3);
        this.rerenderParticipant(event.participantId);
        break;
      case "ParticipantCalled":
        this.stopTimeoutAnimation();
        this.showActionIndicator(event.participantId, "CALL");
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "SmallBlindPosted":
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "BigBlindPosted":
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "ParticipantWentAllIn":
        this.stopTimeoutAnimation();
        this.showActionIndicator(event.participantId, "ALL IN");
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "PayoutDistributed":
        await this.wait(timing.duration);
        await this.animateBetChipsCollectToPlayer(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "ParticipantShowdownCardsRevealed":
        await this.showdownParticipantCards(event, timing);
        // Re-render all participants to show equity badges
        this.state.participants.forEach((p) => {
          this.rerenderParticipant(p.id);
        });
        break;
      case "HandFinished":
        this.stopTimeoutAnimation();
        if (event.finishReason !== "all_folded") {
          await this.wait(timing.duration);
        }
        await this.handleHandFinish(event, timing);
        break;
      case "PotsRecalculated":
        await this.animateBetChipsCollectToPot(event, timing);
        break;
      case "ParticipantToActSelected":
        this.startTimeoutAnimation();
        break;
      case "ParticipantChecked":
        this.stopTimeoutAnimation();
        this.showActionIndicator(event.participantId, "CHECK");
        break;
      case "ParticipantSatOut":
        this.rerenderParticipant(event.participantId);
        this.showActionIndicator(event.participantId, "AWAY");
        break;
      case "ParticipantSatIn":
        this.rerenderParticipant(event.participantId);
        this.showActionIndicator(event.participantId, "I'M BACK");
        break;
      case "ParticipantLeft": {
        const renderer = this.renderers.participants.get(event.participantId);
        if (renderer) {
          this.containers.tableContainer.removeChild(renderer.getContainer());
          this.renderers.participants.delete(event.participantId);
        }
        // Re-render remaining participants as positions may have shifted
        this.state.participants.forEach((p) => {
          this.rerenderParticipant(p.id);
        });
        // Re-render empty seats (the left seat is now available)
        this.renderEmptySeats();
        break;
      }
      case "TableStarted":
      case "TablePaused":
      case "TableResumed":
      case "TableFinished":
        this.renderers.tableInfo.render();
        break;
      default:
        return;
    }
  },

  async showdownParticipantCards(event, timing) {
    const renderer = this.renderers.participants.get(event.participantId);
    const currentParticipant = this.state.participants.find(
      (p) => p.playerId === this.currentUserId,
    );

    if (currentParticipant.id !== event.participantId) {
      await renderer.flipHoleCards(event.holeCards, timing);
    }
  },

  showActionIndicator(participantId, actionType) {
    const renderer = this.renderers.participants.get(participantId);
    if (renderer) {
      renderer.showActionIndicator(actionType);
    }
  },

  async animateFoldCards(event, timing) {
    const renderer = this.renderers.participants.get(event.participantId);
    if (renderer) {
      await renderer.animateFold(this.containers.tableContainer, timing);
    }
  },

  async rerenderParticipant(participantId) {
    const renderer = this.renderers.participants.get(participantId);
    renderer.render();
  },

  async animateBetChipsCollectToPlayer(event, timing) {
    const timeline = gsap.timeline();
    const participantId = event.participantId;
    const participantRenderer = this.renderers.participants.get(participantId);

    const globalTarget =
      participantRenderer.betAreaContainer.getGlobalPosition();
    const localTarget = this.renderers.totalPot
      .getContainer()
      .toLocal(globalTarget);

    this.renderers.totalPot.render(this.state.totalPot);

    const payoutChipsContainer = new PIXI.Container();
    payoutChipsContainer.zIndex = 10; // Above community cards during animation

    const payoutText = new PIXI.Text({
      text: `$${event.amount}`,
      style: { fontSize: 18, fill: 0xffd700, fontWeight: "bold" },
      anchor: 0.5,
    });
    payoutText.position.set(0, 40);

    const chipsRenderer = new ChipsRenderer();
    const chipsContainer = chipsRenderer.render(event.amount);

    payoutChipsContainer.addChild(payoutText);
    payoutChipsContainer.addChild(chipsContainer);

    this.renderers.totalPot.getContainer().addChild(payoutChipsContainer);
    payoutChipsContainer.position.set(0, 0);

    timeline.to(payoutChipsContainer, {
      x: localTarget.x,
      y: localTarget.y,
      duration: timing.duration / 1000,
      ease: "power2.out",
    });

    await timeline.then();
  },

  async animateBetChipsCollectToPot(event, timing) {
    const timeline = gsap.timeline();
    const originalPositions = new Map();

    const animations = this.renderers.participants
      .values()
      .map((participantRenderer) => {
        originalPositions.set(participantRenderer, {
          x: participantRenderer.betAreaContainer.x,
          y: participantRenderer.betAreaContainer.y,
          zIndex: participantRenderer.betAreaContainer.zIndex,
          containerZIndex: participantRenderer.container.zIndex,
        });

        // Raise zIndex during animation to appear above community cards
        participantRenderer.betAreaContainer.zIndex = 10;
        participantRenderer.container.zIndex = 50;

        const globalTarget = this.renderers.totalPot
          .getContainer()
          .getGlobalPosition();

        const localTarget = participantRenderer.container.toLocal(globalTarget);

        participantRenderer.hideBetAreaChipsText();

        // Return the tween promise without awaiting
        return timeline.to(
          participantRenderer.betAreaContainer,
          {
            x: localTarget.x,
            y: localTarget.y,
            duration: timing.duration / 1000,
            ease: "power2.out",
          },
          "<",
        );
      });

    // Wait for all animations to complete simultaneously
    await Promise.all(animations);

    this.renderers.participants.values().forEach((participantRenderer) => {
      participantRenderer.showBetAreaChipsText();
    });

    const pots = event.pots || [];
    const totalPotAmount = pots.reduce((sum, pot) => sum + pot.amount, 0);

    this.renderers.totalPot.render(totalPotAmount);

    this.renderers.participants.values().forEach((participantRenderer) => {
      participantRenderer.betAreaContainer.removeChildren();
      const orig = originalPositions.get(participantRenderer);
      participantRenderer.betAreaContainer.x = orig.x;
      participantRenderer.betAreaContainer.y = orig.y;
      participantRenderer.betAreaContainer.zIndex = orig.zIndex || 5;
      participantRenderer.container.zIndex = orig.containerZIndex || 0;
    });
  },

  async handleHandFinish() {
    this.renderers.communityCards.clear();
    this.renderers.totalPot.clear();
    this.state.participants.forEach((p) => {
      const renderer = this.renderers.participants.get(p.id);
      renderer.clearHoleCards();
      renderer.clearEquityBadge();
    });
  },

  async animateParticipantHandGiven(event, timing) {
    const participantId = event.participantId || event.participant_id;

    const renderer = this.renderers.participants.get(participantId);

    await renderer.animateHandGiven(this.containers.tableContainer, timing);
  },

  async animateCommunityCardsAppear(event, timing) {
    const communityCards = event.communityCards;
    await this.renderers.communityCards.animateNewCards(communityCards, timing);
  },

  async animateBetChipsUpdated(event, timing) {
    const participantId = event.participantId;
    const renderer = this.renderers.participants.get(participantId);

    renderer.render();
  },

  renderHoleCards() {
    for (const [_participantId, participantRenderer] of Object.entries(
      this.renderers.participants,
    )) {
      participantRenderer.render();
    }
  },

  renderCommunityCards() {
    this.renderers.communityCards.render(this.state.communityCards);
  },

  drawDiamondPattern(graphics, x, y, width, height, size, color, alpha) {
    const spacingX = size * 2.4;
    const spacingY = size * 2.4;

    for (let row = 0; row * spacingY < height; row++) {
      const offsetX = row % 2 === 0 ? 0 : spacingX / 2;
      for (let col = 0; col * spacingX < width; col++) {
        const cx = x + col * spacingX + offsetX;
        const cy = y + row * spacingY;
        if (cx > x + width || cy > y + height) continue;

        graphics
          .moveTo(cx, cy - size)
          .lineTo(cx + size * 0.6, cy)
          .lineTo(cx, cy + size)
          .lineTo(cx - size * 0.6, cy)
          .closePath();
        graphics.fill({ color, alpha });
      }
    }
  },

  createRoomBackground() {
    const bg = new PIXI.Graphics();
    const margin = 800;
    const x = -BASE_WIDTH / 2 - margin;
    const y = -BASE_HEIGHT / 2 - margin;
    const w = BASE_WIDTH + margin * 2;
    const h = BASE_HEIGHT + margin * 2;

    // Warm near-black background (Cellar)
    bg.rect(x, y, w, h);
    bg.fill(TABLE_COLORS.roomBg);

    // Subtle diamond pattern in warm tones
    this.drawDiamondPattern(bg, x + 1.5, y + 2, w, h, 18, TABLE_COLORS.roomPatternShadow, 0.5);
    this.drawDiamondPattern(bg, x, y, w, h, 18, TABLE_COLORS.roomPatternMain, 0.8);

    return bg;
  },

  async createTable() {
    // Main container - this gets scaled and centered
    this.containers.container = new PIXI.Container();

    // Table container at center of base dimensions (0,0 since parent is centered)
    this.containers.tableContainer = new PIXI.Container();
    this.containers.tableContainer.position.set(0, 0);
    this.containers.tableContainer.sortableChildren = true;

    // Room background with diamond pattern
    const roomBg = this.createRoomBackground();
    roomBg.zIndex = -10;
    this.containers.tableContainer.addChild(roomBg);

    // Create table — elliptical felt with Cellar styling
    const tableGraphics = new PIXI.Graphics();
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;

    // Outer shadow/glow
    tableGraphics.roundRect(
      -halfW - 15,
      -halfH - 11,
      TABLE_WIDTH + 30,
      TABLE_HEIGHT + 30,
      TABLE_BORDER_RADIUS + 10,
    );
    tableGraphics.fill({ color: 0x000000, alpha: 0.3 });

    // Outer rim — dark oxblood
    tableGraphics.roundRect(
      -halfW,
      -halfH,
      TABLE_WIDTH,
      TABLE_HEIGHT,
      TABLE_BORDER_RADIUS,
    );
    tableGraphics.fill(TABLE_COLORS.outerRim);

    // Inner felt — forest green with glow
    tableGraphics.roundRect(
      -halfW + 16,
      -halfH + 12,
      TABLE_WIDTH - 32,
      TABLE_HEIGHT - 24,
      TABLE_BORDER_RADIUS - 16,
    );
    tableGraphics.fill(TABLE_COLORS.felt);

    // Felt center glow highlight
    tableGraphics.roundRect(
      -halfW + 40,
      -halfH + 30,
      TABLE_WIDTH - 80,
      TABLE_HEIGHT - 60,
      TABLE_BORDER_RADIUS - 40,
    );
    tableGraphics.fill({ color: TABLE_COLORS.feltGlow, alpha: 0.4 });

    this.containers.tableContainer.addChild(tableGraphics);

    // Table rail border
    const railGraphics = new PIXI.Graphics();
    railGraphics.roundRect(
      -halfW,
      -halfH,
      TABLE_WIDTH,
      TABLE_HEIGHT,
      TABLE_BORDER_RADIUS,
    );
    railGraphics.stroke({ width: 10, color: TABLE_COLORS.outerRimBottom });

    // Inner accent line — brass
    railGraphics.roundRect(
      -halfW + 14,
      -halfH + 10,
      TABLE_WIDTH - 28,
      TABLE_HEIGHT - 20,
      TABLE_BORDER_RADIUS - 14,
    );
    railGraphics.stroke({
      width: 1,
      color: TABLE_COLORS.innerAccent,
      alpha: TABLE_COLORS.innerAccentAlpha,
    });

    this.containers.tableContainer.addChild(railGraphics);

    // Initialize TableInfoRenderer
    this.renderers.tableInfo = new TableInfoRenderer(() => this.state);

    this.containers.tableContainer.addChild(
      this.renderers.tableInfo.getContainer(),
    );

    this.renderers.tableInfo.render();

    // Initialize TotalPotRenderer
    this.renderers.totalPot = new TotalPotRenderer(() => this.state);

    this.containers.tableContainer.addChild(
      this.renderers.totalPot.getContainer(),
    );
    this.renderers.totalPot.render(this.state.totalPot);

    this.renderers.totalPot.getContainer().y += 50;
    this.renderers.totalPot.getContainer().zIndex = 5;

    // Initialize CommunityCardsRenderer
    this.renderers.communityCards = new CommunityCardsRenderer(
      () => this.state,
    );

    this.containers.tableContainer.addChild(
      this.renderers.communityCards.getContainer(),
    );

    this.containers.container.addChild(this.containers.tableContainer);
    this.app.stage.addChild(this.containers.container);

    this.state.participants.forEach((participant) => {
      const participantRenderer = new ParticipantRenderer(
        participant.id,
        this.containers.tableContainer,
        () => ({ ...this.state, currentUserId: this.currentUserId }),
      );

      this.renderers.participants.set(participant.id, participantRenderer);

      participantRenderer.render();
    });

    // Initialize DealerButtonRenderer
    this.renderers.dealerButton = new DealerButtonRenderer(
      () => this.state,
      (participantId) => {
        const renderer = this.renderers.participants.get(participantId);
        if (renderer) {
          return {
            x: renderer.container.x,
            y: renderer.container.y,
          };
        }
        return { x: 0, y: 0 };
      },
    );

    this.containers.tableContainer.addChild(
      this.renderers.dealerButton.getContainer(),
    );
    this.renderers.dealerButton.getContainer().zIndex = 100; // Always on top
    this.renderers.dealerButton.render();

    // Create empty seat renderers for all 6 seats
    this.createEmptySeats();
  },

  createEmptySeats() {
    // Clear existing empty seat renderers
    this.renderers.emptySeats.forEach((renderer) => renderer.destroy());
    this.renderers.emptySeats.clear();

    // Create empty seat renderer for each seat (1-6)
    for (let seatNumber = 1; seatNumber <= 6; seatNumber++) {
      const emptySeatRenderer = new EmptySeatRenderer(
        seatNumber,
        this.containers.tableContainer,
        () => ({ ...this.state, currentUserId: this.currentUserId }),
        (clickedSeatNumber) => this.handleSeatClick(clickedSeatNumber),
      );

      this.renderers.emptySeats.set(seatNumber, emptySeatRenderer);
      emptySeatRenderer.render();
    }
  },

  handleSeatClick(seatNumber) {
    // Push event to LiveView to join at this seat
    this.pushEvent("join_at_seat", { seat_number: seatNumber });
  },

  renderEmptySeats() {
    this.renderers.emptySeats.forEach((renderer) => renderer.render());
  },

  async rebuildCanvas() {
    // Stop any in-flight animations
    this.stopTimeoutAnimation();
    gsap.killTweensOf("*");

    // Clear all renderers
    this.renderers.emptySeats.forEach((renderer) => renderer.destroy());
    this.renderers.emptySeats.clear();
    this.renderers.participants.clear();
    this.renderers.communityCards = null;
    this.renderers.totalPot = null;
    this.renderers.tableInfo = null;
    this.renderers.dealerButton = null;

    // Rebuild from scratch
    this.clear();
    await this.createTable();
    this.renderCommunityCards();
    this.resize();

    // Restart timeout animation if needed
    if (this.state.currentTurn && this.state.timeoutInfo) {
      this.startTimeoutAnimation();
    }
  },

  startTimeoutAnimation() {
    if (this.timeoutAnimationFrame) {
      cancelAnimationFrame(this.timeoutAnimationFrame);
    }

    const animate = () => {
      if (this.state?.timeoutInfo) {
        // Find the active participant
        const activeParticipant = this.state.participants.find(
          (p) => p.id === this.state.currentTurn?.participantId,
        );

        if (activeParticipant) {
          const renderer = this.renderers.participants.get(
            activeParticipant.id,
          );
          renderer?.renderTimeoutProgress();
        }

        this.timeoutAnimationFrame = requestAnimationFrame(animate);
      }
    };

    animate();
  },

  stopTimeoutAnimation() {
    if (this.timeoutAnimationFrame) {
      cancelAnimationFrame(this.timeoutAnimationFrame);
      this.timeoutAnimationFrame = null;
    }
  },

  wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  },

  resize() {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const resolution = window.devicePixelRatio || 1;

    this.app.renderer.resolution = resolution;
    this.app.renderer.resize(width, height);

    const scaleX = width / BASE_WIDTH;
    const scaleY = height / BASE_HEIGHT;
    const fitScale = Math.min(scaleX, scaleY);

    // Boost scale by 1.3x but cap it so table never overflows viewport
    // Also cap at 1.3 to prevent table from growing at low browser zoom (25%, 50%, 70%)
    const maxScale =
      Math.min(width / TABLE_WIDTH, height / TABLE_HEIGHT) * 0.75;
    const scale = Math.min(fitScale * 1.3, maxScale);

    this.containers.container.scale.set(scale);
    this.containers.container.x = width / 2;
    this.containers.container.y = height / 2;

    document.documentElement.style.setProperty("--ui-scale", scale * 1.4);
  },

  clear() {
    this.containers.container.removeChildren();
  },
};
