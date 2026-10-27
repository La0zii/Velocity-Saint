class_name Rail
extends Node2D
## A grind rail from `a` to `b` (local coordinates). Hop and land across it,
## roughly lined up, to lock on and build speed.

@export var a := Vector2.ZERO
@export var b := Vector2(128, 0)


func _ready() -> void:
	add_to_group("rails")


func global_a() -> Vector2:
	return to_global(a)


func global_b() -> Vector2:
	return to_global(b)


func _draw() -> void:
	var lift := Vector2(0, -Player.RAIL_HEIGHT)
	draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(0, 0, 0, 0.45), 2.0)
	var posts := int(a.distance_to(b) / 32.0)
	for i in posts + 1:
		var p := a.lerp(b, float(i) / maxf(posts, 1))
		draw_line(p, p + lift, Color("4a3f5c"), 2.0)
	draw_line(a + lift, b + lift, Color("8c8299"), 2.0)
	draw_line(a + lift + Vector2(0, -1), b + lift + Vector2(0, -1), Color("e8b04b"), 1.0)
