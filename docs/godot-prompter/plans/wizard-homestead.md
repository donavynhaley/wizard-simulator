# Wizard Homestead Exterior Plan

## Goals

- Place the wizard tower on a broad, walkable hilltop without changing the tower's current world transform.
- Build three readable paths from the tower to the woods, farm, and village.
- Match route lengths to the player's configured 4.2 meter-per-second walking speed.
- Keep the generated environment editable in Blender and reproducible from a checked-in authoring script.
- Export a Godot-ready GLB with static terrain collision.

## Measured Layout

| Destination | Target time | Target route length | Direction from tower |
| --- | ---: | ---: | --- |
| Woods | 30 seconds | 126 meters | Right |
| Farm | 60 seconds | 252 meters | Left |
| Village | 120 seconds | 504 meters | Center |

The travel times describe continuous walking from the tower along each route.
Small differences can occur from acceleration, player steering, and collision response.

The tower summit rises 32 meters above the surrounding lowland.
Its 14 meter flat summit supports the tower footprint, and the eased hillside reaches the lowland over a 110 meter radius.
The maximum designed slope is about 52 percent before the path corridors are graded into the terrain.
A 360-tree forest belt surrounds the hill's base from roughly 104 to 158 meters from the tower.
The belt reuses `tree_1.glb`, `tree_2.glb`, and `tree_3.glb`, with clear openings maintained around all three paths.

## Scene Composition

```text
WizardTower (existing Node3D)
├── ExteriorHomestead (generated GLB instance)
│   ├── terrain-ground-col
│   ├── Paths
│   ├── Woods
│   ├── Farm
│   ├── Village
│   └── Landmarks
├── DayNightCycle
├── Player
└── Existing tower interior
```

The generated GLB owns only static exterior presentation and terrain collision.
The existing level continues to own the player, lighting, gameplay systems, and tower interior.

## Tasks

- [x] Generate deterministic terrain, route ribbons, and destination landmarks in Blender.
  Skills: `godot-prompter:procedural-generation`, `godot-prompter:3d-essentials`
- [x] Save the editable Blender source and export the runtime GLB.
  Skills: `godot-prompter:assets-pipeline`
- [x] Instance the exported environment in the wizard tower level.
  Skills: `godot-prompter:scene-organization`, `godot-prompter:3d-essentials`
- [x] Validate collision, imports, route lengths, and visual composition.
  Skills: `godot-prompter:godot-testing`, `godot-prompter:3d-essentials`

## Coordinate Contract

The tower remains centered at Godot world position `(0, 0, 0)`.
The hilltop terrain is flat at elevation `0` within the tower footprint and descends 32 meters to the surrounding lowland.
The village path travels generally toward Godot positive Z.
The woods branch toward Godot positive X.
The farm branches toward Godot negative X.

Blender uses Z as up.
The authoring script builds the center route toward Blender negative Y so glTF imports it toward Godot positive Z.
