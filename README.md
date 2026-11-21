# Tron Tank Battle

Drive the 1982 Tron tank across a 96 × 96 grid and engage two Evolution light tanks per wave. Bunkers break the line of sight. Each cannon fires from the tip of its rotating turret.

## Gameplay

![Gameplay recorded in Godot showing the player steering across the grid as enemy tanks close in](docs/media/gameplay.gif)

[Watch the gameplay clip in 720p (MP4)](docs/media/gameplay.mp4)

| View from spawn | Engaging the two light tanks |
| --- | --- |
| [![View from behind the player tank with cover on either side](docs/media/arena.jpg)](docs/media/arena.jpg) | [![Enemy tanks converging ahead of the player](docs/media/encounter.jpg)](docs/media/encounter.jpg) |

## Controls

- Keyboard: **WASD** or arrows to drive, right-drag to aim the turret, **Space** or left-click to fire, **R** to restart after destruction.
- Touch: hold the lower-left stick to drive and steer, drag on the right side to aim, and hold **FIRE** to shoot.

## Open and export

Open this folder in Godot 4.7 or later and run `scenes/battle.tscn`. The project targets the GL Compatibility renderer and enables ETC2/ASTC imports for Android. Android export uses the `Android` preset in `export_presets.cfg`; configure the Android SDK, JDK, export templates, and a release signing key in Godot before publishing.

The checked-in preset is for local debug builds. Its output path is `builds/tron-tank-battle-debug.apk`.

## Assets

Both tank models are by Shriker1. The original license files accompany the [1982 tank](vendor/tron_1982_tank/license.txt) and the [Evolution light tank](vendor/evolution_light_tank/license.txt).
