import * as PIXI from "pixi.js";
import { ChipsRenderer } from "./ChipsRenderer.js";

export class TotalPotRenderer {
  constructor(getState) {
    this.getState = getState;
    this.container = new PIXI.Container();
  }

  render(totalPot) {
    this.container.removeChildren();

    // Render chips
    const chipsRenderer = new ChipsRenderer();
    const chipsContainer = chipsRenderer.render(totalPot);
    this.container.addChild(chipsContainer);

    // Render amount text
    const text = new PIXI.Text({
      text: `$${totalPot}`,
      style: {
        fontSize: 18,
        fontWeight: "bold",
        fill: "#e2e2e2",
      },
    });

    text.position.set(-chipsContainer.width / 2, 25);
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
