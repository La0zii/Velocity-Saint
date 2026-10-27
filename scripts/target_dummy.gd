class_name TargetDummy
extends StaticBody2D
## Shoot it to see how much your speed tier multiplies damage.

const RADIUS := 7.0

var _flash := 0.0
var _total := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)


func take_damage(amount: float, color: Color) -> void:
	_flash = 0.1
	_total += amount
	var fx := FX.get_fx(self)
	fx.burst(global_position + Vector2(0, -8), 6, color, 50.0)
	fx.text(global_position + Vector2(randf_range(-6, 6), -22), str(snappedf(amount, 0.1)), color)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, RADIUS + 1.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Color("ede6d6") if _flash > 0.0 else Color("4a3f5c")
	draw_rect(Rect2(-5, -16, 10, 16), body)
	draw_circle(Vector2(0, -16), 5.0, body)
	draw_circle(Vector2(0, -16), 2.0, Color("e2367a"))
	draw_rect(Rect2(-5, -16, 10, 16), Color("8c8299"), false, 1.0)
