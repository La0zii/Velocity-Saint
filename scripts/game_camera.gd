extends Camera2D
## Follows the player and leads in the direction of travel, so at high speed
## you can see what's coming. Adds screen shake for impacts.

@export var target: Player

var _shake := 0.0


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _ready() -> void:
	if target:
		global_position = target.global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var lead := (target.velocity * target.tuning.camera_lookahead).limit_length(80.0)
	var desired := target.global_position + lead
	global_position = global_position.lerp(desired, 1.0 - exp(-7.0 * delta))
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_shake = move_toward(_shake, 0.0, 25.0 * delta)
