class_name MovementTuning
extends Resource
## Every number that shapes how the sled feels lives here, so we can tune
## the movement together after you play. Open res://tuning/default_movement.tres
## in the Godot Inspector to change values. Speeds are in pixels per second
## (the game is 480 x 270, so 220 px/s crosses the screen in about 2 seconds).

@export_group("Speed")
## Top speed from steering alone. This is 100% for the speed tiers.
@export var max_speed := 220.0
## Top speed while boosting or grinding.
@export var boost_max_speed := 330.0
## How quickly speed above the current cap bleeds away (higher = shorter bursts).
@export var over_cap_drag := 2.2
## Thrust from the left stick at full tilt.
@export var accel := 480.0
## Braking force when the stick points against your motion.
@export var reverse_brake := 950.0
## Rolling friction with no stick input, when nearly stopped.
@export var coast_friction_slow := 360.0
## Rolling friction with no stick input, at top speed. Low = long glides.
@export var coast_friction_fast := 55.0

@export_group("Steering")
## Turn rate (radians per second) when slow. High = nimble.
@export var turn_rate_slow := 13.0
## Turn rate when at top speed. Low = wide, committed arcs.
@export var turn_rate_fast := 4.2
## Below this speed the sled pivots instantly to the stick.
@export var pivot_speed := 35.0
## Sideways grip. High = carves like a car, low = slides like ice.
@export var grip := 9.0
## How much speed survives a carve (1 = turning never costs speed).
@export_range(0.0, 1.0) var carve_keep := 0.93

@export_group("Walk mode")
## Precise, slow movement for fiddly hazards (hold LB).
@export var walk_max_speed := 70.0

@export_group("Drift")
## Sideways grip with the drift trigger fully held.
@export var drift_grip := 1.1
## Extra turn rate while drifting, so you can swing the nose around.
@export var drift_turn_mult := 1.7
## Drifting needs at least this much speed.
@export var drift_min_speed := 75.0
## Seconds of drifting to reach charge levels 1, 2 and 3.
@export var drift_level_times := PackedFloat32Array([0.45, 1.0, 1.7])
## Speed added on release for each charge level (the "drift cash-in").
@export var drift_burst := PackedFloat32Array([55.0, 100.0, 160.0])

@export_group("Boost")
@export var boost_accel := 720.0
## Meter drained per second with the trigger fully held (meter is 0 to 1).
@export var boost_drain := 0.5
@export var boost_regen := 0.28
## Seconds after boosting before the meter refills.
@export var boost_regen_delay := 0.6
## Window after a drift cash-in, wall bounce or landed trick where
## starting a boost gives a bonus kick.
@export var chain_window := 0.4
@export var chain_bonus := 90.0

@export_group("Hop")
## Upward speed of a hop on the fake height axis.
@export var hop_velocity := 150.0
@export var gravity := 600.0
## Steering strength in the air (1 = same as on the ground).
@export_range(0.0, 1.0) var air_control := 0.35
## A hop pressed this long before landing still happens (seconds).
@export var input_buffer := 0.1
## You can still hop this long after riding off the end of a rail.
@export var coyote_time := 0.1
## Ramps multiply hop height and add speed in the ramp's direction.
@export var ramp_launch_mult := 1.6
@export var ramp_speed_bonus := 45.0
## Height needed to clear low obstacles like pews and floor spikes.
@export var low_clear_height := 5.0

@export_group("Trick")
@export var trick_duration := 0.38
## Speed kept if you land before the spin finishes.
@export_range(0.0, 1.0) var bail_speed_keep := 0.4

@export_group("Walls")
## How square a hit must be to count as head-on (1 = dead straight). Anything
## shallower bounces off and keeps most of its speed.
@export_range(0.0, 1.0) var head_on_threshold := 0.82
@export_range(0.0, 1.0) var bounce_keep := 0.86
## Knock-back after a head-on hit, as a fraction of impact speed.
@export var head_on_rebound := 0.15
## Below this speed you slide along walls instead of bouncing.
@export var min_bounce_speed := 60.0

@export_group("Rails")
## How close (px) you must pass over a rail to catch it.
@export var rail_snap_distance := 8.0
## Largest angle between your motion and the rail that still catches.
@export var rail_max_angle_deg := 50.0
@export var grind_accel := 55.0
@export var grind_min_speed := 120.0

@export_group("Speed tiers and hits")
## Seconds above 90% speed before Halo tier lights up.
@export var halo_hold_time := 2.0
@export var hit_iframes := 1.0

@export_group("Shooting (placeholder)")
@export var base_damage := 10.0
@export var base_fire_rate := 5.0
@export var bullet_speed := 320.0
## Fraction of your own velocity added to each shot.
@export var bullet_inherit := 0.3

@export_group("Feel")
## Camera leads your motion by this many seconds of travel.
@export var camera_lookahead := 0.22
@export var rumble_strength := 1.0
