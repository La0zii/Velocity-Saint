extends Node2D
## Grey-box test room for the movement prototype. Built in code from simple
## shapes so it's easy to rearrange. Two screens wide and two tall, with
## angled walls to bounce off, a pillar to carve around, pews to hop, ramps,
## rails, floor spikes and target dummies.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ROOM := Vector2(960, 544)
const WALL := 16.0
const SPAWN := Vector2(100, 272)

const FLOOR_A := Color("1a1526")
const FLOOR_B := Color("1d182b")
const STONE := Color("4a3f5c")
const STONE_EDGE := Color("8c8299")
const PEW := Color("2b2238")


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("14111f"))
	_build_walls()
	_build_props()

	var player: Player = PLAYER_SCENE.instantiate()
	player.position = SPAWN
	var trail := Line2D.new()
	trail.set_script(preload("res://scripts/speed_trail.gd"))
	trail.player = player
	add_child(trail)
	add_child(player)

	var fx := FX.new()
	add_child(fx)

	var camera := Camera2D.new()
	camera.set_script(preload("res://scripts/game_camera.gd"))
	camera.target = player
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(ROOM.x)
	camera.limit_bottom = int(ROOM.y)
	add_child(camera)
	camera.make_current()

	var hud_layer := CanvasLayer.new()
	var hud := Control.new()
	hud.set_script(preload("res://scripts/hud.gd"))
	hud.player = player
	hud_layer.add_child(hud)
	add_child(hud_layer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _build_walls() -> void:
	# Outer walls.
	_solid(_rect(Vector2(ROOM.x * 0.5, WALL * 0.5), Vector2(ROOM.x, WALL)))
	_solid(_rect(Vector2(ROOM.x * 0.5, ROOM.y - WALL * 0.5), Vector2(ROOM.x, WALL)))
	_solid(_rect(Vector2(WALL * 0.5, ROOM.y * 0.5), Vector2(WALL, ROOM.y)))
	_solid(_rect(Vector2(ROOM.x - WALL * 0.5, ROOM.y * 0.5), Vector2(WALL, ROOM.y)))
	# Chamfered corners: hit these at speed to bounce around the room.
	var w := WALL
	_solid(PackedVector2Array([Vector2(w, w), Vector2(w + 64, w), Vector2(w, w + 64)]))
	_solid(PackedVector2Array([Vector2(ROOM.x - w, w), Vector2(ROOM.x - w, w + 64), Vector2(ROOM.x - w - 64, w)]))
	_solid(PackedVector2Array([Vector2(w, ROOM.y - w), Vector2(w, ROOM.y - w - 64), Vector2(w + 64, ROOM.y - w)]))
	_solid(PackedVector2Array([Vector2(ROOM.x - w, ROOM.y - w), Vector2(ROOM.x - w - 64, ROOM.y - w), Vector2(ROOM.x - w, ROOM.y - w - 64)]))
	# Central diamond pillar to carve around and bank off.
	var c := ROOM * 0.5
	_solid(PackedVector2Array([c + Vector2(0, -36), c + Vector2(36, 0), c + Vector2(0, 36), c + Vector2(-36, 0)]))
	# Square pillars (head-on hits stop you hard).
	_solid(_rect(Vector2(300, 150), Vector2(32, 32)))
	_solid(_rect(Vector2(660, 400), Vector2(32, 32)))
	# Angled shards for bank shots.
	_solid(_rect(Vector2(740, 140), Vector2(90, 10), deg_to_rad(25)))
	_solid(_rect(Vector2(220, 410), Vector2(90, 10), deg_to_rad(-25)))
	# Pews: low obstacles you can hop over.
	for y in [222.0, 252.0, 282.0, 312.0]:
		_solid(_rect(Vector2(840, y), Vector2(64, 8)), true)


func _build_props() -> void:
	_add_ramp(Vector2(740, 267), Vector2.RIGHT, Vector2(24, 40))
	_add_ramp(Vector2(600, 480), Vector2.LEFT, Vector2(24, 24))

	_add_rail(Vector2(300, 480), Vector2(540, 480))
	_add_rail(Vector2(400, 64), Vector2(660, 64))

	_add_hazard(Vector2(480, 150), Vector2(64, 12))
	_add_hazard(Vector2(180, 110), Vector2(12, 56))
	_add_hazard(Vector2(860, 480), Vector2(12, 48))

	for p in [Vector2(880, 110), Vector2(905, 150), Vector2(880, 400), Vector2(110, 470)]:
		var dummy := TargetDummy.new()
		dummy.position = p
		add_child(dummy)


func _add_ramp(pos: Vector2, dir: Vector2, size: Vector2) -> void:
	var ramp := Ramp.new()
	ramp.position = pos
	ramp.direction = dir
	ramp.size = size
	add_child(ramp)


func _add_rail(a: Vector2, b: Vector2) -> void:
	var rail := Rail.new()
	rail.a = a
	rail.b = b
	add_child(rail)


func _add_hazard(pos: Vector2, size: Vector2) -> void:
	var hazard := Hazard.new()
	hazard.position = pos
	hazard.size = size
	add_child(hazard)


func _solid(points: PackedVector2Array, low := false) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4 if low else 1
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = PEW if low else STONE
	body.add_child(fill)
	var edge := Line2D.new()
	edge.points = points
	edge.closed = true
	edge.width = 1.0
	edge.default_color = Color("e8b04b") if low else STONE_EDGE
	body.add_child(edge)
	add_child(body)


func _rect(center: Vector2, size: Vector2, angle := 0.0) -> PackedVector2Array:
	var h := size * 0.5
	var pts := PackedVector2Array()
	for corner in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		pts.append(center + corner.rotated(angle))
	return pts


func _draw() -> void:
	# Checker floor so you can feel your speed against the tiles.
	var tiles := Vector2i(int(ROOM.x / 16.0), int(ROOM.y / 16.0))
	for x in tiles.x:
		for y in tiles.y:
			draw_rect(Rect2(x * 16, y * 16, 16, 16), FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
	var font := ThemeDB.fallback_font
	var hint := Color("4a3f5c")
	draw_string(font, Vector2(40, 262), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, hint)
	draw_string(font, Vector2(700, 230), "RAMP OVER THE PEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, hint)
	draw_string(font, Vector2(330, 505), "HOP ONTO THE RAIL", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, hint)
	draw_string(font, Vector2(440, 135), "HOP THE SPIKES", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, hint)
	draw_string(font, Vector2(820, 80), "SHOOT AT SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, hint)
