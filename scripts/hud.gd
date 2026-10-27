extends Control
## Placeholder HUD on the 480 x 270 grid: speed gauge with the four tier
## segments, boost meter, drift charge, style meter, and a debug panel
## (toggle with View/Back or F1).

const FONT_SIZE := 8
const FRAME := Color("4a3f5c")
const DIM := Color("2b2238")
const TEXT := Color("ede6d6")

@export var player: Player

var show_debug := true


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		show_debug = not show_debug


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var t := player.tuning
	var font := ThemeDB.fallback_font
	var tier := player.tier
	var tier_color := SpeedTier.color(tier)

	# Speed gauge, bottom left. The bar runs to boost top speed; the marks are
	# the tier thresholds (25%, 60%, 90% of normal top speed).
	var gauge := Rect2(8, 246, 150, 7)
	var span := t.boost_max_speed
	draw_rect(gauge.grow(1), FRAME)
	draw_rect(gauge, DIM)
	var fill := clampf(player.velocity.length() / span, 0.0, 1.0)
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * fill, gauge.size.y)), tier_color if tier > 0 else Color("8c8299"))
	for i in range(1, 4):
		var x := gauge.position.x + gauge.size.x * SpeedTier.THRESHOLDS[i] * t.max_speed / span
		draw_line(Vector2(x, gauge.position.y - 2), Vector2(x, gauge.end.y + 1), SpeedTier.COLORS[i], 1.0)
	var top_x := gauge.position.x + gauge.size.x * t.max_speed / span
	draw_line(Vector2(top_x, gauge.position.y), Vector2(top_x, gauge.end.y), TEXT, 1.0)
	# Halo charge: fills while you hold 90%+.
	if tier < SpeedTier.HALO and player.halo_timer > 0.0:
		var k := clampf(player.halo_timer / t.halo_hold_time, 0.0, 1.0)
		draw_rect(Rect2(gauge.position.x, gauge.position.y - 4, gauge.size.x * k, 1), SpeedTier.COLORS[3])

	# Boost meter.
	var boost := Rect2(8, 257, 150, 3)
	draw_rect(boost.grow(1), FRAME)
	draw_rect(Rect2(boost.position, Vector2(boost.size.x * player.boost_meter, boost.size.y)), SpeedTier.COLORS[1] if not player.boosting else TEXT)

	# Tier name, multipliers and drift charge.
	var label := "%s  DMG x%.1f  RATE x%.2f" % [SpeedTier.NAMES[tier], SpeedTier.DAMAGE[tier], SpeedTier.FIRE_RATE[tier]]
	_text(font, Vector2(8, 241), label, tier_color if tier > 0 else TEXT)
	for i in 3:
		var lit := player.drifting and player.drift_level > i
		draw_rect(Rect2(164 + i * 7, 247, 5, 5), SpeedTier.COLORS[i + 1] if lit else DIM)
	_text(font, Vector2(164, 262), "DRIFT", TEXT if player.drifting else FRAME)

	# Style meter and hit counter, top left.
	draw_rect(Rect2(8, 8, 80, 3).grow(1), FRAME)
	draw_rect(Rect2(8, 8, 80 * player.style / 100.0, 3), SpeedTier.COLORS[1])
	_text(font, Vector2(8, 21), "STYLE %d   HITS %d" % [int(player.style), player.hits_taken], TEXT)

	if show_debug:
		_draw_debug(font)


func _draw_debug(font: Font) -> void:
	var p := player
	var state := "GRIND" if p.grinding_rail else ("AIR" if p.airborne else "GROUND")
	if p.walk_mode:
		state += " (WALK)"
	var pad_name := Input.get_joy_name(0) if Input.get_connected_joypads().size() > 0 else "no controller found"
	var lines := [
		"speed %d px/s  (%d%% of top)" % [int(p.velocity.length()), int(100.0 * p.velocity.length() / p.tuning.max_speed)],
		"state %s  height %d" % [state, int(p.height)],
		"boost %d%%  chain %s" % [int(p.boost_meter * 100.0), "READY" if p.chain_timer > 0.0 else "-"],
		"pad: %s" % pad_name,
		"",
		"L stick steer   R stick shoot",
		"RT boost   LT drift (release = burst)",
		"A hop   B spin   LB walk",
		"Start restart   View hide this",
	]
	var y := 12.0
	for line in lines:
		_text(font, Vector2(300, y), line, Color("8c8299"))
		y += 9.0


func _text(font: Font, at: Vector2, s: String, color: Color) -> void:
	draw_string(font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color("14111f"))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
