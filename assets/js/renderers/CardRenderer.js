import * as PIXI from "pixi.js";
import {
  CARD_WIDTH,
  CARD_HEIGHT,
  CARD_BORDER_RADIUS,
  CARD_PATTERN,
  CARD_DIAMOND_COORDS,
  CARD_FONT_SIZES,
  CARD_TEXT_POSITIONS,
  CARD_COLORS,
  CARD_SUIT_SYMBOLS,
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
      // Face down card with nicer styling
      bg.fill(CARD_COLORS.backBg);
      bg.stroke({ width: 2, color: CARD_COLORS.backBorder });
      container.addChild(bg);

      const pattern = new PIXI.Graphics();
      pattern.roundRect(
        CARD_PATTERN.x,
        CARD_PATTERN.y,
        CARD_PATTERN.width,
        CARD_PATTERN.height,
        CARD_PATTERN.borderRadius,
      );
      pattern.fill(CARD_COLORS.backPattern);
      container.addChild(pattern);

      // Diamond pattern on back
      const diamond = new PIXI.Graphics();
      diamond.moveTo(CARD_DIAMOND_COORDS.center.x, CARD_DIAMOND_COORDS.center.y);
      diamond.lineTo(CARD_DIAMOND_COORDS.right.x, CARD_DIAMOND_COORDS.right.y);
      diamond.lineTo(CARD_DIAMOND_COORDS.bottom.x, CARD_DIAMOND_COORDS.bottom.y);
      diamond.lineTo(CARD_DIAMOND_COORDS.left.x, CARD_DIAMOND_COORDS.left.y);
      diamond.closePath();
      diamond.stroke({ width: 1.5, color: CARD_COLORS.backDiamond, alpha: 0.6 });
      container.addChild(diamond);

      return container;
    }

    // Face up card
    bg.fill(CARD_COLORS.faceBg);
    bg.stroke({ width: 2, color: CARD_COLORS.faceBorder });
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
        fontFamily: "Arial, sans-serif",
      },
    });

    rankText.position.set(CARD_TEXT_POSITIONS.rank.x, CARD_TEXT_POSITIONS.rank.y);
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
