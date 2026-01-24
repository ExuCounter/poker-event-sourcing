import * as PIXI from "pixi.js";
import gsap from "gsap";
import { CardRenderer } from "./CardRenderer.js";

export class CommunityCardsRenderer {
  constructor(getState) {
    this.getState = getState;
    this.container = new PIXI.Container();
  }

  render(communityCards) {
    this.container.removeChildren();

    const cardRenderer = new CardRenderer();
    communityCards.forEach((card, index) => {
      const cardSprite = cardRenderer.render(card);
      cardSprite.position.set(index * 80, 0);
      this.container.addChild(cardSprite);
    });

    // Center the cards on the table
    const maxWidth = 5 * 80;
    const tableHeight = 800; // Base table height

    this.container.position.set(-(maxWidth / 2), -(tableHeight / 4));

    return this.container;
  }

  async animateNewCards(newCards, timing) {
    const timeline = gsap.timeline();
    const state = this.getState();

    const cardRenderer = new CardRenderer();
    newCards.forEach((card, index) => {
      const cardSprite = cardRenderer.render(card);
      cardSprite.position.set(0, 200);
      cardSprite.alpha = 0;

      const targetIndex = state.communityCards.length - newCards.length + index;

      const targetX = targetIndex * 80;

      this.container.addChild(cardSprite);

      timeline.to(
        cardSprite,
        {
          x: targetX,
          y: 0,
          alpha: 1,
          duration: timing.duration / 1000,
          delay: index * 0.15,
          ease: "power2.out",
        },
        0,
      );
    });

    await timeline.then();
  }

  getContainer() {
    return this.container;
  }

  clear() {
    this.container.removeChildren();
  }
}
