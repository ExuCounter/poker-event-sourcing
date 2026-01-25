import * as PIXI from "pixi.js";
import gsap from "gsap";
import { CardRenderer } from "./CardRenderer.js";
import {
  COMMUNITY_CARD_SPACING,
  BASE_HEIGHT,
  ANIMATION_START_Y,
} from "../constants.js";

export class CommunityCardsRenderer {
  constructor(getState) {
    this.getState = getState;
    this.container = new PIXI.Container();
  }

  render(communityCards) {
    this.container.removeChildren();

    const cardRenderer = new CardRenderer();
    communityCards.forEach((card, index) => {
      const cardSprite = cardRenderer.renderCommunityCard(card);
      cardSprite.position.set(index * COMMUNITY_CARD_SPACING, 0);
      this.container.addChild(cardSprite);
    });

    // Center the cards on the table
    const maxWidth = 5 * COMMUNITY_CARD_SPACING;

    this.container.position.set(-(maxWidth / 2), -(BASE_HEIGHT / 6));

    return this.container;
  }

  async animateNewCards(newCards, timing) {
    const timeline = gsap.timeline();
    const state = this.getState();

    const cardRenderer = new CardRenderer();
    newCards.forEach((card, index) => {
      const cardSprite = cardRenderer.renderCommunityCard(card);
      cardSprite.position.set(0, ANIMATION_START_Y);
      cardSprite.alpha = 0;

      const targetIndex = state.communityCards.length - newCards.length + index;

      const targetX = targetIndex * COMMUNITY_CARD_SPACING;

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
