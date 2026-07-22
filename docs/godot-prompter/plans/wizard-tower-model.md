# Wizard Tower Model Plan

## Goals

- Replace the CSG tower blockout with an editable Blender-authored dark-fantasy tower.
- Preserve the approved 6 meter exterior radius and world origin.
- Build four above-ground floors, a pointed roof, and an additional secret basement.
- Connect the ground through third floors with a central spiral staircase.
- Make the observatory accessible only through an exterior wooden staircase.
- Reveal the basement and its hidden floor stair only after the player's first death.
- Preserve existing gameplay stations as independent Godot scene instances.

## Scene Tree

```text
WizardTower (Node3D, level composition root)
├── WorldBlockout (imported homestead GLB)
├── TowerArchitecture (tower_architecture.tscn)
│   ├── Model (imported tower GLB)
│   ├── SecretHatchBlocker (StaticBody3D)
│   ├── BasementRespawn (Marker3D)
│   ├── GroundReturn (Marker3D)
│   └── MoodLights (Node3D)
├── DayNightCycle
├── Player
├── FloorProps (Node3D)
└── BasementProps (Node3D)
```

## Responsibilities

| Owner | Responsibility |
| --- | --- |
| Blender tower source | Architectural visual geometry, authored material assignments, named collision meshes, and modular floor collections. |
| Tower architecture wrapper | Runtime markers, hatch collision, local lights, and a stable API for basement reveal state. |
| Wizard tower level | Compose the environment and player, listen for death, reveal the basement, and respawn the player. |
| Player health component | Own health values and emit `died` without knowing about the level. |

## Signal Map

| Signal | Source | Consumer | Purpose |
| --- | --- | --- | --- |
| `died` | `Player/Components/HealthComponent` | `WizardTower` | Trigger first-death basement discovery and respawn. |
| `basement_revealed` | `TowerArchitecture` | Future save/UI systems | Announce that the hidden floor passage is permanently open. |

## Data Flow

1. Lethal damage causes the player's health component to emit `died`.
2. The level asks the architecture wrapper to reveal the basement passage.
3. The wrapper hides the closed hatch, shows the open hatch, and disables the hatch blocker.
4. The level teleports the player to the basement respawn marker and resets physics interpolation.
5. The level resets the player's health and returns control.
6. Later deaths reuse the revealed passage and the same basement respawn point.

## Tasks

- [x] Author a deterministic modular tower in Blender and export a Godot-ready GLB.
  Skills: `godot-prompter:3d-essentials`, `godot-prompter:assets-pipeline`
- [x] Create a focused architecture wrapper with collision, lighting, markers, and reveal behavior.
  Skills: `godot-prompter:scene-organization`, `godot-prompter:physics-system`
- [x] Replace the CSG blockout while preserving independent gameplay props.
  Skills: `godot-prompter:scene-organization`, `godot-prompter:3d-essentials`
- [x] Connect player death to the hidden-basement discovery and respawn flow.
  Skills: `godot-prompter:scene-organization`, `godot-prompter:physics-system`
- [x] Verify dimensions, imported collisions, routes, stairs, and reveal behavior.
  Skills: `godot-prompter:godot-testing`, `godot-prompter:assets-pipeline`
- [x] Capture and inspect exterior, interior, observatory, and basement views.
  Skills: `godot-prompter:3d-essentials`

## Coordinate Contract

The tower remains centered at Godot world position `(0, 0, 0)`.
Its exterior masonry radius is 6 meters.
Ground-floor walking height remains close to Godot `Y = 0.2` to preserve existing prop placement.
The entrance continues to face Godot positive Z toward the exterior paths.
Blender uses Z as up, with the entrance authored toward Blender negative Y for glTF import.
