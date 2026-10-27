extends SceneTree
## Headless smoke test for the movement prototype. Loads the test room,
## drives the sled with simulated input and checks the big behaviours.
## Run from the project folder:
##   godot --headless -s res://tests/movement_smoke_test.gd

var room: Node
var player: Player
var failures := 0


func _initialize() -> void:
	room = load("res://scenes/test_room.tscn").instantiate()
	root.add_child(room)
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	player = get_first_node_in_group("player")
	var t := player.tuning

	# Accelerate to the right in open floor.
	_reset(Vector2(100, 272), Vector2.ZERO)
	Input.action_press("move_right", 1.0)
	await _frames(90)
	_check("reaches near top speed", player.velocity.length() > t.max_speed * 0.9, "%s at %s, hits %d" % [player.velocity.length(), player.position, player.hits_taken])
	_check("speed tier is RUSH", player.tier == SpeedTier.RUSH, SpeedTier.NAMES[player.tier])
	Input.action_release("move_right")

	# Coasting keeps momentum for a while.
	_reset(Vector2(100, 200), Vector2(200, 0))
	await _frames(30)
	_check("coasting keeps most speed after 0.5 s", player.velocity.length() > 150.0, player.velocity.length())

	# Halo: hold 90%+ for 2 s (start fast, carve around with the stick held).
	_reset(Vector2(100, 272), Vector2(t.max_speed, 0))
	player.facing = 0.0
	Input.action_press("move_right", 1.0)
	player.position = Vector2(60, 340)
	player.velocity = Vector2(t.max_speed, 0)
	var reached_halo := false
	for i in 150:
		await physics_frame
		# Keep the sled in the open by teleporting back along the lane.
		if player.position.x > 600:
			player.position.x = 60
		player.position.y = 340
		if player.tier == SpeedTier.HALO:
			reached_halo = true
			break
	Input.action_release("move_right")
	_check("reaches HALO after holding speed", reached_halo, player.halo_timer)

	# Getting hit drops one tier.
	var before := player.tier
	player.iframes = 0.0
	player.take_hit(player.global_position + Vector2(10, 0))
	await physics_frame
	_check("hit drops one tier", player.tier == before - 1, "%s -> %s" % [SpeedTier.NAMES[before], SpeedTier.NAMES[player.tier]])
	player.iframes = 0.0

	# Drift then release gives a burst above normal top speed.
	_reset(Vector2(80, 240), Vector2(200, 0))
	player.facing = 0.0
	Input.action_press("move_up", 0.6)
	Input.action_press("move_right", 0.8)
	Input.action_press("drift", 1.0)
	await _frames(55)
	var level := player.drift_level
	Input.action_release("drift")
	await _frames(2)
	Input.action_release("move_up")
	Input.action_release("move_right")
	_check("drift charges at least level 1", level >= 1, level)
	_check("drift cash-in bursts past top speed", player.velocity.length() > t.max_speed, player.velocity.length())

	# Boost pushes past normal top speed and drains the meter.
	_reset(Vector2(80, 400), Vector2(200, 0))
	player.facing = 0.0
	player.boost_meter = 1.0
	Input.action_press("move_right", 1.0)
	Input.action_press("boost", 1.0)
	await _frames(40)
	_check("boost exceeds top speed", player.velocity.length() > t.max_speed * 1.1, player.velocity.length())
	_check("boost drains meter", player.boost_meter < 1.0, player.boost_meter)
	Input.action_release("boost")
	Input.action_release("move_right")

	# Hop leaves the ground and lands again.
	_reset(Vector2(100, 272), Vector2(100, 0))
	Input.action_press("hop")
	await _frames(2)
	Input.action_release("hop")
	_check("hop goes airborne", player.airborne and player.height > 0.0, player.height)
	await _frames(40)
	_check("hop lands", not player.airborne and player.height == 0.0, player.height)

	# Glancing wall hit bounces and keeps speed.
	_reset(Vector2(300, 60), Vector2(200, -120))
	player.facing = player.velocity.angle()
	await _frames(40)
	_check("glancing hit bounces off top wall", player.velocity.y > 0.0, player.velocity)
	_check("bounce keeps most speed", player.velocity.length() > 120.0, player.velocity.length())

	# Head-on wall hit stops hard.
	_reset(Vector2(100, 272), Vector2(-220, 0))
	player.facing = PI
	await _frames(30)
	_check("head-on hit stops hard", player.velocity.length() < 60.0, player.velocity.length())

	# Ramp launches into a long hop, then you catch the rail.
	_reset(Vector2(660, 480), Vector2(-260, 0))
	player.facing = PI
	var launched := false
	var grinded := false
	for i in 90:
		await physics_frame
		if player.airborne and player.height > 25.0:
			launched = true
		if player.grinding_rail:
			grinded = true
	_check("ramp launches high", launched, player.height)
	_check("lands on and grinds the rail", grinded, player.position)

	# Spikes hurt on the ground, not in the air.
	_reset(Vector2(480, 150), Vector2.ZERO)
	player.iframes = 0.0
	var hits := player.hits_taken
	await _frames(3)
	_check("spikes hit on the ground", player.hits_taken == hits + 1, player.hits_taken)

	# Shooting at speed spawns bullets carrying the tier multiplier.
	_reset(Vector2(700, 110), Vector2.ZERO)
	Input.action_press("aim_right", 1.0)
	await _frames(10)
	Input.action_release("aim_right")
	var bullets := room.get_children().filter(func(n): return n is Bullet)
	_check("right stick fires bullets", bullets.size() > 0, bullets.size())

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _reset(pos: Vector2, vel: Vector2) -> void:
	player.position = pos
	player.velocity = vel
	player.airborne = false
	player.height = 0.0
	player.vz = 0.0
	player.grinding_rail = null
	player.drifting = false
	player.drift_level = 0
	player.iframes = 5.0
	player.halo_timer = 0.0
	player.tier = SpeedTier.IDLE
	player.facing = vel.angle() if vel.length() > 0.0 else 0.0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, detail: Variant) -> void:
	print("%s  %s  (%s)" % ["ok  " if ok else "FAIL", label, str(detail)])
	if not ok:
		failures += 1
