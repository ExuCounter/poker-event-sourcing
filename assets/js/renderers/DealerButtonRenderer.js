import * as PIXI from "pixi.js";
import { HOOD_WIDTH, CARD_OVERLAP } from "../constants.js";

export class DealerButtonRenderer {
  constructor(getState, getParticipantPosition) {
    this.getState = getState;
    this.getParticipantPosition = getParticipantPosition;
    this.container = new PIXI.Container();
    this.container.zIndex = 15;

    this.#createButton();
  }

  #createButton() {
    const buttonRadius = 14;

    // Shadow
    const shadow = new PIXI.Graphics();
    shadow.circle(2, 2, buttonRadius);
    shadow.fill({ color: 0x000000, alpha: 0.3 });
    this.container.addChild(shadow);

    // White circle
    const button = new PIXI.Graphics();
    button.circle(0, 0, buttonRadius);
    button.fill(0xffffff);
    button.circle(0, 0, buttonRadius);
    button.stroke({ color: 0xcccccc, width: 1 });
    this.container.addChild(button);

    // "D" text
    const dealerText = new PIXI.Text({
      text: "D",
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 16,
        fontWeight: "bold",
        fill: 0x1a1a1a,
      },
    });
    dealerText.anchor.set(0.5, 0.5);
    this.container.addChild(dealerText);
  }

  getContainer() {
    return this.container;
  }

  render() {
    const state = this.getState();
    const dealer = state.participants.find((p) => p.position === "dealer");

    if (!dealer) {
      this.container.visible = false;
      return;
    }

    this.container.visible = true;

    // Get the dealer's screen position
    const dealerPos = this.getParticipantPosition(dealer.id);

    // Position button near the hood (top-right corner)
    this.container.position.set(
      dealerPos.x + HOOD_WIDTH + 5,
      dealerPos.y + CARD_OVERLAP + 10,
    );
  }
}
