import * as PIXI from "pixi.js";

export class CardRenderer {
  render(card) {
    const container = new PIXI.Container();
    const bg = new PIXI.Graphics();
    bg.roundRect(0, 0, 70, 100, 8);

    if (!card) {
      // Face down card with nicer styling
      bg.fill(0x1a365d);
      bg.stroke({ width: 2, color: 0x2d4a6f });
      container.addChild(bg);

      const pattern = new PIXI.Graphics();
      pattern.roundRect(5, 5, 60, 90, 6);
      pattern.fill(0x152951);
      container.addChild(pattern);

      // Diamond pattern on back
      const diamond = new PIXI.Graphics();
      diamond.moveTo(35, 15);
      diamond.lineTo(50, 50);
      diamond.lineTo(35, 85);
      diamond.lineTo(20, 50);
      diamond.closePath();
      diamond.stroke({ width: 1.5, color: 0x3b5998, alpha: 0.6 });
      container.addChild(diamond);

      return container;
    }

    // Face up card
    bg.fill(0xffffff);
    bg.stroke({ width: 2, color: 0x333333 });
    container.addChild(bg);

    const isRed = card.suit === "hearts" || card.suit === "diamonds";
    const color = isRed ? 0xdc2626 : 0x1f2937;

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
        fontFamily: "Arial, sans-serif",
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
  }
}
