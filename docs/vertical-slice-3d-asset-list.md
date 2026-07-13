# Vertical Slice 3D Asset List

This list is based on the vertical slice scope in [game-design-document.md](game-design-document.md), especially the one tower floor, brewing station, storefront window, healing potion, and standard scroll ink requirements.

## Existing Project Models

These bespoke models already exist under `assets/models/`.

| Asset | Model | Source | Scene wrapper | Slice use |
| --- | --- | --- | --- | --- |
| Wooden mug | `assets/models/wooden_mug.glb` | `source_assets/blender/props/wooden_mug.blend` | `game/world/props/furniture/wooden_mug.tscn` | Dressing or potion-serving prop |
| Golden chalice | `assets/models/golden_chalice.glb` | `source_assets/blender/props/golden_chalice.blend` | `game/world/props/furniture/golden_chalice.tscn` | Gilded reward or storefront dressing |
| Barrel, pristine | `assets/models/barrel_pristine.glb` | `source_assets/blender/props/barrel.blend` | `game/world/props/furniture/barrel.tscn` | Reagent, water, or storage dressing |
| Barrel, scuffed | `assets/models/barrel_scuffed.glb` | `source_assets/blender/props/barrel.blend` | `game/world/props/furniture/barrel.tscn` | Reagent, water, or storage dressing |
| Book | `assets/models/book_closed.glb`, `assets/models/book_open.glb` | `source_assets/blender/props/book.blend` | `game/books/book.tscn` | Library shelf, reading, and rune reference |

No dedicated alchemy prep or brewing models were found in `assets/models/`.

The current bespoke exports live directly under `assets/models/`.
For new props, this list follows the pipeline recommendation in [blender-pipeline.md](blender-pipeline.md) and uses `assets/models/props/`.

## Required Alchemy Assets

Create these as bespoke low-poly props for the alchemy vertical slice.

| Priority | Asset | Purpose | Recommended files | Notes |
| --- | --- | --- | --- | --- |
| P0 | Mortar and pestle | Prep station for grinding or crushing reagents. | `source_assets/blender/props/mortar_and_pestle.blend`, `assets/models/props/mortar_and_pestle.glb`, `game/alchemy/props/mortar_and_pestle.tscn` | Model the bowl and pestle as separate named meshes so the pestle can be animated or picked up later. |
| P0 | Wizard stove and brew pot | Heat station for brewing the healing potion and standard scroll ink. | `source_assets/blender/props/wizard_stove.blend`, `assets/models/props/wizard_stove.glb`, `game/alchemy/props/wizard_stove.tscn` | Include burner, small pot, flame socket, and obvious heat-control affordance. |
| P0 | Chopping board | Prep station for chopped herbs and other reagents. | `source_assets/blender/props/chopping_board.blend`, `assets/models/props/chopping_board.glb`, `game/alchemy/props/chopping_board.tscn` | Keep it chunky, stained, and readable from first-person view. |
| P0 | Prep knife | Tool prop for the chopping board interaction. | `source_assets/blender/props/prep_knife.blend`, `assets/models/props/prep_knife.glb`, `game/alchemy/props/prep_knife.tscn` | Keep the final readable as a hand tool rather than a weapon. |
| P0 | Cauldron | Primary visual anchor for brewing, stirring, boiling, and failed sludge. | `source_assets/blender/props/cauldron.blend`, `assets/models/props/cauldron.glb`, `game/alchemy/props/cauldron.tscn` | Include separate body and liquid meshes, with room for smoke, glow, bubbles, and interaction collision in the scene wrapper. |

## Supporting Slice Assets To Consider

These are not in the initial alchemy request, but the vertical slice will likely need them to make the brewing loop legible.

| Priority | Asset | Purpose |
| --- | --- | --- |
| P1 | Potion bottle | Finished healing potion for standing-order turn-in. |
| P1 | Ink bottle | Finished standard scroll ink for the spellcraft table. |
| P1 | Reagent herb bundle | Choppable input item for the board. |
| P1 | Powder or crushed reagent pile | Output from the mortar and pestle. |
| P1 | Stirring spoon or ladle | Stirring affordance for the cauldron or brew pot. |
| P1 | Small ingredient jar set | Shelf dressing that makes the alchemy station readable. |
| P1 | Storefront display tray | Place where potions or scrolls visibly change hands. |

## Acceptance Checklist

- Each final prop has a `.blend` source file and exported `.glb`.
- Each `.glb` has a matching `.glb.import` after Godot imports it.
- Any interactable or collidable prop has a `.tscn` wrapper.
- Scale is authored in meters and feels right from first-person view.
- Rotation and scale are applied before export.
- Origins are useful, usually bottom-center for placed props and grip-adjacent for handheld tools.
- Mesh and material names are clean.
- Simple collision is added in Godot, using cylinder shapes for pots and cauldrons and box shapes for boards or stoves where possible.
- The cauldron and brew pot leave room for separate liquid, smoke, glow, and bubble effects.
