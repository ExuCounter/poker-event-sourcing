import * as PIXI from "pixi.js";
import { TABLE_COLORS, FONTS } from "../constants.js";

export class TableInfoRenderer {
  constructor(getState) {
    this.getState = getState;
    this.container = new PIXI.Container();
  }

  render() {
    this.container.removeChildren();

    const state = this.getState();
    const tableType = state.tableType;
    const tableStatus = state.tableStatus;

    if (!tableType) {
      return this.container;
    }

    const formattedTableType = tableType
      .split("_")
      .map((word) => {
        // Convert number words to digits
        const numberMap = { six: "6", nine: "9", ten: "10" };
        return (
          numberMap[word.toLowerCase()] ||
          word.charAt(0).toUpperCase() + word.slice(1)
        );
      })
      .join("-");

    const formattedStatus = tableStatus
      ? tableStatus.charAt(0).toUpperCase() + tableStatus.slice(1)
      : "";

    const displayParts = [formattedTableType, "NL Holdem"];

    if (formattedStatus) {
      displayParts.push(formattedStatus);
    }

    // Watermark-style brand text on the felt
    const tableTypeText = new PIXI.Text({
      text: displayParts.join(" \u00B7 "),
      style: {
        fontFamily: FONTS.display,
        fontStyle: "italic",
        fontSize: 32,
        fontWeight: "400",
        fill: TABLE_COLORS.potAmount,
        letterSpacing: 4,
      },
    });

    tableTypeText.alpha = 0.12;
    tableTypeText.anchor.set(0.5);
    tableTypeText.position.set(0, 45);

    this.container.addChild(tableTypeText);

    // Show "Waiting for players" message when table is waiting
    if (tableStatus === "waiting") {
      const waitingText = new PIXI.Text({
        text: "Waiting for players\u2026",
        style: {
          fontFamily: FONTS.ui,
          fontSize: 24,
          fontWeight: "500",
          fill: TABLE_COLORS.potAmount,
          letterSpacing: 1,
        },
      });

      waitingText.alpha = 0.25;
      waitingText.anchor.set(0.5);
      waitingText.position.set(0, -30);

      this.container.addChild(waitingText);
    }

    return this.container;
  }

  getContainer() {
    return this.container;
  }
}
