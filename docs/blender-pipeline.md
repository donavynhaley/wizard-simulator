# Blender Modeling Pipeline

This document is the source of truth for where project-authored 3D models belong.
The short version is that every model has an editable source, a Godot-importable export, and usually a feature-owned scene wrapper.

## Where Each File Goes

| File | Purpose | Location |
| --- | --- | --- |
| `.blend` | Editable modeling source | `source_assets/blender/<category>/` |
| `.glb` | Runtime export imported by Godot | `assets/models/<category>/` |
| Texture used by the export | Runtime texture imported by Godot | `assets/textures/<category>/` or beside the model when relative paths require it |
| `.tscn` | Game-ready wrapper with collision and behavior | The owning `game/<feature>/` folder |
| `.gd` | Runtime behavior | Beside the owning feature scene |
| `.glb.import` and texture `.import` | Godot import settings | Generated beside the imported runtime asset |

Do not put `.blend` files under `assets/`.
Godot imports files under `assets/`, while `source_assets/` is intentionally excluded from Godot imports with `.gdignore`.

Do not put gameplay scenes or scripts under `assets/models/`.
The `assets/` tree contains importable runtime files, while `game/` owns gameplay composition and behavior.

## Category Names

Use the same category for the Blender source and exported model whenever possible.

```text
source_assets/blender/
  characters/
  environments/
  props/

assets/models/
  characters/
  environments/
  props/
```

Most standalone objects belong in `props/`.
Characters and rigged creatures belong in `characters/`.
Large architectural modules, terrain, and reusable environment sets belong in `environments/`.

Existing project exports at the root of `assets/models/` are valid legacy paths and do not need to move solely for consistency.
Place new exports in a category folder so the runtime model library remains navigable as it grows.

## Complete Placement Examples

An alchemy cauldron should use:

```text
source_assets/blender/props/cauldron.blend
assets/models/props/cauldron.glb
game/alchemy/props/cauldron.tscn
game/alchemy/props/cauldron.gd        # Only when behavior is needed
```

A generic furniture barrel should use:

```text
source_assets/blender/props/barrel.blend
assets/models/props/barrel.glb
game/world/props/furniture/barrel.tscn
```

A physical book model should use:

```text
source_assets/blender/props/book.blend
assets/models/props/book.glb
game/books/presentation/book_visual.tscn
```

A scribing prop such as an inkwell should use:

```text
source_assets/blender/props/inkwell.blend
assets/models/props/inkwell.glb
game/scribing/station/inkwell.tscn     # Only if it needs its own wrapper
```

A player body model should use:

```text
source_assets/blender/characters/wizard.blend
assets/models/characters/wizard.glb
game/player/body/wizard_body.tscn
```

The feature wrapper may instance several raw models when they form one gameplay object.
For example, `game/scribing/station/crafting_table.tscn` can instance separate table, scroll, quill, and inkwell exports.

## Choosing the Scene Owner

Put the `.tscn` wrapper under the feature that owns its behavior.

| Asset use | Scene location |
| --- | --- |
| Alchemy equipment or ingredients | `game/alchemy/` |
| Books, page presentation, or book furniture | `game/books/` |
| Player body or first-person model | `game/player/body/` or `game/player/viewmodel/` |
| Rune-scribing equipment | `game/scribing/station/` |
| Level-specific or generic world prop | `game/world/props/` |
| Generic furniture | `game/world/props/furniture/` |
| Presentation shared by unrelated features | `shared/` |

If ownership is unclear, choose the feature that controls the object's interaction or lifecycle.
Do not create a new top-level folder for one model.

## Third-Party Models

Do not mix downloaded packs with project-authored Blender files.

Keep complete downloaded packs and their original documentation under:

```text
source_assets/third_party_packs/<pack_name>/
```

Copy only runtime files that an actual scene references into:

```text
assets/third_party/<creator_or_pack>/<asset_name>/
```

Preserve licenses, attribution, shared textures, and other required dependencies with the runtime copy.
Document new third-party runtime assets in `assets/third_party/README.md` and `CREDITS.md`.

## Naming Rules

Use lowercase `snake_case` for filenames and Blender object names.

Good filenames:

```text
cauldron.blend
cauldron.glb
tower_door.glb
wizard_body.glb
```

Good Blender object and material names:

```text
cauldron_body
cauldron_liquid
tower_door_frame
tower_door_planks
iron_dark
wood_weathered
```

Avoid names such as `Cube.003`, `Material.001`, `new_mesh_final`, or `export_2`.
Keep one main asset or one intentionally reusable set per exported `.glb`.

## Blender Authoring Rules

Build at real-world scale because one Godot unit equals one meter.
Apply rotation and scale before export with `Ctrl+A`, then `Rotation & Scale`.
Place the origin intentionally before export.
Bottom center is the default for objects placed on floors or tables, while handheld props should use a grip-friendly origin.
Make forward orientation consistent and verify it in Godot before final handoff.
Keep material slots and object hierarchy as simple as the asset allows.

## Export Settings

Use `File -> Export -> glTF 2.0` in Blender.
Choose `glTF Binary (.glb)` as the export format.
Export selected objects when the Blender file contains work that should not be part of the runtime model.
Keep materials enabled.
Use the default glTF transform settings unless the first Godot import demonstrates an orientation or scale problem.

Pack unique textures into the `.glb` when that keeps the model self-contained.
Use separate runtime textures when multiple models share them or artists need to revise them independently.
Keep relative texture dependencies in a stable folder beside the exported model when the GLB references external files.

## Godot Import Flow

1. Save the editable Blender source under `source_assets/blender/<category>/`.
2. Export the `.glb` under `assets/models/<category>/`.
3. Let Godot import the file and generate its `.glb.import` sidecar.
4. Select the `.glb` in Godot's FileSystem dock and review its Import settings.
5. Use Advanced Import Settings when the model contains animation, a skeleton, generated collision, or per-node overrides.
6. Create the game-ready `.tscn` under the owning feature.
7. Instance the raw `.glb` inside the wrapper instead of editing the imported scene directly.
8. Add simple collision, interaction areas, scripts, audio, VFX, and feature-specific presentation to the wrapper.
9. Run the relevant scene or integration test before handoff.

Never edit files under `.godot/imported/` because Godot regenerates them.
Do not hand-edit `.import` files when the Import dock can make the change safely.
Commit `.import` sidecars because they preserve import settings and resource UIDs across machines.

## Collision

Prefer simple collision authored in the feature-owned Godot scene for most props.

- Use `BoxShape3D` for crates, doors, shelves, and blocky props.
- Use `CylinderShape3D` for barrels, pots, columns, and cauldrons.
- Use `SphereShape3D` for round objects.
- Use convex collision only when primitive shapes cannot represent the gameplay silhouette.

When imported collision is appropriate, use Godot's recognized Blender suffixes.

| Blender object suffix | Godot result |
| --- | --- |
| `-col` | Static body collision |
| `-convcol` | Convex collision shape |
| `-rigid` | Rigid body |
| `-navmesh` | Navigation region |
| `-occluder` | Occluder instance |

Keep collision meshes low-detail.
Never use a high-detail visual mesh directly as physics collision unless profiling and gameplay requirements justify it.

## Version-Control Handoff

The modeling handoff should normally include:

- The editable `.blend` source under `source_assets/blender/`.
- The exported `.glb` under `assets/models/`.
- Any separate runtime textures.
- Generated `.import` sidecars after Godot has imported the asset.
- The feature-owned `.tscn` wrapper when the model is already integrated.
- Any license or attribution updates for third-party work.

Do not commit `.godot/` because it is a generated local cache.
Do not place temporary renders, reference screenshots, autosaves, or abandoned exports in runtime asset folders.
Remove superseded exports once no scene or resource references them.

## Modeling Handoff Checklist

Before handing off a model, confirm:

- The `.blend` is in `source_assets/blender/<category>/`.
- The `.glb` is in the matching `assets/models/<category>/` folder.
- The source and export use clear `snake_case` names.
- Scale is correct in meters.
- Rotation and scale are applied.
- The origin is placed intentionally.
- Object and material names are clean.
- Required textures are packed or copied with stable relative paths.
- The `.glb` imports in Godot without errors or missing dependencies.
- The `.glb.import` and texture `.import` sidecars are included.
- The game-ready wrapper is under the owning feature rather than under `assets/`.
- Collision uses simple shapes unless the asset genuinely needs imported collision.
- Materials, orientation, animation, and rigging look correct in the wrapper scene.
