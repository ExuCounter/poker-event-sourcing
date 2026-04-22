import * as PIXI from "pixi.js";
import gsap from "gsap";
import { Howl } from "howler";
import { ParticipantRenderer } from "./renderers/ParticipantRenderer.js";
import { CommunityCardsRenderer } from "./renderers/CommunityCardsRenderer.js";
import { TotalPotRenderer } from "./renderers/TotalPotRenderer.js";
import { ChipsRenderer } from "./renderers/ChipsRenderer.js";
import { TableInfoRenderer } from "./renderers/TableInfoRenderer.js";
import { DealerButtonRenderer } from "./renderers/DealerButtonRenderer.js";
import {
  BASE_WIDTH,
  BASE_HEIGHT,
  TABLE_RADIUS_X,
  TABLE_RADIUS_Y,
  TABLE_WIDTH,
  TABLE_HEIGHT,
  TABLE_BORDER_RADIUS,
} from "./constants.js";

export const PokerCanvas = {
  async mounted() {
    const serverState = JSON.parse(this.el.dataset.state);
    const lobbyState = JSON.parse(this.el.dataset.lobby);
    const currentUserId = this.el.dataset.currentUserId;
    const mode = this.el.dataset.mode || "live";

    this.app = new PIXI.Application();

    this.containers = {};
    this.state = serverState;
    this.lobbyState = lobbyState;
    this.currentUserId = currentUserId;
    this.isReplayMode = mode === "replay";
    this.timeoutAnimationFrame = null;

    await this.app.init({
      canvas: this.el,
      backgroundColor: 0x1a3d2e, // Darker green for contrast
      resizeTo: window,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
      antialias: true,
    });

    this.renderers = {
      communityCards: null,
      totalPot: null,
      tableInfo: null,
      participants: new Map(),
    };

    this.handleEvent(
      "table_event",
      async ({ event: event, new_state: serverState }) => {
        this.state = serverState;

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
          renderer.render();
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

  async createTable() {
    // Main container - this gets scaled and centered
    this.containers.container = new PIXI.Container();

    // Table container at center of base dimensions (0,0 since parent is centered)
    this.containers.tableContainer = new PIXI.Container();
    this.containers.tableContainer.position.set(0, 0);
    this.containers.tableContainer.sortableChildren = true;

    // Create table with fixed dimensions (rounded rectangle like poker room)
    const tableGraphics = new PIXI.Graphics();
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;

    // Outer glow/shadow effect
    tableGraphics.roundRect(
      -halfW - 15,
      -halfH - 11,
      TABLE_WIDTH + 30,
      TABLE_HEIGHT + 30,
      TABLE_BORDER_RADIUS + 10,
    );
    tableGraphics.fill({ color: 0x000000, alpha: 0.03 });

    // Main table felt
    tableGraphics.roundRect(
      -halfW,
      -halfH,
      TABLE_WIDTH,
      TABLE_HEIGHT,
      TABLE_BORDER_RADIUS,
    );
    tableGraphics.fill(0x35654d);

    // Inner felt highlight
    tableGraphics.roundRect(
      -halfW + 20,
      -halfH + 10,
      TABLE_WIDTH - 40,
      TABLE_HEIGHT - 30,
      TABLE_BORDER_RADIUS - 20,
    );
    tableGraphics.fill(0x3d7359);

    // Table rail (border)
    tableGraphics.roundRect(
      -halfW,
      -halfH,
      TABLE_WIDTH,
      TABLE_HEIGHT,
      TABLE_BORDER_RADIUS,
    );
    tableGraphics.stroke({ width: 12, color: 0x5c3d2e }); // Wood color

    // Inner rail edge
    tableGraphics.roundRect(
      -halfW + 6,
      -halfH + 4,
      TABLE_WIDTH - 12,
      TABLE_HEIGHT - 8,
      TABLE_BORDER_RADIUS - 6,
    );
    tableGraphics.stroke({ width: 2, color: 0x8b6914 }); // Gold trim

    this.containers.tableContainer.addChild(tableGraphics);

    // Initialize TableInfoRenderer
    this.renderers.tableInfo = new TableInfoRenderer(
      () => this.state,
      () => this.lobbyState,
    );

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
        () => this.lobbyState,
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
  },

  async rebuildCanvas() {
    this.clear();
    await this.createTable();
    this.renderCommunityCards();
    this.resize();
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
    const maxScale = Math.min(width / TABLE_WIDTH, height / TABLE_HEIGHT) * 0.9;
    const scale = Math.min(fitScale * 1.3, maxScale);

    this.containers.container.scale.set(scale);
    this.containers.container.x = width / 2;
    this.containers.container.y = height / 2;

    document.documentElement.style.setProperty("--game-scale", scale);

    // Boost buttons on smaller screens to maintain touch-friendly size
    const buttonBoost = scale < 1 ? Math.min(1 / scale, 1.5) : 1;
    document.documentElement.style.setProperty("--button-boost", buttonBoost);
  },

  clear() {
    this.containers.container.removeChildren();
  },
};
