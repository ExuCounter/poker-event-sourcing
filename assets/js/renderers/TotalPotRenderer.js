import * as PIXI from "pixi.js";
import { ChipsRenderer } from "./ChipsRenderer.js";

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

    // Render amount text
    const text = new PIXI.Text({
      text: `$${totalPot}`,
      style: {
        fontSize: 20,
        fontWeight: "bold",
        fill: "#e2e2e2",
      },
    });

    text.anchor.set(0.5, 0);
    text.position.set(0, chipsContainer.y + 28);
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
