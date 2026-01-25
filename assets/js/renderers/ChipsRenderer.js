import * as PIXI from "pixi.js";
import {
  CHIP_RADIUS,
  CHIP_SHADOW_OFFSET,
  CHIP_STACK_OFFSET,
  CHIP_NOTCH_COUNT,
  CHIP_NOTCH_RADIUS,
  CHIP_NOTCH_SIZE,
  CHIP_INNER_RING_RADIUS,
  CHIP_VALUES,
  CHIP_COLORS,
} from "../constants.js";

export class ChipsRenderer {
  render(amount) {
    const container = new PIXI.Container();
    const chips = [];

    let remaining = amount;
    let stackOffset = 0;

    for (const value of CHIP_VALUES) {
      while (remaining >= value) {
        const chip = this.#createSingleChip(value, CHIP_COLORS[value]);
        chip.y = -stackOffset * CHIP_STACK_OFFSET;
        container.addChild(chip);
        chips.push(chip);

        remaining -= value;
        stackOffset++;
      }
    }

    return container;
  }

  #createSingleChip(value, color) {
    const chip = new PIXI.Container();

    // Chip shadow
    const shadow = new PIXI.Graphics();
    shadow.circle(CHIP_SHADOW_OFFSET.x, CHIP_SHADOW_OFFSET.y, CHIP_RADIUS);
    shadow.fill({ color: 0x000000, alpha: 0.3 });
    chip.addChild(shadow);

    // Main chip
    const circle = new PIXI.Graphics();
    circle.circle(0, 0, CHIP_RADIUS);
    circle.fill(color);
    circle.stroke({ width: 2, color: 0xffffff, alpha: 0.3 });
    chip.addChild(circle);

    // Edge notches (classic poker chip style)
    const notches = new PIXI.Graphics();
    for (let i = 0; i < CHIP_NOTCH_COUNT; i++) {
      const angle = (i / CHIP_NOTCH_COUNT) * Math.PI * 2;
      const x = Math.cos(angle) * CHIP_NOTCH_RADIUS;
      const y = Math.sin(angle) * CHIP_NOTCH_RADIUS;
      notches.circle(x, y, CHIP_NOTCH_SIZE);
    }
    notches.fill(0xffffff, 0.4);
    chip.addChild(notches);

    // Inner ring
    const innerRing = new PIXI.Graphics();
    innerRing.circle(0, 0, CHIP_INNER_RING_RADIUS);
    innerRing.stroke({ width: 2, color: 0xffffff, alpha: 0.5 });
    chip.addChild(innerRing);

    // Value text
    const text = new PIXI.Text({
      text: value.toString(),
      style: {
        fontSize: 11,
        fontWeight: "bold",
        fill: color === CHIP_COLORS[1] ? 0x1a1a1a : 0xffffff,
        fontFamily: "Arial, sans-serif",
      },
      anchor: 0.5,
    });
    chip.addChild(text);

    return chip;
  }

  formatChips(amount) {
    if (amount >= 1000000) {
      return `$${(amount / 1000000).toFixed(1)}M`;
    }
    if (amount >= 10000) {
      return `$${(amount / 1000).toFixed(1)}K`;
    }
    return `$${amount.toLocaleString()}`;
  }
}
