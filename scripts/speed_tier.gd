class_name SpeedTier
## Velocity tiers from the design doc: the faster you go, the harder you hit.
## Speed is measured as a fraction of MovementTuning.max_speed.

enum { IDLE, CRUISE, RUSH, HALO }

const NAMES: Array[String] = ["IDLE", "CRUISE", "RUSH", "HALO"]
## Lowest speed fraction for each tier. Halo also needs halo_hold_time seconds.
const THRESHOLDS: Array[float] = [0.0, 0.25, 0.60, 0.90]
const DAMAGE: Array[float] = [0.8, 1.0, 1.3, 1.6]
const FIRE_RATE: Array[float] = [0.9, 1.0, 1.15, 1.3]
## None, teal, violet, gold (palette: Bone grey, Cyber teal, Electric violet, Candle gold).
const COLORS: Array[Color] = [Color("8c8299"), Color("2fd6c3"), Color("8a5cff"), Color("e8b04b")]
## How far below a tier's threshold you must fall before dropping out of it,
## so the tier doesn't flicker when you hover on a boundary.
const HYSTERESIS := 0.04


static func from_ratio(ratio: float, halo_ready: bool) -> int:
	if ratio >= THRESHOLDS[HALO] and halo_ready:
		return HALO
	if ratio >= THRESHOLDS[RUSH]:
		return RUSH
	if ratio >= THRESHOLDS[CRUISE]:
		return CRUISE
	return IDLE


static func color(tier: int) -> Color:
	return COLORS[tier]
