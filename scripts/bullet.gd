class_name Bullet
extends Area2D
## Placeholder shot. Damage is set by the player's speed tier when fired.
## Flies over low obstacles (pews), stops on walls and targets.

const LIFETIME := 1.2

var velocity := Vector2.ZERO
var damage := 10.0
var color := Color.WHITE
var height := 6.0
var _age := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	if _age > LIFETIME:
		queue_free()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, color)
	else:
		FX.get_fx(self).burst(global_position, 4, color, 40.0)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2(0, 2), 2.0, Color(0, 0, 0, 0.4))
	draw_line(Vector2(0, -height), Vector2(0, -height) - velocity.normalized() * 4.0, Color(color, 0.5), 2.0)
	draw_circle(Vector2(0, -height), 2.0, color)
