// Poker canvas constants - single source of truth for positioning and offsets
// Design direction: "Cellar" — editorial casino warmth (oxblood + forest felt + brass)

// ============================================================================
// BASE LAYOUT
// ============================================================================
export const BASE_WIDTH = 1300;
export const BASE_HEIGHT = 1100;
export const TABLE_RADIUS_X = 450;
export const TABLE_RADIUS_Y = 300;

// Rectangular table dimensions
export const TABLE_WIDTH = 1000;
export const TABLE_HEIGHT = 545;
export const TABLE_BORDER_RADIUS = 450;

// ============================================================================
// CARD DIMENSIONS
// ============================================================================
export const CARD_WIDTH = 90;
export const CARD_HEIGHT = 124;
export const CARD_BORDER_RADIUS = 9;
export const COMMUNITY_CARD_SPACING = CARD_WIDTH + 11;
export const HOLE_CARD_SPACING = CARD_WIDTH;

// Card back pattern dimensions
export const CARD_PATTERN = {
  x: 5,
  y: 5,
  width: 80,
  height: 114,
  borderRadius: 7,
};

// Card diamond decoration
export const CARD_DIAMOND_COORDS = {
  center: { x: 40, y: 17 },
  right: { x: 56, y: 56 },
  bottom: { x: 40, y: 96 },
  left: { x: 23, y: 56 },
};

// ============================================================================
// CARD TYPOGRAPHY
// ============================================================================
export const CARD_FONT_SIZES = {
  rank: 34,
  smallSuit: 34,
  bigSuit: 78,
};

export const CARD_TEXT_POSITIONS = {
  rank: { x: 7, y: 4 },
  smallSuit: { x: 9, y: 36 },
  bigSuit: { x: 58, y: 84 },
};

// ============================================================================
// CARD COLORS — Cellar direction
// ============================================================================
export const CARD_COLORS = {
  // Face down card — tartan oxblood pattern
  backBg: 0x5c2420,
  backBorder: 0x3a1510,
  backPattern: 0x4a1c18,
  backStripe1: 0x6b2c28,
  backStripe2: 0x4a1c18,
  backInnerBorder: 0xffffff,

  // Face up card
  faceBg: 0xffffff,
  faceGradientEnd: 0xf4f1ea,
  faceBorder: 0xe0dcd4,
  red: 0xb53236,
  black: 0x1a1a1a,
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

export const CHIP_VALUES = [1000, 100, 25, 5, 1];

export const CHIP_COLORS = {
  1000: 0xb8902f, // Brass
  100: 0x1a1a1a, // Black
  25: 0x2d6a4f, // Forest green
  5: 0xb53236, // Oxblood red
  1: 0xf4f1ea, // Bone white
};

export const CHIP_EDGE_COLORS = {
  1000: 0x6b5117,
  100: 0x000000,
  25: 0x163d2a,
  5: 0x7a1c20,
  1: 0xcfc8ba,
};

// ============================================================================
// TABLE COLORS — Cellar direction
// ============================================================================
export const TABLE_COLORS = {
  // Room background
  roomBg: 0x1a1310,
  roomPatternShadow: 0x100b08,
  roomPatternMain: 0x201510,

  // Felt — richer, more saturated greens
  felt: 0x1e4a35,
  feltMid: 0x2d6a4f,
  feltGlow: 0x3a8262,
  feltCenter: 0x44926c,

  // Inner shadow on felt
  feltShadowInner: 0x0a1f15,
  feltShadowInnerAlpha: 0.6,

  // Table rail — deeper contrast
  outerRim: 0x251810,
  outerRimBottom: 0x140c08,
  outerRimHighlight: 0x3a2a1e,
  innerAccent: 0xc4a43a,
  innerAccentAlpha: 0.45,

  // Outer shadow
  shadowColor: 0x000000,
  shadowAlpha: 0.5,

  // Pot text
  potLabel: 0xc4a43a,
  potAmount: 0xf4f1ea,
};

// ============================================================================
// PARTICIPANT / HOOD LAYOUT
// ============================================================================
export const HOOD_WIDTH = 180;
export const HOOD_HEIGHT = 95;
export const HOOD_BORDER_RADIUS = 12;
export const HOOD_PADDING = 12;
export const CARD_OVERLAP = 79;
export const CARD_OFFSET_X = 0;

// Avatar
export const AVATAR_SIZE = 30;
export const AVATAR_SIZE_HERO = 38;

// ============================================================================
// PARTICIPANT COLORS — Cellar direction
// ============================================================================
export const PARTICIPANT_COLORS = {
  hoodBg: 0x0f0f12,
  hoodBgAlpha: 0.88,
  hoodBgFolded: 0x0f0f12,
  hoodBgFoldedAlpha: 0.55,
  border: 0x3a3428,
  borderFolded: 0x2a2620,
  borderActive: 0xc4a43a,
  divider: 0x3a3428,
  text: 0xc8c0b0,
  textFolded: 0x7a7468,
  chips: 0xc4a43a,
  chipsFolded: 0x5a5448,
  activeGlow: 0xc4a43a,
  activeGlowAlpha: 0.25,
  timerGreen: 0x4ade80,
  timerYellow: 0xfbbf24,
  timerRed: 0xef4444,
  timerBg: 0x2a2620,
  positionBadgeBg: 0x2a2620,
  positionBadgeBorder: 0x3a3428,
  positionBadgeText: 0xc4a43a,
  allInText: 0xc4a43a,
  actionLabelBg: 0x2a2620,
  actionLabelBorder: 0x3a3428,
  actionLabelText: 0x7a7468,
  actionLabelAllIn: 0xc4a43a,
  sittingOutText: 0x7a7468,
};

// Action indicator colors — Cellar palette
export const ACTION_INDICATOR_COLORS = {
  RAISE: 0xc4a43a,
  CALL: 0x4ade80,
  CHECK: 0x60a5fa,
  FOLD: 0x8a2f20,
  "ALL IN": 0xc4a43a,
  AWAY: 0x7a7468,
  "I'M BACK": 0x4ade80,
};

// ============================================================================
// DEALER BUTTON — Cellar (brass)
// ============================================================================
export const DEALER_BUTTON = {
  bgGradientTop: 0xf4f1ea,
  bgGradientBottom: 0xd8d2c0,
  border: 0x8a7a55,
  text: 0x3a2a14,
  shadow: 0x000000,
  shadowAlpha: 0.4,
  radius: 14,
};

// ============================================================================
// EMPTY SEAT
// ============================================================================
export const EMPTY_SEAT_COLORS = {
  bg: 0x0f0f12,
  bgAlpha: 0.6,
  border: 0x3a3428,
  borderAlpha: 0.5,
  labelText: 0x7a7468,
  openText: 0xc4a43a,
  hoverBg: 0x1a1814,
  hoverBgAlpha: 0.8,
  hoverBorder: 0xc4a43a,
};

// ============================================================================
// FONTS
// ============================================================================
export const FONTS = {
  ui: "'DM Sans', system-ui, sans-serif",
  display: "'Bodoni Moda', 'Times New Roman', serif",
  mono: "'IBM Plex Mono', monospace",
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
