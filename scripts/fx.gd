class_name FX
extends Node2D
## Lightweight placeholder effects (sparks, rings, afterimages, floating
## text), all drawn with shapes until real sprites and particles arrive.

const FONT_SIZE := 8

var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _ghosts: Array[Dictionary] = []
var _texts: Array[Dictionary] = []


static func get_fx(node: Node) -> FX:
	return node.get_tree().get_first_node_in_group("fx") as FX


func _ready() -> void:
	add_to_group("fx")
	z_index = 50


func sparks(pos: Vector2, dir: Vector2, count: int, color: Color, speed := 80.0, spread := 0.7) -> void:
	for i in count:
		var v := dir.normalized().rotated(randf_range(-spread, spread)) * speed * randf_range(0.5, 1.2)
		_particles.append({"pos": pos, "vel": v, "life": randf_range(0.15, 0.35), "max": 0.35, "color": color})


func burst(pos: Vector2, count: int, color: Color, speed := 80.0) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.3, 1.0)
		_particles.append({"pos": pos, "vel": v, "life": randf_range(0.2, 0.45), "max": 0.45, "color": color})


func ring(pos: Vector2, color: Color, radius: float) -> void:
	_rings.append({"pos": pos, "color": color, "radius": radius, "life": 0.3, "max": 0.3})


func ghost(pos: Vector2, angle: float, color: Color) -> void:
	_ghosts.append({"pos": pos, "angle": angle, "color": color, "life": 0.2, "max": 0.2})


func text(pos: Vector2, s: String, color: Color) -> void:
	_texts.append({"pos": pos, "text": s, "color": color, "life": 0.8, "max": 0.8})


func _process(delta: float) -> void:
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= exp(-4.0 * delta)
	for list in [_rings, _ghosts, _texts]:
		for e in list:
			e.life -= delta
	for t in _texts:
		t.pos.y -= 18.0 * delta
	_particles = _particles.filter(func(e): return e.life > 0.0)
	_rings = _rings.filter(func(e): return e.life > 0.0)
	_ghosts = _ghosts.filter(func(e): return e.life > 0.0)
	_texts = _texts.filter(func(e): return e.life > 0.0)
	queue_redraw()


func _draw() -> void:
	var sled := PackedVector2Array([Vector2(9, 0), Vector2(5, -4), Vector2(-7, -3), Vector2(-7, 3), Vector2(5, 4)])
	for g in _ghosts:
		draw_set_transform(g.pos, g.angle, Vector2.ONE)
		draw_colored_polygon(sled, Color(g.color, 0.5 * g.life / g.max))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for r in _rings:
		var k: float = 1.0 - r.life / r.max
		draw_arc(r.pos, r.radius * (0.5 + k), 0.0, TAU, 24, Color(r.color, 1.0 - k), 1.0)
	for p in _particles:
		draw_rect(Rect2(p.pos.round(), Vector2.ONE), Color(p.color, clampf(p.life / 0.2, 0.0, 1.0)))
	var font := ThemeDB.fallback_font
	for t in _texts:
		var size := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var at: Vector2 = (t.pos - Vector2(size.x * 0.5, 0)).round()
		var c: Color = t.color
		draw_string(font, at + Vector2(1, 1), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(Color("14111f"), c.a * minf(t.life / 0.3, 1.0)))
		draw_string(font, at, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(c, minf(t.life / 0.3, 1.0)))
