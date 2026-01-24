import * as PIXI from "pixi.js";

export class ChipsRenderer {
  render(amount) {
    const container = new PIXI.Container();
    const chips = [];
    const chipValues = [100, 25, 5, 1];
    const chipColors = {
      100: 0x1a1a1a, // Black with slight grey
      25: 0x059669, // Emerald green
      5: 0xdc2626, // Red
      1: 0xf5f5f5, // Off-white
    };

    let remaining = amount;
    let stackOffset = 0;

    for (const value of chipValues) {
      while (remaining >= value) {
        const chip = this.#createSingleChip(value, chipColors[value]);
        chip.y = -stackOffset * 4;
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
    shadow.circle(2, 2, 20);
    shadow.fill({ color: 0x000000, alpha: 0.3 });
    chip.addChild(shadow);

    // Main chip
    const circle = new PIXI.Graphics();
    circle.circle(0, 0, 20);
    circle.fill(color);
    circle.stroke({ width: 2, color: 0xffffff, alpha: 0.3 });
    chip.addChild(circle);

    // Edge notches (classic poker chip style)
    const notches = new PIXI.Graphics();
    for (let i = 0; i < 8; i++) {
      const angle = (i / 8) * Math.PI * 2;
      const x = Math.cos(angle) * 16;
      const y = Math.sin(angle) * 16;
      notches.circle(x, y, 3);
    }
    notches.fill(0xffffff, 0.4);
    chip.addChild(notches);

    // Inner ring
    const innerRing = new PIXI.Graphics();
    innerRing.circle(0, 0, 12);
    innerRing.stroke({ width: 2, color: 0xffffff, alpha: 0.5 });
    chip.addChild(innerRing);

    // Value text
    const text = new PIXI.Text({
      text: value.toString(),
      style: {
        fontSize: 11,
        fontWeight: "bold",
        fill: color === 0xf5f5f5 ? 0x1a1a1a : 0xffffff,
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
