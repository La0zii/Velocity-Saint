# Velocity Saint

A top-down pixel-art roguelike for PC, played on a gamepad. You ride a mag-sled
through a neon cathedral-city, and **the faster you go, the harder you hit**.

This is the **movement prototype**: one grey-box test room with the full
momentum model, built in Godot 4 with GDScript. Everything is placeholder
shapes until the real art arrives.

## Run it on your PC

1. **Install Godot 4.4 or newer** (the standard version, not .NET) from
   <https://godotengine.org/download>. It's a single program, no installer:
   unzip it and run it.
2. **Get the project.** On the GitHub page click **Code → Download ZIP** and
   unzip it, or clone it with GitHub Desktop.
3. **Open it.** In Godot's Project Manager click **Import**, pick the
   `project.godot` file in this folder, then **Import & Edit**. The first open
   takes a few seconds while Godot imports files. If it says the project was
   made with an older version and offers to convert, say yes.
4. **Plug in your controller** (before or after launching).
5. **Press F5** (or the ▶ Play button, top right). The test room opens in a
   1440 × 810 window. Maximise it if you like: the game scales up in whole
   pixels so the pixel art stays crisp.

The debug panel (top right) shows your speed, state and the controller Godot
detected. If it says "no controller found", reconnect the pad and restart.

## Controls

| Gamepad (Xbox names) | Keyboard | Action |
|---|---|---|
| Left stick | WASD | Steer (analog: tilt sets thrust) |
| Right stick | Arrow keys | Aim and fire |
| RT (analog) | Shift | Boost (uses the meter) |
| LT (analog) | Q | Drift: hold to slide, release to cash in a speed burst |
| A | Space | Hop |
| B | E | Spin trick (brief i-frames) |
| LB (hold) | Ctrl | Walk mode: slow and precise |
| Start / Menu | R | Restart the room |
| View / Back | F1 | Show or hide the debug panel |

PlayStation and Switch Pro pads use the same positions (Cross = A, Circle = B,
R2 = RT, L2 = LT, and so on).

## What to try

- **Carve.** Hold a direction at speed: you turn in arcs and keep momentum.
  Push the stick against your motion to brake.
- **Speed tiers.** The bar bottom left shows your speed. Cross 25% for
  **Cruise** (teal trail), 60% for **Rush** (violet), and hold 90%+ for 2 s for
  **Halo** (gold, afterimages). Damage and fire rate go up with each tier.
  Shoot the target dummies (top right) at different speeds to see the numbers.
- **Drift.** Hold LT while turning. The three pips fill (teal, violet, gold);
  release for a burst. Starting a boost right after a burst, a wall bounce or
  a landed spin gives a **CHAIN** kick.
- **Walls.** Hit a wall at an angle to bounce off and keep your speed. Hit it
  head-on and you stop hard.
- **Hop and spin.** A hops over pews and floor spikes. Press B in the air for a
  360; land before it finishes and you bail and lose speed.
- **Ramps and rails.** Ride onto a ramp (cyan chevrons) to launch. Hop onto a
  rail roughly lined up with it to grind and build speed; A hops off.
- **Getting hit.** Touching the pink spikes on the ground drops you one speed
  tier.

## Tuning the feel

Every movement number lives in one file: **`tuning/default_movement.tres`**.
Click it in Godot's FileSystem panel and the Inspector shows each value with a
description (hover a name). Change a value, save, and press F5 again. Tell me
what feels off ("turning is too twitchy at speed", "drift is too slippery") and
I'll tune it with you.

## Project layout

```
project.godot              Settings: 480 x 270 pixel grid, input map
scenes/test_room.tscn      Main scene (room is built in scripts/test_room.gd)
scenes/player.tscn         The player on the mag-sled
scripts/player.gd          All movement: steering, drift, boost, hop, rails, walls
scripts/speed_tier.gd      Idle / Cruise / Rush / Halo thresholds and multipliers
scripts/movement_tuning.gd The tuning values and what they mean
scripts/hud.gd             Speed gauge, boost, drift pips, style, debug panel
tests/                     Headless smoke test
art/                       Drop your sprite sheets here
```

## Automated check

With Godot on your PATH, from this folder:

```
godot --headless -s res://tests/movement_smoke_test.gd
```

It drives the sled with simulated input and checks acceleration, speed tiers,
drift, boost, hops, wall bounces, ramps, rails, spikes and shooting.
