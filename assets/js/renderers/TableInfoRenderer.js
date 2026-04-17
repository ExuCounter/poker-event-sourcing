import * as PIXI from "pixi.js";
import { TABLE_HEIGHT } from "../constants.js";

export class TableInfoRenderer {
  constructor(getState, getLobbyState) {
    this.getState = getState;
    this.getLobbyState = getLobbyState;
    this.container = new PIXI.Container();
  }

  render() {
    this.container.removeChildren();

    const state = this.getState();
    const lobbyState = this.getLobbyState();
    const tableType = lobbyState.tableType;
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

    const tableTypeText = new PIXI.Text({
      text: displayParts.join(", "),
      style: {
        fontFamily: "Arial, sans-serif",
        fontSize: 38,
        fontWeight: "600",
        fill: 0xffffff,
        letterSpacing: 1,
      },
    });

    tableTypeText.alpha = 0.12;
    tableTypeText.anchor.set(0.5);
    tableTypeText.position.set(0, 45);

    this.container.addChild(tableTypeText);

    return this.container;
  }

  getContainer() {
    return this.container;
  }
}
