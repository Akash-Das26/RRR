class_name Palette
extends RefCounted
## The game's art direction, in one file.
##
## Everything visual in this project is drawn procedurally from these constants,
## so the palette is the whole style guide. No third-party sprites, no ripped
## art: "stylized cinematic ancient Persian fantasy" is expressed as warm
## sandstone architecture shot through with cold temporal energy.

# --- Architecture -----------------------------------------------------------
const STONE_DEEP := Color("4a3524")
const STONE_SHADE := Color("6b4d33")
const STONE_BASE := Color("9d7449")
const STONE_LIGHT := Color("c49a63")
const STONE_EDGE := Color("e0bd85")

# --- Temporal energy --------------------------------------------------------
const TEMPORAL_CORE := Color("eafcff")
const TEMPORAL_GLOW := Color("7fe3ff")
const TEMPORAL_DEEP := Color("2b6cff")
const TEMPORAL_FADE := Color("8be3ff", 0.28)

# --- Characters -------------------------------------------------------------
const PRINCE_SASH := Color("d8e8f2")
const PRINCE_TUNIC := Color("e8e2d4")
const PRINCE_SKIN := Color("a86b45")
const BLADE := Color("dfe9f2")

# --- Enemies ----------------------------------------------------------------
const GUARD_ARMOUR := Color("8b2f2f")
const GUARD_TRIM := Color("d9a03c")
const SHADOW_BODY := Color("2a1b3d")
const SHADOW_GLOW := Color("b06cff")

# --- UI ---------------------------------------------------------------------
const UI_TEXT := Color("e8f4ff")
const UI_DIM := Color("9fb3c8")
const UI_PANEL := Color("0e0b18", 0.82)
const UI_HEALTH := Color("d4483f")
const UI_ACCENT := Color("7fe3ff")
const UI_WARN := Color("e8b24a")

# --- World ------------------------------------------------------------------
const SKY_TOP := Color("120d1c")
const SKY_BOTTOM := Color("2a1a2e")
const HAZARD := Color("ff5a3c")


## Deterministic pseudo-random tint so procedural speckles are stable between
## runs (important: the headless smoke test compares nothing visual, but a
## flickering world would still be a bug).
static func jitter(base: Color, rng: RandomNumberGenerator, amount: float = 0.06) -> Color:
	var delta := rng.randf_range(-amount, amount)
	return Color(
		clampf(base.r + delta, 0.0, 1.0),
		clampf(base.g + delta, 0.0, 1.0),
		clampf(base.b + delta, 0.0, 1.0),
		base.a
	)
