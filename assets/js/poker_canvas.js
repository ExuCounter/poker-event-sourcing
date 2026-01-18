import * as PIXI from "pixi.js";
import gsap from "gsap";
import { Howl } from "howler";

export const PokerCanvas = {
  async mounted() {
    const serverState = JSON.parse(this.el.dataset.state);

    this.app = new PIXI.Application();

    this.containers = {};

    this.state = {
      communityCards: serverState.community_cards || [],
      participants: serverState.participants || [],
      totalPot: serverState.total_pot,
      currentUserId: this.el.dataset.currentUserId,
    };

    console.log(this.state);

    await this.app.init({
      canvas: this.el,
      backgroundColor: 0x2d5a27,
      resizeTo: window,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
      antialias: true,
    });

    this.handleEvent("table_event", async ({ event: event }) => {
      await this.runAnimation(event);
      this.pushEvent("event_processed", { event_id: event.event_id });
    });

    this.loadSounds();
    await this.createTable();
    this.renderHoleCards();
    this.renderCommunityCards();
  },

  loadSounds() {
    this.sounds = {
      raise: new Howl({ src: ["/sounds/raise.mp3"], volume: 0.5 }),
    };
  },

  async runAnimation(event) {
    // Extract timing from event (if provided by server)
    const timing = event.timing || event.animation || {};

    switch (event.type) {
      case "ParticipantRaised":
        this.sounds.raise.play();
        await this.animateBetChipsUpdated(event, timing);
        break;
      case "RoundStarted":
        await this.animateCommunityCardsAppear(event, timing);
        break;
      case "ParticipantHandGiven":
        await this.animateParticipantHandGiven(event, timing);
        break;
      case "ParticipantCalled":
        await this.animateBetChipsUpdated(event, timing);
        break;
      case "SmallBlindPosted":
        await this.animateBetChipsUpdated(event, timing);
        break;
      case "BigBlindPosted":
        await this.animateBetChipsUpdated(event, timing);
        break;
      case "ParticipantWentAllIn":
        await this.animateBetChipsUpdated(event, timing);
        break;
      case "PayoutDistributed":
        await this.animateBetChipsCollectToPlayer(event, timing);
        break;
      case "HandFinished":
        await this.handleHandFinish(event, timing);
        break;
      case "PotsRecalculated":
        await this.animateBetChipsCollectToPot(event, timing);
        break;
      default:
        return;
    }
  },

  async animateBetChipsCollectToPlayer(event, timing) {
    const timeline = gsap.timeline();
    const betArea = this.betAreas[event.participant_id];

    const globalTarget = betArea.container.getGlobalPosition();
    const localTarget = this.containers.totalPotContainer.toLocal(globalTarget);

    this.state.totalPot -= event.amount;

    this.containers.totalPotContainer = await this.renderTotalPot(
      this.containers.totalPotContainer,
      this.state.totalPot,
    );

    const totalPot = await this.renderTotalPot(
      new PIXI.Container(),
      event.amount,
    );

    this.containers.totalPotContainer.addChild(totalPot);

    totalPot.position.set(0, 0);

    timeline.to(totalPot, {
      x: localTarget.x,
      y: localTarget.y,
      duration: 0.5,
      ease: "power2.out",
    });

    await timeline.then();
  },

  async renderTotalPot(container, amount) {
    container.removeChildren();

    const totalPot = new PIXI.Text({
      text: `$${amount}`,
      style: {
        fontSize: 24,
      },
      anchor: 0.5,
    });

    totalPot.position.set(0, 40);

    const chipsContainer = new PIXI.Container();

    chipsContainer.position.set(0, 0);

    container.addChild(totalPot);
    container.addChild(chipsContainer);

    this.createChips(amount, chipsContainer);

    return container;
  },

  async animateBetChipsCollectToPot(event, timing) {
    const timeline = gsap.timeline();
    const originalPositions = new Map();

    Object.values(this.betAreas).forEach((area) => {
      originalPositions.set(area, { x: area.container.x, y: area.container.y });

      const globalTarget =
        this.containers.totalPotContainer.getGlobalPosition();
      const localTarget = area.container.toLocal(globalTarget);

      timeline.to(area.container, {
        x: localTarget.x,
        y: localTarget.y - 60,
        duration: 0.25,
        ease: "power2.out",
      });
    });

    await timeline.then();

    const totalPotAmount = event.pots.reduce((sum, pot) => sum + pot.amount, 0);

    this.containers.totalPotContainer = await this.renderTotalPot(
      this.containers.totalPotContainer || new PIXI.Container(),
      totalPotAmount,
    );

    this.state.totalPot = totalPotAmount;

    Object.values(this.betAreas).forEach((area) => {
      area.container.removeChildren();
      area.betAmount = 0;
      const orig = originalPositions.get(area);
      area.container.x = orig.x;
      area.container.y = orig.y;
    });
  },

  async handleHandFinish() {
    this.containers.communityCardsContainer.removeChildren();
    this.containers.totalPotContainer.removeChildren();
    Object.values(this.betAreas).forEach((area) => {
      area.container.removeChildren();
    });

    this.state.communityCards = [];
  },

  async animateParticipantHandGiven(event, timing) {
    const participant = this.containers.participants[event.participant_id];

    event.hole_cards.forEach((card, index) => {
      const cardSprite = this.createCard(card);
      const globalCenter = this.containers.tableContainer.toGlobal({
        x: 0,
        y: 0,
      });

      const localStart = participant.toLocal(globalCenter);

      cardSprite.position.set(localStart.x - 40, localStart.y - 40);

      const targetX = index * 40;
      const targetY = 0;

      participant.addChild(cardSprite);

      gsap.to(cardSprite, {
        x: targetX,
        y: targetY,
        alpha: 1,
        duration: 0.25,
        delay: index * 0.15, // stagger each card
        ease: "power2.out",
      });
    });

    participant.holeCards = event.hole_cards;
  },

  async animateCommunityCardsAppear(event, timing) {
    event.community_cards.forEach((card, index) => {
      this.state.communityCards.push(card);
      const cardSprite = this.createCard(card);

      this.containers.communityCardsContainer.addChild(cardSprite);

      cardSprite.position.set(0, 200);

      const targetX = (this.state.communityCards.length - 1) * 80;
      const targetY = 0;

      gsap.to(cardSprite, {
        x: targetX,
        y: targetY,
        alpha: 1,
        duration: 0.25,
        delay: index * 0.15, // stagger each card
        ease: "power2.out",
      });
    });
  },

  async animateBetChipsUpdated(event, timing) {
    const betArea = this.betAreas[event.participant_id];

    betArea.container.removeChildren();

    betArea.betAmount = event.amount + betArea.betAmount;

    this.createChips(betArea.betAmount, betArea.container);
  },

  renderHoleCards() {
    for (const [participantId, container] of Object.entries(
      this.containers.participants,
    )) {
      const participant = this.state.participants.find(
        (participant) => participant.id === participantId,
      );

      const holeCards = participant?.hole_cards || [null, null];

      holeCards.forEach((card, index) => {
        const cardSprite = this.createCard(card);
        cardSprite.position.set(index * 40, 0);
        container.addChild(cardSprite);
      });
    }
  },

  renderCommunityCards() {
    this.containers.communityCardsContainer = new PIXI.Container();

    this.containers.tableContainer.addChild(
      this.containers.communityCardsContainer,
    );

    this.state.communityCards.forEach((card, index) => {
      const cardSprite = this.createCard(card);
      cardSprite.position.set(index * 80, 0); // space cards apart
      this.containers.communityCardsContainer.addChild(cardSprite);
    });

    const maxWidth = 5 * 80; // 5 community cards max

    this.containers.communityCardsContainer.position.set(
      -maxWidth / 2,
      -this.containers.tableContainer.height / 4, // adjust as needed
    );
  },

  createCard(card) {
    const container = new PIXI.Container();
    const bg = new PIXI.Graphics();
    bg.roundRect(0, 0, 70, 100, 8);

    // face down card
    if (!card) {
      bg.fill(0x2244aa);
      bg.stroke({ width: 2, color: 0x000000 });
      container.addChild(bg);

      // pattern on back
      const pattern = new PIXI.Graphics();
      pattern.roundRect(5, 5, 60, 90, 6);
      pattern.fill(0x1a3377);
      container.addChild(pattern);

      // inner decoration
      const inner = new PIXI.Graphics();
      inner.roundRect(10, 10, 50, 80, 4);
      inner.stroke({ width: 1, color: 0x3355aa });
      container.addChild(inner);

      return container;
    }

    // face up card
    bg.fill(0xffffff);
    bg.stroke({ width: 2, color: 0x000000 });
    container.addChild(bg);

    const isRed = card.suit === "hearts" || card.suit === "diamonds";
    const color = isRed ? 0xff0000 : 0x000000;

    const suitSymbols = {
      hearts: "♥",
      diamonds: "♦",
      clubs: "♣",
      spades: "♠",
    };

    const rankText = new PIXI.Text({
      text: card.rank,
      style: {
        fontSize: 20,
        fill: color,
        fontWeight: "bold",
      },
      resolution: 2,
    });
    rankText.position.set(6, 4);
    container.addChild(rankText);

    const suitSmall = new PIXI.Text({
      text: suitSymbols[card.suit],
      style: {
        fontSize: 16,
        fill: color,
      },
    });
    suitSmall.position.set(8, 24);
    container.addChild(suitSmall);

    const suitBig = new PIXI.Text({
      text: suitSymbols[card.suit],
      style: {
        fontSize: 32,
        fill: color,
      },
      anchor: 0.5,
    });
    suitBig.position.set(35, 55);
    container.addChild(suitBig);

    return container;
  },

  async createTable() {
    this.containers.container = new PIXI.Container();
    this.containers.tableContainer = new PIXI.Container({
      x: this.app.screen.width / 2,
      y: this.app.screen.height / 2,
    });

    const tableGraphics = new PIXI.Graphics();

    tableGraphics.ellipse(
      0,
      0,
      this.app.screen.width / 2.5,
      this.app.screen.height / 3.75,
    );

    tableGraphics.fill(0x35654d);
    tableGraphics.stroke({ width: 5, color: "gray" });

    this.containers.totalPotContainer = await this.renderTotalPot(
      this.containers.totalPotContainer || new PIXI.Container(),
      this.state.totalPot,
    );

    console.log(this.containers.totalPotContainer);

    this.containers.tableContainer.addChild(tableGraphics);
    this.containers.tableContainer.addChild(this.containers.totalPotContainer);

    this.containers.container.addChild(this.containers.tableContainer);
    this.app.stage.addChild(this.containers.container);

    this.betAreas = {};
    this.containers.participants = {};

    this.state.participants.forEach((p, i) => {
      const { x: participantX, y: participantY } = this.getPlayerPosition(
        i,
        this.state.participants.length,
        this.state.currentUserId,
        this.state.participants,
      );

      const participantContainer = new PIXI.Container({
        x: participantX,
        y: participantY,
      });

      const chipsText = new PIXI.Text({
        text: `$${p.chips}`,
        style: { fill: 0x00ff00 },
        anchor: 0.5,
      });

      this.containers.participants[p.id] = participantContainer;

      participantContainer.addChild(chipsText);

      this.containers.tableContainer.addChild(participantContainer);

      const betContainer = new PIXI.Container({
        x: 0,
        y: -60,
      });

      participantContainer.addChild(betContainer);

      const chips = this.createChips(p.bet_this_round, betContainer);

      this.betAreas[p.id] = {
        container: betContainer,
        chips: chips,
        betAmount: p.bet_this_round,
      };
    });
  },

  createChips(betAmount, container) {
    const chips = [];
    const chipValues = [100, 25, 5, 1]; // Denominations from highest to lowest
    const chipColors = {
      100: 0x000000, // Black
      25: 0x00aa00, // Green
      5: 0xaa0000, // Red
      1: 0xffffff, // White
    };

    let remaining = betAmount;
    let stackOffset = 0;

    for (const value of chipValues) {
      while (remaining >= value) {
        const chip = this.createSingleChip(value, chipColors[value]);
        chip.y = -stackOffset * 4; // Stack chips vertically
        container.addChild(chip);
        chips.push(chip);

        remaining -= value;
        stackOffset++;
      }
    }

    return chips;
  },

  createSingleChip(value, color) {
    const chip = new PIXI.Container();

    // Main chip circle - v8 syntax
    const circle = new PIXI.Graphics();
    circle.circle(0, 0, 20);
    circle.fill(color);
    circle.stroke({ width: 2, color: 0xcccccc });

    // Inner ring decoration - v8 syntax
    const innerRing = new PIXI.Graphics();
    innerRing.circle(0, 0, 14);
    innerRing.stroke({ width: 2, color: 0xffffff, alpha: 0.5 });

    // Value text - v8 syntax
    const text = new PIXI.Text({
      text: value.toString(),
      style: {
        fontSize: 12,
        fontWeight: "bold",
        fill: color === 0xffffff ? 0x000000 : 0xffffff,
      },
      anchor: 0.5,
    });

    chip.addChild(circle, innerRing, text);
    return chip;
  },

  getPlayerPosition(
    participantIndex,
    totalPlayers,
    currentUserId,
    participants,
  ) {
    // Current user always at bottom center
    const currentUserIndex = participants.findIndex(
      (p) => p.player_id === currentUserId,
    );

    // Calculate relative position (same logic as your Elixir code)
    const relativePos =
      (participantIndex - currentUserIndex + totalPlayers) % totalPlayers;

    // 6-max positions matching your CSS
    const positions = {
      0: { x: 0, y: this.containers.tableContainer.height / 2 }, // hero - bottom center
      1: {
        x: this.containers.tableContainer.width / 3,
        y: this.containers.tableContainer.height / 2.5,
      }, // right of hero
    };

    return positions[relativePos] || positions[0];
  },

  wait(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  },

  destroyed() {
    this.app.destroy(true);
  },

  percent(value, total) {
    return (value / 100) * total;
  },
};
