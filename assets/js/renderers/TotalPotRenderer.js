import * as PIXI from "pixi.js";
import { ChipsRenderer } from "./ChipsRenderer.js";
import { TABLE_COLORS, FONTS } from "../constants.js";

export class TotalPotRenderer {
  constructor(getState) {
    this.getState = getState;
    this.container = new PIXI.Container();
  }

  render(totalPot) {
    this.container.removeChildren();

    if (totalPot === 0) return this.container;

    // Render chips
    const chipsRenderer = new ChipsRenderer();
    const chipsContainer = chipsRenderer.render(totalPot);

    this.container.addChild(chipsContainer);

    // "POT" label
    const potLabel = new PIXI.Text({
      text: "POT",
      style: {
        fontFamily: FONTS.mono,
        fontSize: 11,
        fontWeight: "500",
        fill: TABLE_COLORS.potLabel,
        letterSpacing: 2,
      },
    });
    potLabel.anchor.set(0.5, 0);
    potLabel.position.set(0, chipsContainer.y + 26);
    potLabel.alpha = 0.6;
    this.container.addChild(potLabel);

    // Pot amount text
    const text = new PIXI.Text({
      text: `$${totalPot.toLocaleString()}`,
      style: {
        fontSize: 24,
        fontWeight: "bold",
        fill: TABLE_COLORS.potAmount,
        fontFamily: FONTS.display,
      },
    });

    text.anchor.set(0.5, 0);
    text.position.set(0, chipsContainer.y + 40);
    this.container.addChild(text);

    return this.container;
  }

  getContainer() {
    return this.container;
  }

  clear() {
    this.container.removeChildren();
  }
}
