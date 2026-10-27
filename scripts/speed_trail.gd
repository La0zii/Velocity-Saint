extends Line2D
## Trail behind the sled. Length and colour show your speed tier
## (none, teal, violet, gold) so you can read your speed at a glance.

const LENGTHS: Array[int] = [0, 8, 16, 26]

@export var player: Player


func _ready() -> void:
	top_level = true
	width = 3.0
	joint_mode = LINE_JOINT_ROUND
	begin_cap_mode = LINE_CAP_ROUND


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	add_point(player.global_position + Vector2(0, -player.height) - Vector2.from_angle(player.facing) * 7.0)
	var keep := LENGTHS[player.tier]
	while get_point_count() > keep:
		remove_point(0)
	var c := SpeedTier.color(player.tier)
	var g := Gradient.new()
	g.set_color(0, Color(c, 0.0))
	g.set_color(1, Color(c, 0.85))
	gradient = g
