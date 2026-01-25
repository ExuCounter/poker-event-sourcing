import * as PIXI from "pixi.js";
import gsap from "gsap";
import { Howl } from "howler";
import { ParticipantRenderer } from "./renderers/ParticipantRenderer.js";
import { CommunityCardsRenderer } from "./renderers/CommunityCardsRenderer.js";
import { TotalPotRenderer } from "./renderers/TotalPotRenderer.js";
import { ChipsRenderer } from "./renderers/ChipsRenderer.js";
import {
  BASE_WIDTH,
  BASE_HEIGHT,
  TABLE_RADIUS_X,
  TABLE_RADIUS_Y,
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

    console.log(this.state);

    await this.app.init({
      canvas: this.el,
      backgroundColor: 0x1a3d2e, // Darker green for contrast
      resizeTo: window,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
      antialias: false,
    });

    // Initialize renderer objects
    this.renderers = {
      communityCards: null,
      totalPot: null,
      participants: new Map(),
    };

    this.handleEvent(
      "table_event",
      async ({ event: event, new_state: serverState }) => {
        this.state = serverState;

        console.log(event);
        console.log(this.state);

        // if (this.isReplayMode) {
        //   this.pushEvent("event_processed", {
        //     eventId: event.eventId || event.event_id,
        //   });
        // }

        await this.runAnimation(event);

        if (!this.isReplayMode) {
          this.pushEvent("event_processed", {
            eventId: event.eventId || event.event_id,
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
    const timing = event.timing || event.animation || { duration: 250 };

    switch (event.type) {
      case "ParticipantRaised":
        this.sounds.raise.play();
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "RoundStarted":
        await this.animateCommunityCardsAppear(event, timing);

        this.state.participants.forEach((p) => {
          const renderer = this.renderers.participants.get(p.id);
          renderer.render();
        });

        break;
      case "ParticipantHandGiven":
        await this.animateParticipantHandGiven(event, timing);
        break;
      case "ParticipantFolded":
        this.rerenderParticipant(event.participantId);
        break;
      case "ParticipantCalled":
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
        await this.animateBetChipsUpdated(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "PayoutDistributed":
        await this.animateBetChipsCollectToPlayer(event, timing);
        this.rerenderParticipant(event.participantId);
        break;
      case "ParticipantShowdownCardsRevealed":
        await this.showdownParticipantCards(event, timing);
        break;
      case "HandFinished":
        await this.wait(timing.duration);
        await this.handleHandFinish(event, timing);
        break;
      case "PotsRecalculated":
        await this.animateBetChipsCollectToPot(event, timing);
        break;
      default:
        return;
    }
  },

  async showdownParticipantCards(event) {
    const renderer = this.renderers.participants.get(event.participantId);
    const currentParticipant = this.state.participants.find(
      (p) => p.playerId === this.currentUserId,
    );

    if (currentParticipant.id !== event.participantId) {
      await renderer.flipHoleCards(event.holeCards);
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
    const payoutText = new PIXI.Text({
      text: `$${event.amount}`,
      style: { fontSize: 24, fill: 0xffd700, fontWeight: "bold" },
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
      duration: timing.duration / 1000 || 0.5,
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
        });

        const globalTarget = this.renderers.totalPot
          .getContainer()
          .getGlobalPosition();

        const localTarget =
          participantRenderer.betAreaContainer.toLocal(globalTarget);

        participantRenderer.hideBetAreaChipsText();

        // Return the tween promise without awaiting
        return timeline.to(
          participantRenderer.betAreaContainer,
          {
            x: localTarget.x,
            y: localTarget.y - 60,
            duration: timing.duration / 1000 || 0.4,
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

    // Create table with fixed dimensions
    const tableGraphics = new PIXI.Graphics();

    // Outer glow/shadow effect
    tableGraphics.ellipse(0, 4, TABLE_RADIUS_X + 5, TABLE_RADIUS_Y + 5);
    tableGraphics.fill({ color: 0x000000, alpha: 0.3 });

    // Main table felt
    tableGraphics.ellipse(0, 0, TABLE_RADIUS_X, TABLE_RADIUS_Y);
    tableGraphics.fill(0x35654d);

    // Inner felt highlight
    tableGraphics.ellipse(0, -10, TABLE_RADIUS_X - 20, TABLE_RADIUS_Y - 15);
    tableGraphics.fill(0x3d7359);

    // Table rail (border)
    tableGraphics.ellipse(0, 0, TABLE_RADIUS_X, TABLE_RADIUS_Y);
    tableGraphics.stroke({ width: 12, color: 0x5c3d2e }); // Wood color

    // Inner rail edge
    tableGraphics.ellipse(0, 0, TABLE_RADIUS_X - 6, TABLE_RADIUS_Y - 4);
    tableGraphics.stroke({ width: 2, color: 0x8b6914 }); // Gold trim

    this.containers.tableContainer.addChild(tableGraphics);

    // Initialize TotalPotRenderer
    this.renderers.totalPot = new TotalPotRenderer(() => this.state);
    this.containers.tableContainer.addChild(
      this.renderers.totalPot.getContainer(),
    );
    this.renderers.totalPot.render(this.state.totalPot);

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
  },

  async rebuildCanvas() {
    this.clear();
    await this.createTable();
    this.renderCommunityCards();
    this.resize();
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

    // Use min for uniform scaling, but set a minimum based on width
    const uniformScale = Math.min(scaleX, scaleY);
    const minScale = scaleX * 0.6; // Don't go below 60% of width-based scale

    const scale = Math.max(uniformScale, minScale);

    this.containers.container.scale.set(scale);
    this.containers.container.x = width / 2;
    this.containers.container.y = height / 2;

    document.documentElement.style.setProperty("--game-scale", scale);
  },

  clear() {
    this.containers.container.removeChildren();
  },
};
