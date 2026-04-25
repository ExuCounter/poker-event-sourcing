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
    shadow.circle(1.5, 2, buttonRadius + 1);
    shadow.fill({ color: 0x000000, alpha: 0.4 });
    this.container.addChild(shadow);

    // Red outer ring
    const button = new PIXI.Graphics();
    button.circle(0, 0, buttonRadius);
    button.fill(0xcc2222);
    button.circle(0, 0, buttonRadius);
    button.stroke({ color: 0x991111, width: 1.5 });
    this.container.addChild(button);

    // Inner circle (darker red)
    const inner = new PIXI.Graphics();
    inner.circle(0, 0, buttonRadius - 3);
    inner.fill(0xb81c1c);
    this.container.addChild(inner);

    // "D" text
    const dealerText = new PIXI.Text({
      text: "D",
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 15,
        fontWeight: "bold",
        fill: 0xffffff,
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
