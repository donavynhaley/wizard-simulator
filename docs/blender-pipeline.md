# Blender Pipeline

This project uses Blender for 3D source assets and Godot for game-ready scene setup.

The recommended handoff format is **glTF Binary (`.glb`)**.

## Folder Layout

Use this structure for source files and exported game assets:

```text
assets/
  source/
    blender/
      props/
        cauldron.blend
        tower_door.blend
  models/
    props/
      cauldron.glb
      tower_door.glb
```

The `.blend` file is the editable source file.

The `.glb` file is the exported model that Godot imports.

The Godot scene is the game-ready wrapper that adds collisions, scripts, lights, interaction areas, and other runtime behavior.

Recommended Godot structure:

```text
assets/models/props/cauldron.glb
scenes/props/cauldron.tscn
scripts/props/cauldron.gd
```

## Blender Authoring Rules

Build at real-world scale.

Godot units are meters.

Before exporting, apply transforms in Blender with `Ctrl+A -> Rotation & Scale`.

Set the asset origin/pivot to a useful location.

For props, bottom center is usually the best default.

Use clean object and material names.

Good examples:

```text
cauldron_body
cauldron_liquid
tower_door_frame
tower_door_planks
```

Avoid temporary names like `Cube.003`, `Material.001`, or `new_mesh_final_final`.

Keep one main prop per exported `.glb` unless the asset is naturally a set.

## Export Settings

In Blender, use:

```text
File -> Export -> glTF 2.0
```

Set the format to:

```text
glTF Binary (.glb)
```

Export selected objects when exporting a single prop from a larger Blender scene.

Keep materials enabled.

Use Blender's default glTF transform settings unless the first Godot import shows a scale or orientation problem.

If textures are simple and stable, packing them into the `.glb` is fine.

If textures need to be shared across many assets, keep them as separate files in a clear texture folder.

## Godot Import Flow

Place exported models under `assets/models/`.

Godot will auto-import the `.glb` and create a matching `.glb.import` file.

Commit both the `.glb` and `.glb.import` files.

Create a `.tscn` scene for anything that needs gameplay setup.

The `.glb` should remain the raw imported model.

The `.tscn` should be the game-ready object.

For example, a cauldron scene may include:

- The imported model.
- Collision shapes.
- An interaction area.
- A script.
- Smoke, glow, or liquid effects.
- Audio emitters.

## Collision

Prefer creating collision in Godot for most props.

Use simple collision shapes whenever possible.

Good defaults:

- `BoxShape3D` for crates, doors, shelves, and blocky props.
- `CylinderShape3D` for barrels, pots, columns, and cauldrons.
- `SphereShape3D` for round objects.
- Convex collision only when simple shapes are not accurate enough.

If a model needs custom collision from Blender, name the collision mesh clearly.

Example:

```text
collision_cauldron
collision_tower_door
```

Keep collision meshes simple.

Do not use high-detail visual meshes as physics collision.

## Git Workflow

The asset creator should commit Blender source files and exported `.glb` files.

The Godot integrator should commit `.tscn`, `.import`, and script changes.

If the repo starts growing too large, move large binary assets to Git LFS.

Do not add Git LFS until repo size becomes a real problem.

Always pull the latest `main` before adding or exporting new assets.

Use short, clear commit messages.

Examples:

```text
Add cauldron model
Add tower door model
Set up cauldron prop scene
```

## Handoff Checklist

Before handing off a Blender asset, confirm:

- Scale is correct in meters.
- Rotation and scale are applied.
- Origin is placed intentionally.
- Object names are clean.
- Material names are clean.
- The exported `.glb` opens in Godot.
- The `.blend` and `.glb` are in the expected folders.

Before using an asset in gameplay, confirm:

- The model appears at the correct size.
- The model faces the expected direction.
- Materials import correctly.
- Collision feels correct.
- The game-ready `.tscn` is committed.
- The `.glb.import` file is committed.
