import * as PIXI from "pixi.js";
import {
  CARD_WIDTH,
  CARD_HEIGHT,
  CARD_BORDER_RADIUS,
  CARD_PATTERN,
  CARD_FONT_SIZES,
  CARD_TEXT_POSITIONS,
  CARD_COLORS,
  CARD_SUIT_SYMBOLS,
  FONTS,
} from "../constants.js";

export class CardRenderer {
  renderHoleCard(card) {
    const container = this.#createCardBase(card);

    if (!card) {
      return container;
    }

    const { color, suitSymbols } = this.#getCardStyle(card);

    this.#addRankAndSmallSuit(container, card, color, suitSymbols);

    return container;
  }

  renderCommunityCard(card) {
    const container = this.#createCardBase(card);

    if (!card) {
      return container;
    }

    const { color, suitSymbols } = this.#getCardStyle(card);

    this.#addRankAndSmallSuit(container, card, color, suitSymbols);
    this.#addCenterSuit(container, card, color, suitSymbols);

    return container;
  }

  #createCardBase(card) {
    const container = new PIXI.Container();
    const bg = new PIXI.Graphics();
    bg.roundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, CARD_BORDER_RADIUS);

    if (!card) {
      // Face down — tartan oxblood pattern (Cellar direction)
      bg.fill(CARD_COLORS.backBg);
      bg.stroke({ width: 1.5, color: CARD_COLORS.backBorder });
      container.addChild(bg);

      // Tartan stripe pattern (45deg repeating)
      const stripes = new PIXI.Graphics();
      const stripeWidth = 6;
      const gap = 6;
      const totalSize = CARD_WIDTH + CARD_HEIGHT;

      for (let i = -totalSize; i < totalSize; i += stripeWidth + gap) {
        stripes.moveTo(i, 0);
        stripes.lineTo(i + totalSize, totalSize);
        stripes.lineTo(i + totalSize + stripeWidth, totalSize);
        stripes.lineTo(i + stripeWidth, 0);
        stripes.closePath();
        stripes.fill({ color: CARD_COLORS.backStripe1, alpha: 0.6 });
      }

      // Mask stripes to card shape
      const mask = new PIXI.Graphics();
      mask.roundRect(0, 0, CARD_WIDTH, CARD_HEIGHT, CARD_BORDER_RADIUS);
      mask.fill(0xffffff);
      container.addChild(mask);
      stripes.mask = mask;
      container.addChild(stripes);

      // Inner border frame
      const innerFrame = new PIXI.Graphics();
      innerFrame.roundRect(
        CARD_PATTERN.x,
        CARD_PATTERN.y,
        CARD_PATTERN.width,
        CARD_PATTERN.height,
        CARD_PATTERN.borderRadius,
      );
      innerFrame.stroke({
        width: 1,
        color: CARD_COLORS.backInnerBorder,
        alpha: 0.18,
      });
      container.addChild(innerFrame);

      return container;
    }

    // Face up card — cream white
    bg.fill(CARD_COLORS.faceBg);
    bg.stroke({ width: 1, color: CARD_COLORS.faceBorder });
    container.addChild(bg);

    return container;
  }

  #getCardStyle(card) {
    const isRed = card.suit === "hearts" || card.suit === "diamonds";
    const color = isRed ? CARD_COLORS.red : CARD_COLORS.black;

    return { color, suitSymbols: CARD_SUIT_SYMBOLS };
  }

  #addRankAndSmallSuit(container, card, color, suitSymbols) {
    const rankText = new PIXI.Text({
      text: card.rank,
      style: {
        fontSize: CARD_FONT_SIZES.rank,
        fill: color,
        fontWeight: "bold",
        fontFamily: FONTS.display,
      },
    });

    rankText.position.set(
      CARD_TEXT_POSITIONS.rank.x,
      CARD_TEXT_POSITIONS.rank.y,
    );
    container.addChild(rankText);

    const suitSmall = new PIXI.Text({
      text: suitSymbols[card.suit],
      style: {
        fontSize: CARD_FONT_SIZES.smallSuit,
        fill: color,
      },
    });

    suitSmall.position.set(
      CARD_TEXT_POSITIONS.smallSuit.x,
      CARD_TEXT_POSITIONS.smallSuit.y,
    );
    container.addChild(suitSmall);
  }

  #addCenterSuit(container, card, color, suitSymbols) {
    const suitBig = new PIXI.Text({
      text: suitSymbols[card.suit],
      style: {
        fontSize: CARD_FONT_SIZES.bigSuit,
        fill: color,
      },
      anchor: 0.5,
    });

    suitBig.position.set(
      CARD_TEXT_POSITIONS.bigSuit.x,
      CARD_TEXT_POSITIONS.bigSuit.y,
    );
    container.addChild(suitBig);
  }
}
