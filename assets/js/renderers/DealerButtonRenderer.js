import * as PIXI from "pixi.js";
import { HOOD_WIDTH, CARD_OVERLAP, DEALER_BUTTON, FONTS } from "../constants.js";

export class DealerButtonRenderer {
  constructor(getState, getParticipantPosition) {
    this.getState = getState;
    this.getParticipantPosition = getParticipantPosition;
    this.container = new PIXI.Container();
    this.container.zIndex = 15;

    this.#createButton();
  }

  #createButton() {
    const r = DEALER_BUTTON.radius;

    // Shadow
    const shadow = new PIXI.Graphics();
    shadow.circle(1.5, 2, r + 1);
    shadow.fill({ color: DEALER_BUTTON.shadow, alpha: DEALER_BUTTON.shadowAlpha });
    this.container.addChild(shadow);

    // Brass outer
    const button = new PIXI.Graphics();
    button.circle(0, 0, r);
    button.fill(DEALER_BUTTON.bgGradientTop);
    button.circle(0, 0, r);
    button.stroke({ color: DEALER_BUTTON.border, width: 1.5 });
    this.container.addChild(button);

    // Inner circle (slightly darker)
    const inner = new PIXI.Graphics();
    inner.circle(0, 0, r - 3);
    inner.fill(DEALER_BUTTON.bgGradientBottom);
    this.container.addChild(inner);

    // "D" text
    const dealerText = new PIXI.Text({
      text: "D",
      style: {
        fontFamily: FONTS.display,
        fontSize: 15,
        fontWeight: "bold",
        fill: DEALER_BUTTON.text,
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
