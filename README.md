# Hyouka Kart Racer

A fully original 3D arcade kart racer for Android made with Godot 4.7.

This is **not a Mario asset clone**: all drivers, vehicles, tracks, colors, UI, procedural textures/materials, animations, and audio are original/procedural.

## Gameplay
- 4 original circuits with different visual themes
- 8 original racers
- 3-lap races
- Arcade steering, acceleration, braking and Turbo
- Android touch controls plus keyboard controls
- Procedural 3D scenery and kart models
- Camera follow, wheel animation, body/driver animation
- No web view and no HTML game

## Android
Godot exports the game as a native Android APK. The game logic is GDScript inside Godot; the APK is not a Kotlin-native game.

## Build
Use Godot 4.7.2 and an Android export preset. The CI workflow is intended to export a debug APK first, then a release APK after the project passes validation.
