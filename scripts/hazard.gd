class_name Hazard
extends Area2D
## Floor spikes. Hurt you only while you're on the ground, so hop over them.

@export var size := Vector2(48, 12)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and player.height < 3.0:
			player.take_hit(global_position)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color("2b2238"))
	var x := r.position.x + 2.0
	while x < r.end.x - 2.0:
		var base := r.end.y - 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, base), Vector2(x + 2.0, r.position.y + 2.0), Vector2(x + 4.0, base)]), Color("e2367a"))
		x += 6.0
