# Kenney Asset Manifest

This folder contains CC0 Kenney assets for building out the Wizard Simulator tower, exterior vista, and gothic dressing.
The downloaded zip files are preserved in `_downloads` for traceability.

## Packs

| Pack | Local folder | Use | Source |
| --- | --- | --- | --- |
| Modular Dungeon Kit | `modular-dungeon-kit` | Stone room shells, dungeon walls, gates, and straight stairs. | https://kenney.nl/assets/modular-dungeon-kit |
| Fantasy Town Kit | `fantasy-town-kit` | Village buildings, stone stairs, wall sections, roofs, roads, trees, lanterns, and town props. | https://kenney.nl/assets/fantasy-town-kit |
| Retro Fantasy Kit | `retro-fantasy-kit` | Tower modules, fortified walls, gates, castle silhouettes, floors, and retro low-poly structures. | https://kenney.nl/assets/retro-fantasy-kit |
| Graveyard Kit | `graveyard-kit` | Grim stone props, candles, crypt pieces, iron fences, damaged benches, and moody exterior dressing. | https://kenney.nl/assets/graveyard-kit |
| Retro Textures Fantasy | `retro-textures-fantasy` | Pixel/retro stone, wood, roof, door, and window textures for grimy analog materials. | https://kenney.nl/assets/retro-textures-fantasy |

Each pack includes its own `License.txt`.
The licenses identify the assets as Creative Commons Zero, CC0.
Credit to Kenney is optional, but the source links above should stay with the project.

## Inventory

- Downloaded asset files: 2210.
- Total files including this manifest: 2211.
- GLB models: 402.
- FBX models: 402.
- OBJ models: 402.
- PNG textures and previews: 574.

Use the GLB files first in Godot.
They are the quickest format to instance into the scene while you block out the tower.

## Tower Structure

Use these as the first pass for a stone tower with multiple walkable floors:

- `modular-dungeon-kit/Models/GLB format/room-large.glb`
- `modular-dungeon-kit/Models/GLB format/room-wide.glb`
- `modular-dungeon-kit/Models/GLB format/room-corner.glb`
- `modular-dungeon-kit/Models/GLB format/template-floor-big.glb`
- `modular-dungeon-kit/Models/GLB format/template-floor.glb`
- `modular-dungeon-kit/Models/GLB format/template-wall.glb`
- `modular-dungeon-kit/Models/GLB format/template-wall-corner.glb`
- `modular-dungeon-kit/Models/GLB format/template-wall-half.glb`
- `modular-dungeon-kit/Models/GLB format/template-wall-top.glb`

For a more exterior tower silhouette, use:

- `retro-fantasy-kit/Models/GLB format/tower-base.glb`
- `retro-fantasy-kit/Models/GLB format/tower.glb`
- `retro-fantasy-kit/Models/GLB format/tower-top.glb`
- `retro-fantasy-kit/Models/GLB format/tower-edge.glb`

## Stairs And Floors

Use these for vertical traversal and multi-floor editing:

- `fantasy-town-kit/Models/GLB format/stairs-stone.glb`
- `fantasy-town-kit/Models/GLB format/stairs-stone-handrail.glb`
- `fantasy-town-kit/Models/GLB format/stairs-stone-round.glb`
- `fantasy-town-kit/Models/GLB format/stairs-wide-stone.glb`
- `fantasy-town-kit/Models/GLB format/stairs-wide-stone-handrail.glb`
- `modular-dungeon-kit/Models/GLB format/stairs.glb`
- `modular-dungeon-kit/Models/GLB format/stairs-wide.glb`
- `retro-fantasy-kit/Models/GLB format/floor-stairs.glb`
- `retro-fantasy-kit/Models/GLB format/floor-stairs-corner-inner.glb`
- `retro-fantasy-kit/Models/GLB format/floor-stairs-corner-outer.glb`

## Window Vista

Use these to build a large window looking out over the village and castle:

- `fantasy-town-kit/Models/GLB format/wall-window-glass.glb`
- `fantasy-town-kit/Models/GLB format/wall-window-round.glb`
- `fantasy-town-kit/Models/GLB format/wall-window-stone.glb`
- `fantasy-town-kit/Models/GLB format/wall-arch.glb`
- `fantasy-town-kit/Models/GLB format/wall-arch-top.glb`
- `modular-dungeon-kit/Models/GLB format/gate-door-window.glb`
- `retro-textures-fantasy/PNG/window_tall_rounded_lit.png`
- `retro-textures-fantasy/PNG/window_tall_divided.png`
- `retro-textures-fantasy/PNG/window_square_metal_fortified.png`

Keep the window frame chunky and imperfect.
The target style should feel low-poly, dirty, and useful rather than ornate.

## Village View

Use these as distant exterior set dressing outside the window:

- `fantasy-town-kit/Models/GLB format/wall.glb`
- `fantasy-town-kit/Models/GLB format/wall-wood.glb`
- `fantasy-town-kit/Models/GLB format/wall-wood-window-shutters.glb`
- `fantasy-town-kit/Models/GLB format/roof-gable.glb`
- `fantasy-town-kit/Models/GLB format/roof-high-gable.glb`
- `fantasy-town-kit/Models/GLB format/road.glb`
- `fantasy-town-kit/Models/GLB format/road-bend.glb`
- `fantasy-town-kit/Models/GLB format/fence.glb`
- `fantasy-town-kit/Models/GLB format/fence-broken.glb`
- `fantasy-town-kit/Models/GLB format/tree.glb`
- `fantasy-town-kit/Models/GLB format/tree-crooked.glb`
- `fantasy-town-kit/Models/GLB format/windmill.glb`
- `fantasy-town-kit/Models/GLB format/watermill.glb`

## Castle View

Use these for a readable castle shape beyond the village:

- `retro-fantasy-kit/Models/GLB format/wall-fortified.glb`
- `retro-fantasy-kit/Models/GLB format/wall-fortified-window.glb`
- `retro-fantasy-kit/Models/GLB format/wall-fortified-door.glb`
- `retro-fantasy-kit/Models/GLB format/wall-fortified-gate.glb`
- `retro-fantasy-kit/Models/GLB format/wall-gate.glb`
- `retro-fantasy-kit/Models/GLB format/tower-base.glb`
- `retro-fantasy-kit/Models/GLB format/tower-top.glb`

For distant scenery, keep collisions off and reduce material detail.
The castle should read through silhouette and cold rim light from the tower window.

## Grimy Wizard Dressing

Use these to keep the tower from feeling clean:

- `graveyard-kit/Models/GLB format/candle.glb`
- `graveyard-kit/Models/GLB format/candle-multiple.glb`
- `graveyard-kit/Models/GLB format/lantern-candle.glb`
- `graveyard-kit/Models/GLB format/fire-basket.glb`
- `graveyard-kit/Models/GLB format/altar-stone.glb`
- `graveyard-kit/Models/GLB format/debris.glb`
- `graveyard-kit/Models/GLB format/debris-wood.glb`
- `graveyard-kit/Models/GLB format/bench-damaged.glb`
- `graveyard-kit/Models/GLB format/urn-round.glb`
- `graveyard-kit/Models/GLB format/urn-square.glb`
- `graveyard-kit/Models/GLB format/stone-wall-damaged.glb`
- `graveyard-kit/Models/GLB format/iron-fence-damaged.glb`

## Texture Starting Points

Use these for stone walls, floors, wood, roofs, doors, and dirty window surfaces:

- `retro-textures-fantasy/PNG/wall_stone.png`
- `retro-textures-fantasy/PNG/wall_stone_depth.png`
- `retro-textures-fantasy/PNG/wall_brick_stone_center.png`
- `retro-textures-fantasy/PNG/wall_brick_small_stone.png`
- `retro-textures-fantasy/PNG/floor_stone.png`
- `retro-textures-fantasy/PNG/floor_stone_pattern.png`
- `retro-textures-fantasy/PNG/floor_wood_planks_damaged.png`
- `retro-textures-fantasy/PNG/door_wood.png`
- `retro-textures-fantasy/PNG/door_metal_gate.png`
- `retro-textures-fantasy/PNG/roof_clay_grey_center.png`
- `retro-textures-fantasy/PNG/roof_thatch_center.png`

## Godot Notes

Instance GLBs as scene children during manual editing.
For large exterior vistas, mark static background pieces as non-collidable unless the player can reach them.
For tower floors and stairs, add or verify `StaticBody3D` collision where Godot import does not generate the collision you need.
Use low-resolution textures, fog, color desaturation, limited draw distance, and warm/cold practical lights to keep the analog horror feel.
