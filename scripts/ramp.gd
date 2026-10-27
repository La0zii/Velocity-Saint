class_name Ramp
extends Area2D
## Ride onto a ramp heading roughly in its direction to launch into a long hop.

@export var direction := Vector2.RIGHT
@export var size := Vector2(24, 24)

const MIN_ENTRY_SPEED := 50.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	direction = direction.normalized()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player and not player.airborne and player.grinding_rail == null:
			if player.velocity.dot(direction) > MIN_ENTRY_SPEED:
				player.launch_from_ramp(direction)


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, Color("2b2238"))
	draw_rect(r, Color("4a3f5c"), false, 1.0)
	# Chevrons point the launch direction.
	var side := direction.orthogonal()
	for i in 3:
		var tip := direction * (-6.0 + i * 6.0)
		draw_polyline(PackedVector2Array([tip - direction * 3.0 + side * 4.0, tip, tip - direction * 3.0 - side * 4.0]), Color("2fd6c3"), 1.0)
