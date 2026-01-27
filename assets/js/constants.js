// Poker canvas constants - single source of truth for positioning and offsets

// ============================================================================
// BASE LAYOUT
// ============================================================================
export const BASE_WIDTH = 1300;
export const BASE_HEIGHT = 1100;
export const TABLE_RADIUS_X = 450;
export const TABLE_RADIUS_Y = 300;

// ============================================================================
// CARD DIMENSIONS
// ============================================================================
export const CARD_WIDTH = 80;
export const CARD_HEIGHT = 110;
export const CARD_BORDER_RADIUS = 8;
export const COMMUNITY_CARD_SPACING = CARD_WIDTH + 10;
export const HOLE_CARD_SPACING = CARD_WIDTH;

// Card back pattern dimensions
export const CARD_PATTERN = {
  x: 5,
  y: 5,
  width: 70,
  height: 100,
  borderRadius: 6,
};

// Card diamond decoration
export const CARD_DIAMOND_COORDS = {
  center: { x: 35, y: 15 },
  right: { x: 50, y: 50 },
  bottom: { x: 35, y: 85 },
  left: { x: 20, y: 50 },
};

// ============================================================================
// CARD TYPOGRAPHY
// ============================================================================
export const CARD_FONT_SIZES = {
  rank: 30,
  smallSuit: 30,
  bigSuit: 70,
};

export const CARD_TEXT_POSITIONS = {
  rank: { x: 6, y: 4 },
  smallSuit: { x: 8, y: 32 },
  bigSuit: { x: 52, y: 75 },
};

// ============================================================================
// CARD COLORS
// ============================================================================
export const CARD_COLORS = {
  // Face down card
  backBg: 0x1a365d,
  backBorder: 0x2d4a6f,
  backPattern: 0x152951,
  backDiamond: 0x3b5998,

  // Face up card
  faceBg: 0xffffff,
  faceBorder: 0x333333,
  red: 0xdc2626,
  black: 0x1f2937,
};

export const CARD_SUIT_SYMBOLS = {
  hearts: "♥",
  diamonds: "♦",
  clubs: "♣",
  spades: "♠",
};

// ============================================================================
// CHIP DIMENSIONS
// ============================================================================
export const CHIP_RADIUS = 20;
export const CHIP_SHADOW_OFFSET = { x: 2, y: 2 };
export const CHIP_STACK_OFFSET = 4;
export const CHIP_NOTCH_COUNT = 8;
export const CHIP_NOTCH_RADIUS = 16;
export const CHIP_NOTCH_SIZE = 3;
export const CHIP_INNER_RING_RADIUS = 12;

export const CHIP_VALUES = [100, 25, 5, 1];

export const CHIP_COLORS = {
  100: 0x1a1a1a, // Black
  25: 0x059669, // Emerald green
  5: 0xdc2626, // Red
  1: 0xf5f5f5, // Off-white
};

// ============================================================================
// PARTICIPANT / HOOD LAYOUT
// ============================================================================
export const HOOD_WIDTH = 160;
export const HOOD_HEIGHT = 84;
export const HOOD_BORDER_RADIUS = 20;
export const HOOD_PADDING = 14;
export const CARD_OVERLAP = 70;
export const CARD_OFFSET_X = 0;

// ============================================================================
// PARTICIPANT COLORS
// ============================================================================
export const PARTICIPANT_COLORS = {
  hoodBg: 0x1a1a1a,
  hoodBgFolded: 0x2a2a2a,
  border: 0x4a4a4a,
  borderFolded: 0x404040,
  divider: 0x3a3a3a,
  text: 0xffffff,
  textFolded: 0x888888,
  chips: 0x4ade80,
  chipsFolded: 0x666666,
  activeGlow: 0xf4d03f,
  timerGreen: 0x4ade80,
  timerYellow: 0xfbbf24,
  timerRed: 0xef4444,
  timerBg: 0x333333,
};

// ============================================================================
// ANIMATION CONSTANTS
// ============================================================================
export const ANIMATION_START_Y = 200;

// ============================================================================
// LEGACY (to be removed eventually)
// ============================================================================
export const CARD_Y_POSITION = -60;
export const BET_AREA_OFFSET = { x: 30, y: -110 };
