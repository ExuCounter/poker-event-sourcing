import * as PIXI from "pixi.js";
import {
  TABLE_WIDTH,
  TABLE_HEIGHT,
  EMPTY_SEAT_COLORS,
  FONTS,
} from "../constants.js";

const EMPTY_SEAT_SIZE = 110; // Diameter for circular empty seats

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
      x: pos.x - EMPTY_SEAT_SIZE / 2,
      y: pos.y - EMPTY_SEAT_SIZE / 2 + 20,
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

    // Check if player can join a seat (false for tournaments)
    const canJoinSeat = state.playerActions?.canJoinSeat === true;

    // Hide empty seats entirely when joining isn't possible (tournaments)
    if (!canJoinSeat) {
      this.container.visible = false;
      return;
    }

    const isCurrentUserSeated = state.participants.some(
      (p) => p.playerId === state.currentUserId,
    );
    const canClick = !isCurrentUserSeated;

    this.container.visible = true;
    this.container.eventMode = canClick ? "static" : "none";
    this.container.cursor = canClick ? "pointer" : "default";

    const seatPosition = this.#getSeatPosition();
    this.container.position.set(seatPosition.x, seatPosition.y);

    // Draw empty seat placeholder
    this.#renderEmptySeat(!canClick);
  }

  #renderEmptySeat(isCurrentUserSeated) {
    const seatContainer = new PIXI.Container();
    const size = EMPTY_SEAT_SIZE;
    const halfSize = size / 2;

    // Circular semi-transparent background
    const bg = new PIXI.Graphics();
    bg.circle(halfSize, halfSize, halfSize);
    bg.fill({ color: EMPTY_SEAT_COLORS.bg, alpha: EMPTY_SEAT_COLORS.bgAlpha });
    bg.stroke({
      color: EMPTY_SEAT_COLORS.border,
      width: 1.5,
      alpha: EMPTY_SEAT_COLORS.borderAlpha,
    });
    seatContainer.addChild(bg);

    // "Seat N" label
    const seatLabel = new PIXI.Text({
      text: `Seat`,
      style: {
        fontFamily: FONTS.mono,
        fontSize: 16,
        fontWeight: "500",
        fill: EMPTY_SEAT_COLORS.labelText,
        letterSpacing: 1,
      },
    });
    seatLabel.anchor.set(0.5, 0.5);
    seatLabel.position.set(halfSize, halfSize - 12);
    seatContainer.addChild(seatLabel);

    // "Open" or "Empty" based on user status
    if (!isCurrentUserSeated) {
      const joinText = new PIXI.Text({
        text: "Open",
        style: {
          fontFamily: FONTS.ui,
          fontSize: 16,
          fontWeight: "bold",
          fill: EMPTY_SEAT_COLORS.openText,
        },
      });
      joinText.anchor.set(0.5, 0.5);
      joinText.position.set(halfSize, halfSize + 14);
      seatContainer.addChild(joinText);

      // Add hover effect
      this.container.on("pointerover", () => {
        bg.clear();
        bg.circle(halfSize, halfSize, halfSize);
        bg.fill({
          color: EMPTY_SEAT_COLORS.hoverBg,
          alpha: EMPTY_SEAT_COLORS.hoverBgAlpha,
        });
        bg.stroke({
          color: EMPTY_SEAT_COLORS.hoverBorder,
          width: 2,
          alpha: 0.9,
        });
      });

      this.container.on("pointerout", () => {
        bg.clear();
        bg.circle(halfSize, halfSize, halfSize);
        bg.fill({
          color: EMPTY_SEAT_COLORS.bg,
          alpha: EMPTY_SEAT_COLORS.bgAlpha,
        });
        bg.stroke({
          color: EMPTY_SEAT_COLORS.border,
          width: 1.5,
          alpha: EMPTY_SEAT_COLORS.borderAlpha,
        });
      });
    } else {
      // Show "Empty" for seated users
      const emptyText = new PIXI.Text({
        text: "Empty",
        style: {
          fontFamily: FONTS.ui,
          fontSize: 16,
          fill: EMPTY_SEAT_COLORS.labelText,
        },
      });
      emptyText.anchor.set(0.5, 0.5);
      emptyText.position.set(halfSize, halfSize + 14);
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
