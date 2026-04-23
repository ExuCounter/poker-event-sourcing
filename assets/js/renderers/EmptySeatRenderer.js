import * as PIXI from "pixi.js";
import {
  TABLE_WIDTH,
  TABLE_HEIGHT,
  HOOD_WIDTH,
  HOOD_HEIGHT,
  HOOD_BORDER_RADIUS,
} from "../constants.js";

export class EmptySeatRenderer {
  constructor(seatNumber, tableContainer, getState, onSeatClick) {
    this.seatNumber = seatNumber; // Physical seat number (1-6)
    this.getState = getState;
    this.tableContainer = tableContainer;
    this.onSeatClick = onSeatClick; // Callback when seat is clicked

    this.container = new PIXI.Container();
    this.container.sortableChildren = true;
    this.container.eventMode = "static";
    this.container.cursor = "pointer";

    this.tableContainer.addChild(this.container);

    // Bind click handler
    this.container.on("pointerdown", () => {
      if (this.onSeatClick) {
        this.onSeatClick(this.seatNumber);
      }
    });
  }

  // Fixed seat positions for 6-max table (indexed 0-5 for visual positions)
  // Position 0 is always at bottom center, then clockwise
  #getFixedSeatPositions() {
    const halfW = TABLE_WIDTH / 2;
    const halfH = TABLE_HEIGHT / 2;
    const sidePadding = 30;
    const topPadding = 20;
    const bottomPadding = -10;

    return [
      { x: 0, y: halfH + bottomPadding }, // Visual 0: Bottom center
      { x: halfW + sidePadding, y: halfH * 0.4 }, // Visual 1: Bottom right
      { x: halfW + sidePadding, y: -halfH * 0.4 }, // Visual 2: Top right
      { x: 0, y: -halfH - topPadding }, // Visual 3: Top center
      { x: -halfW - sidePadding, y: -halfH * 0.4 }, // Visual 4: Top left
      { x: -halfW - sidePadding, y: halfH * 0.4 }, // Visual 5: Bottom left
    ];
  }

  // Calculate visual position with rotation so current user is at bottom
  #getVisualPosition() {
    const state = this.getState();
    const currentUser = state.participants.find(
      (p) => p.playerId === state.currentUserId,
    );

    // Get viewer's physical seat number (1-6), default to 1 if not seated
    const viewerSeatNumber = currentUser?.seatNumber || 1;

    // Calculate rotation offset so viewer's seat appears at visual position 0 (bottom)
    const rotationOffset = viewerSeatNumber - 1;

    // Apply rotation: shift seat numbers so current user is at visual position 0
    // Seat numbers are 1-6, visual positions are 0-5
    const visualPosition = (this.seatNumber - 1 - rotationOffset + 6) % 6;

    return visualPosition;
  }

  #getSeatPosition() {
    const visualPosition = this.#getVisualPosition();
    const seatPositions = this.#getFixedSeatPositions();
    const pos = seatPositions[visualPosition] || { x: 0, y: 0 };

    return {
      x: pos.x - HOOD_WIDTH / 2,
      y: pos.y - 70,
    };
  }

  render() {
    this.container.removeChildren();

    const state = this.getState();

    // Check if this seat is occupied
    const isOccupied = state.participants.some(
      (p) => p.seatNumber === this.seatNumber,
    );

    if (isOccupied) {
      // Don't render empty seat if it's occupied
      this.container.visible = false;
      return;
    }

    // Check if current user is already seated (can't join another seat)
    const isCurrentUserSeated = state.participants.some(
      (p) => p.playerId === state.currentUserId,
    );

    this.container.visible = true;
    this.container.eventMode = isCurrentUserSeated ? "none" : "static";
    this.container.cursor = isCurrentUserSeated ? "default" : "pointer";

    const seatPosition = this.#getSeatPosition();
    this.container.position.set(seatPosition.x, seatPosition.y);

    // Draw empty seat placeholder
    this.#renderEmptySeat(isCurrentUserSeated);
  }

  #renderEmptySeat(isCurrentUserSeated) {
    const seatContainer = new PIXI.Container();
    seatContainer.position.set(0, 79); // Same as CARD_OVERLAP

    // Semi-transparent background
    const bg = new PIXI.Graphics();
    bg.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
    bg.fill({ color: 0x1a1a1a, alpha: 0.5 });
    bg.stroke({ color: 0x4a4a4a, width: 2, alpha: 0.6 });
    seatContainer.addChild(bg);

    // "Seat N" label
    const seatLabel = new PIXI.Text({
      text: `Seat ${this.seatNumber}`,
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 18,
        fontWeight: "bold",
        fill: 0x888888,
      },
    });
    seatLabel.anchor.set(0.5, 0.5);
    seatLabel.position.set(HOOD_WIDTH / 2, HOOD_HEIGHT / 3);
    seatContainer.addChild(seatLabel);

    // "Click to join" or empty placeholder based on user status
    if (!isCurrentUserSeated) {
      const joinText = new PIXI.Text({
        text: "Click to join",
        style: {
          fontFamily: "Arial, sans-serif",
          fontSize: 16,
          fontWeight: "bold",
          fill: 0x4ade80, // Green color for action
        },
      });
      joinText.anchor.set(0.5, 0.5);
      joinText.position.set(HOOD_WIDTH / 2, (HOOD_HEIGHT * 2) / 3);
      seatContainer.addChild(joinText);

      // Add hover effect
      this.container.on("pointerover", () => {
        bg.clear();
        bg.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
        bg.fill({ color: 0x2a2a2a, alpha: 0.7 });
        bg.stroke({ color: 0x4ade80, width: 2, alpha: 0.8 });
      });

      this.container.on("pointerout", () => {
        bg.clear();
        bg.roundRect(0, 0, HOOD_WIDTH, HOOD_HEIGHT, HOOD_BORDER_RADIUS);
        bg.fill({ color: 0x1a1a1a, alpha: 0.5 });
        bg.stroke({ color: 0x4a4a4a, width: 2, alpha: 0.6 });
      });
    } else {
      // Show "Empty" for seated users
      const emptyText = new PIXI.Text({
        text: "Empty",
        style: {
          fontFamily: "Arial, sans-serif",
          fontSize: 16,
          fill: 0x666666,
        },
      });
      emptyText.anchor.set(0.5, 0.5);
      emptyText.position.set(HOOD_WIDTH / 2, (HOOD_HEIGHT * 2) / 3);
      seatContainer.addChild(emptyText);
    }

    this.container.addChild(seatContainer);
  }

  getContainer() {
    return this.container;
  }

  destroy() {
    this.container.removeAllListeners();
    this.tableContainer.removeChild(this.container);
    this.container.destroy({ children: true });
  }
}
