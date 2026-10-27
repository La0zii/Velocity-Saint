class_name Player
extends CharacterBody2D
## The Velocity Saint on their mag-sled. Moves like a vehicle with grip:
## steer, carve, drift, boost, hop, spin, bounce off walls and grind rails.
## The node's position is the point on the floor under the sled; `height`
## is a fake vertical axis used for hops, drawn by lifting the sprite above
## its shadow.

signal tier_changed(tier: int)

const LAYER_WALLS := 1
const LAYER_LOW := 4 # physics layer 3: pews and other low obstacles
const PICKUP_RADIUS := 5.0
const RAIL_HEIGHT := 4.0

@export var tuning: MovementTuning

# Motion
var facing := 0.0
var height := 0.0
var vz := 0.0
var airborne := false
var walk_mode := false

# Drift
var drifting := false
var drift_input := 0.0
var drift_time := 0.0
var drift_level := 0

# Boost
var boosting := false
var boost_input := 0.0
var boost_meter := 1.0
var _boost_regen_timer := 0.0
var _was_boosting := false
var chain_timer := 0.0

# Hop, trick, rails
var _hop_buffer := 0.0
var _coyote := 0.0
var trick_timer := 0.0
var trick_spin := 0.0
var _trick_in_air := false
var grinding_rail: Rail = null
var _grind_dir := 1.0

# Tiers, style, damage
var tier := SpeedTier.IDLE
var halo_timer := 0.0
var style := 0.0
var iframes := 0.0
var hits_taken := 0
var _flash := 0.0
var _fire_cooldown := 0.0
var _spark_timer := 0.0
var _ghost_timer := 0.0
var _pad := 0

var aim := Vector2.ZERO


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	add_to_group("player")
	collision_layer = 2
	collision_mask = LAYER_WALLS | LAYER_LOW
	motion_mode = MOTION_MODE_FLOATING


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad = event.device


func _physics_process(delta: float) -> void:
	var t := tuning
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	drift_input = Input.get_action_strength("drift")
	boost_input = Input.get_action_strength("boost")
	walk_mode = Input.is_action_pressed("walk") and grinding_rail == null
	if Input.is_action_just_pressed("hop"):
		_hop_buffer = t.input_buffer
	if Input.is_action_just_pressed("trick"):
		_start_trick()

	chain_timer = maxf(chain_timer - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)

	if grinding_rail:
		_boost(delta)
		_grind(delta)
	else:
		_steer(delta, move)
		_drift(delta)
		_boost(delta)
		_apply_speed_cap(delta)
	_hop_and_height(delta)
	if grinding_rail == null:
		_move(delta)
		if airborne:
			_try_catch_rail()
	_update_trick(delta)
	_update_tier(delta)
	_shoot(delta)
	style = maxf(style - 4.0 * delta, 0.0)
	_emit_effects(delta)
	queue_redraw()


# --- Steering ----------------------------------------------------------------

func _steer(delta: float, move: Vector2) -> void:
	var t := tuning
	var speed := velocity.length()
	var ratio := clampf(speed / t.max_speed, 0.0, 1.0)
	var control := t.air_control if airborne else 1.0
	var mag := move.length()
	var cap := t.walk_max_speed if walk_mode else t.max_speed

	if mag > 0.0:
		var target := move.angle()
		if (speed < t.pivot_speed or walk_mode) and not airborne:
			facing = target
		else:
			var rate := lerpf(t.turn_rate_slow, t.turn_rate_fast, ratio)
			if drifting:
				rate *= t.drift_turn_mult
			facing = rotate_toward(facing, target, rate * control * delta)
		var fwd := Vector2.from_angle(facing)
		if speed > 1.0 and move.dot(velocity / speed) < -0.3:
			# Stick held against the motion: brake.
			velocity = velocity.move_toward(Vector2.ZERO, t.reverse_brake * mag * control * delta)
		elif speed < cap:
			velocity += fwd * t.accel * mag * control * delta
	elif not airborne:
		# Friction falls off quickly with speed so fast glides carry far.
		var friction := lerpf(t.coast_friction_slow, t.coast_friction_fast, sqrt(ratio))
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if airborne:
		return
	# Grip: bleed off sideways sliding, but keep most of the speed so carving
	# through a turn redirects momentum instead of killing it.
	var fwd := Vector2.from_angle(facing)
	var before_grip := velocity.length()
	var forward_speed := velocity.dot(fwd)
	var lateral := velocity - fwd * forward_speed
	var g := t.grip * 2.0 if walk_mode else lerpf(t.grip, t.drift_grip, drift_input if drifting else 0.0)
	var gripped := fwd * forward_speed + lateral * exp(-g * delta)
	if gripped.length() > 0.01:
		velocity = gripped.normalized() * lerpf(gripped.length(), before_grip, t.carve_keep)


# --- Drift -------------------------------------------------------------------

func _drift(delta: float) -> void:
	var t := tuning
	var speed := velocity.length()
	var holding := drift_input > 0.25 and not walk_mode
	var want := holding and speed > t.drift_min_speed and (not airborne or drifting)
	if want:
		if not drifting:
			drifting = true
			drift_time = 0.0
			drift_level = 0
		if not airborne:
			# Charge faster the more sideways you are sliding.
			var slip := absf(Vector2.from_angle(facing).cross(velocity / speed))
			drift_time += delta * (0.5 + slip * 1.5) * drift_input
			var level := 0
			for threshold in t.drift_level_times:
				if drift_time >= threshold:
					level += 1
			if level > drift_level:
				drift_level = level
				FX.get_fx(self).ring(global_position, _drift_color(), 6.0 + level * 3.0)
				_rumble(0.15 * level, 0.0, 0.08)
	elif drifting:
		if holding:
			# Dropped below drift speed: fizzle out without a cash-in.
			drifting = false
			drift_level = 0
		else:
			_cash_in()


func _cash_in() -> void:
	var t := tuning
	drifting = false
	if drift_level > 0 and not airborne:
		var fwd := Vector2.from_angle(facing)
		var speed := velocity.length()
		velocity = velocity.lerp(fwd * speed, 0.75) + fwd * t.drift_burst[drift_level - 1]
		chain_timer = t.chain_window
		_add_style(8.0 * drift_level)
		var fx := FX.get_fx(self)
		fx.burst(global_position, 10 + drift_level * 6, _drift_color(), 90.0)
		fx.text(global_position + Vector2(0, -20), ["", "DRIFT", "DRIFT+", "DRIFT++"][drift_level], _drift_color())
		_shake(1.0 + drift_level)
		_rumble(0.3, 0.2 * drift_level, 0.12)
	drift_time = 0.0
	drift_level = 0


func _drift_color() -> Color:
	return [Color("8c8299"), SpeedTier.COLORS[1], SpeedTier.COLORS[2], SpeedTier.COLORS[3]][drift_level]


# --- Boost -------------------------------------------------------------------

func _boost(delta: float) -> void:
	var t := tuning
	boosting = boost_input > 0.1 and boost_meter > 0.0 and not walk_mode
	var fwd := Vector2.from_angle(facing)
	if boosting:
		if not _was_boosting and chain_timer > 0.0:
			velocity += fwd * t.chain_bonus
			chain_timer = 0.0
			_add_style(10.0)
			FX.get_fx(self).text(global_position + Vector2(0, -26), "CHAIN!", SpeedTier.COLORS[3])
			_shake(2.0)
			_rumble(0.2, 0.5, 0.15)
		if velocity.length() < t.boost_max_speed:
			velocity += fwd * t.boost_accel * boost_input * delta
		boost_meter = maxf(boost_meter - t.boost_drain * boost_input * delta, 0.0)
		_boost_regen_timer = t.boost_regen_delay
	else:
		_boost_regen_timer -= delta
		if _boost_regen_timer <= 0.0:
			boost_meter = minf(boost_meter + t.boost_regen * delta, 1.0)
	_was_boosting = boosting


func _apply_speed_cap(delta: float) -> void:
	var t := tuning
	var cap := t.boost_max_speed if boosting else t.max_speed
	var drag := t.over_cap_drag
	if walk_mode:
		cap = t.walk_max_speed
		drag = 8.0
	var speed := velocity.length()
	if speed > cap:
		velocity = velocity / speed * (cap + (speed - cap) * exp(-drag * delta))


# --- Hop, height, tricks -----------------------------------------------------

func _hop_and_height(delta: float) -> void:
	var t := tuning
	_hop_buffer = maxf(_hop_buffer - delta, 0.0)
	_coyote = maxf(_coyote - delta, 0.0)
	if _hop_buffer > 0.0 and (not airborne or _coyote > 0.0 or grinding_rail):
		_hop_buffer = 0.0
		if grinding_rail:
			grinding_rail = null
			height = RAIL_HEIGHT
			_add_style(4.0)
		_start_hop(t.hop_velocity)
	if airborne:
		vz -= t.gravity * delta
		height += vz * delta
		if height <= 0.0:
			_land()


func _start_hop(up_speed: float) -> void:
	airborne = true
	vz = up_speed
	_coyote = 0.0
	FX.get_fx(self).burst(global_position, 5, Color("8c8299"), 30.0)


## Called by ramps when you ride onto them.
func launch_from_ramp(direction: Vector2) -> void:
	var t := tuning
	_start_hop(t.hop_velocity * t.ramp_launch_mult)
	velocity += direction * t.ramp_speed_bonus
	_add_style(6.0)
	_rumble(0.2, 0.3, 0.1)


func _land() -> void:
	height = 0.0
	vz = 0.0
	airborne = false
	var fx := FX.get_fx(self)
	fx.burst(global_position, 6, Color("8c8299"), 40.0)
	if trick_timer > 0.0 and _trick_in_air:
		# Landed mid-spin: bail.
		velocity *= tuning.bail_speed_keep
		trick_timer = 0.0
		trick_spin = 0.0
		style = 0.0
		fx.text(global_position + Vector2(0, -20), "BAIL", Color("e2367a"))
		_shake(3.0)
		_rumble(0.6, 0.3, 0.2)
	_trick_in_air = false


func _start_trick() -> void:
	if trick_timer > 0.0:
		return
	trick_timer = tuning.trick_duration
	_trick_in_air = airborne or grinding_rail != null
	iframes = maxf(iframes, tuning.trick_duration * 0.8)


func _update_trick(delta: float) -> void:
	if trick_timer <= 0.0:
		return
	trick_timer -= delta
	trick_spin = TAU * (1.0 - maxf(trick_timer, 0.0) / tuning.trick_duration)
	if trick_timer <= 0.0:
		trick_spin = 0.0
		if _trick_in_air:
			_add_style(15.0)
			chain_timer = tuning.chain_window
			FX.get_fx(self).text(global_position + Vector2(0, -24), "360!", SpeedTier.COLORS[1])
		else:
			_add_style(3.0)


# --- Rails -------------------------------------------------------------------

func _try_catch_rail() -> void:
	var t := tuning
	if vz > 40.0 or height > RAIL_HEIGHT + 16.0:
		return
	var speed := velocity.length()
	if speed < 40.0:
		return
	for node in get_tree().get_nodes_in_group("rails"):
		var rail := node as Rail
		var a := rail.global_a()
		var b := rail.global_b()
		var p := Geometry2D.get_closest_point_to_segment(global_position, a, b)
		if p.distance_to(global_position) > t.rail_snap_distance:
			continue
		var dir := (b - a).normalized()
		if absf(velocity.dot(dir)) / speed < cos(deg_to_rad(t.rail_max_angle_deg)):
			continue
		grinding_rail = rail
		_grind_dir = signf(velocity.dot(dir))
		global_position = p
		airborne = false
		height = RAIL_HEIGHT
		vz = 0.0
		drifting = false
		drift_level = 0
		velocity = dir * _grind_dir * maxf(speed, t.grind_min_speed)
		facing = velocity.angle()
		_add_style(6.0)
		FX.get_fx(self).text(global_position + Vector2(0, -20), "GRIND", SpeedTier.COLORS[2])
		_rumble(0.3, 0.1, 0.1)
		return


func _grind(delta: float) -> void:
	var t := tuning
	var a := grinding_rail.global_a()
	var b := grinding_rail.global_b()
	var along := (b - a).normalized()
	var dir := along * _grind_dir
	var speed := maxf(velocity.dot(dir), t.grind_min_speed) + t.grind_accel * delta
	speed = minf(speed, t.boost_max_speed)
	velocity = dir * speed
	facing = dir.angle()
	height = RAIL_HEIGHT
	var next := global_position + velocity * delta
	var progress := (next - a).dot(along)
	if progress < 0.0 or progress > a.distance_to(b):
		# Rode off the end: drop off with a little coyote time to hop.
		grinding_rail = null
		airborne = true
		vz = 0.0
		_coyote = t.coyote_time
	global_position = next
	_add_style(5.0 * delta)


# --- Collision ---------------------------------------------------------------

func _move(delta: float) -> void:
	collision_mask = LAYER_WALLS | (LAYER_LOW if height < tuning.low_clear_height else 0)
	var motion := velocity * delta
	for i in 3:
		var col := move_and_collide(motion)
		if col == null:
			break
		var remaining := col.get_remainder().length()
		_on_wall_hit(col)
		if velocity.length() < 1.0:
			break
		motion = velocity.normalized() * remaining


func _on_wall_hit(col: KinematicCollision2D) -> void:
	var t := tuning
	var n := col.get_normal()
	var speed := velocity.length()
	if speed < 1.0:
		return
	var into := -velocity.dot(n) / speed # 1 = head-on, 0 = grazing
	if into <= 0.05:
		velocity = velocity.slide(n)
		return
	var fx := FX.get_fx(self)
	if into >= t.head_on_threshold and speed >= t.min_bounce_speed:
		# Head-on: hard stop with a little knock-back.
		velocity = n * speed * t.head_on_rebound
		drifting = false
		drift_level = 0
		fx.burst(col.get_position(), 8, Color("ede6d6"), 60.0)
		_shake(clampf(speed / 60.0, 1.0, 5.0))
		_rumble(0.5, 0.6 * speed / t.max_speed, 0.15)
	elif speed >= t.min_bounce_speed:
		# Glancing: bounce off and keep most of the speed. The sled turns to
		# face the new direction so grip doesn't eat the bounce.
		velocity = velocity.bounce(n) * t.bounce_keep
		facing = velocity.angle()
		chain_timer = t.chain_window
		_add_style(5.0)
		fx.sparks(col.get_position(), n, 10, SpeedTier.color(tier), 110.0)
		_shake(1.5)
		_rumble(0.4, 0.15, 0.08)
	else:
		velocity = velocity.slide(n)


## Hazards and enemies call this. Drops you one speed tier.
func take_hit(from_position: Vector2) -> bool:
	if iframes > 0.0:
		return false
	iframes = tuning.hit_iframes
	hits_taken += 1
	style = 0.0
	_flash = 0.15
	if tier > SpeedTier.IDLE:
		var limit_ratio := SpeedTier.THRESHOLDS[tier] - SpeedTier.HYSTERESIS - 0.03
		if tier == SpeedTier.HALO:
			limit_ratio = SpeedTier.THRESHOLDS[SpeedTier.HALO] - SpeedTier.HYSTERESIS - 0.04
		velocity = velocity.limit_length(maxf(limit_ratio, 0.0) * tuning.max_speed)
		tier -= 1
		tier_changed.emit(tier)
	halo_timer = 0.0
	var away := (global_position - from_position).normalized()
	velocity += away * 50.0
	var fx := FX.get_fx(self)
	fx.burst(global_position, 16, Color("e2367a"), 100.0)
	fx.text(global_position + Vector2(0, -24), "HIT  -1 TIER", Color("e2367a"))
	_shake(5.0)
	_rumble(0.8, 0.8, 0.25)
	_hit_stop(0.07)
	return true


# --- Speed tiers, style, shooting --------------------------------------------

func _update_tier(delta: float) -> void:
	var ratio := velocity.length() / tuning.max_speed
	if ratio >= SpeedTier.THRESHOLDS[SpeedTier.HALO]:
		halo_timer += delta
	elif ratio < SpeedTier.THRESHOLDS[SpeedTier.HALO] - SpeedTier.HYSTERESIS:
		halo_timer = 0.0
	var halo_ready := halo_timer >= tuning.halo_hold_time
	var candidate := SpeedTier.from_ratio(ratio, halo_ready)
	var new_tier := tier
	if candidate > tier:
		new_tier = candidate
	elif candidate < tier and ratio < SpeedTier.THRESHOLDS[tier] - SpeedTier.HYSTERESIS:
		new_tier = SpeedTier.from_ratio(ratio + SpeedTier.HYSTERESIS, halo_ready)
	if tier == SpeedTier.HALO and new_tier < SpeedTier.HALO:
		halo_timer = 0.0
	if new_tier != tier:
		if new_tier == SpeedTier.HALO:
			FX.get_fx(self).ring(global_position, SpeedTier.COLORS[3], 24.0)
			FX.get_fx(self).text(global_position + Vector2(0, -28), "HALO", SpeedTier.COLORS[3])
			_rumble(0.3, 0.3, 0.2)
		tier = new_tier
		tier_changed.emit(tier)


func _add_style(amount: float) -> void:
	style = minf(style + amount, 100.0)


func damage_multiplier() -> float:
	return SpeedTier.DAMAGE[tier]


func _shoot(delta: float) -> void:
	_fire_cooldown -= delta
	if aim.length() < 0.35 or _fire_cooldown > 0.0:
		return
	var t := tuning
	_fire_cooldown = 1.0 / (t.base_fire_rate * SpeedTier.FIRE_RATE[tier])
	var dir := aim.normalized()
	var bullet := Bullet.new()
	bullet.velocity = dir * t.bullet_speed + velocity * t.bullet_inherit
	bullet.damage = t.base_damage * SpeedTier.DAMAGE[tier]
	bullet.color = SpeedTier.color(tier) if tier > SpeedTier.IDLE else Color("ede6d6")
	bullet.position = global_position + dir * 6.0
	bullet.height = height + 6.0
	get_parent().add_child(bullet)


# --- Feedback ----------------------------------------------------------------

func _emit_effects(delta: float) -> void:
	var fx := FX.get_fx(self)
	var fwd := Vector2.from_angle(facing)
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.03
		if drifting and not airborne:
			var side := fwd.orthogonal()
			for s in [-1.0, 1.0]:
				fx.sparks(global_position - fwd * 6.0 + side * 3.0 * s, -fwd, 1, _drift_color(), 50.0)
		if grinding_rail:
			fx.sparks(global_position, -fwd, 2, SpeedTier.COLORS[3], 70.0)
		if boosting:
			fx.sparks(global_position - fwd * 8.0 + Vector2(0, -height), -fwd, 1, SpeedTier.color(maxi(tier, 1)), 60.0, 0.3)
	_ghost_timer -= delta
	if tier == SpeedTier.HALO and _ghost_timer <= 0.0:
		_ghost_timer = 0.05
		fx.ghost(global_position + Vector2(0, -height), facing + trick_spin, SpeedTier.COLORS[3])


func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_shake"):
		cam.add_shake(amount)


func _rumble(weak: float, strong: float, duration: float) -> void:
	var k := tuning.rumble_strength
	if k > 0.0:
		Input.start_joy_vibration(_pad, clampf(weak * k, 0.0, 1.0), clampf(strong * k, 0.0, 1.0), duration)


func _hit_stop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# --- Placeholder drawing -----------------------------------------------------

func _draw() -> void:
	var tier_color := SpeedTier.color(tier)
	modulate = Color(1, 1, 1, 0.45) if iframes > 0.0 and int(iframes * 20.0) % 2 == 0 else Color.WHITE

	# Shadow stays on the floor and shrinks as you rise.
	var shadow := clampf(1.0 - height / 60.0, 0.45, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 8.0 * shadow, Color(0, 0, 0, 0.5))
	if airborne or grinding_rail:
		# Outline the shadow in the air so you can always read where you'll land.
		draw_arc(Vector2.ZERO, 8.0 * shadow, 0.0, TAU, 16, Color(Color("8c8299"), 0.6), 1.0)

	draw_set_transform(Vector2(0, -height), facing + trick_spin, Vector2.ONE)
	# Thruster flame.
	if boosting or tier > SpeedTier.IDLE:
		var flame := 3.0 + 5.0 * boost_input + 2.0 * tier
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -2), Vector2(-7 - flame, 0), Vector2(-7, 2)]), tier_color if tier > 0 else SpeedTier.COLORS[1])
	# Coffin-lid sled.
	var sled := PackedVector2Array([Vector2(9, 0), Vector2(5, -4), Vector2(-7, -3), Vector2(-7, 3), Vector2(5, 4)])
	draw_colored_polygon(sled, Color("4a3f5c"))
	sled.append(sled[0])
	draw_polyline(sled, Color("e8b04b"), 1.0)
	# Rider: cloak streams behind with speed, hood and visor in front.
	var ratio := clampf(velocity.length() / tuning.max_speed, 0.0, 1.5)
	var lean := 0.0
	if drifting:
		lean = 1.5 * signf(Vector2.from_angle(facing).cross(velocity))
	draw_colored_polygon(PackedVector2Array([Vector2(1, -3 + lean), Vector2(-3 - 5.0 * ratio, -2 + lean), Vector2(-3 - 5.0 * ratio, 2 + lean), Vector2(1, 3 + lean)]), Color("2b2238"))
	draw_circle(Vector2(1, lean), 3.5, Color("2b2238"))
	draw_line(Vector2(3, -1.5 + lean), Vector2(3, 1.5 + lean), Color("2fd6c3"), 1.0)
	draw_set_transform(Vector2(0, -height), 0.0, Vector2.ONE)
	# Halo ring brightens with tier.
	var halo_alpha: float = [0.25, 0.5, 0.8, 1.0][tier]
	draw_arc(Vector2(0, -7), 4.0, 0.0, TAU, 16, Color(tier_color, halo_alpha), 1.0)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 9.0, Color(Color("e2367a"), 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
