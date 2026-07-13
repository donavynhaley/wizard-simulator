# Wizard Simulator

Wizard Simulator is a first-person 3D game built with Godot 4.7.
The current playable tower focuses on physical interaction, rune scribing, readable books, and an early alchemy loop.

## Current Features

- A hand-authored wizard tower with day and night lighting.
- A composed first-person player with movement, interaction, visible arms, beard inventory presentation, magical item handling, and HUD feedback.
- Physical rune scribing with a scroll, ink, quill, reference book, camera poses, stroke recognition, rune glow, sealing, and completion signals.
- Physical books with page data, page rendering, placement, opening, and page turning.
- Early alchemy interactions for gathering elements, filling and heating a flask, and breaking a dropped flask.

The previous compiled-spell, castable-scroll, spell-delivery, and spell-effect implementation has been removed intentionally.
Sealing a scribed scroll currently preserves the ink and recognition results, restores player control, and emits `scribing_completed` without creating an inventory item.

## Project Layout

```text
game/
  alchemy/       Alchemy scenes, ingredients, props, and storage
  books/         Book runtime, presentation, resources, and props
  player/        Player root, body, viewmodel, interaction, and HUD
  scribing/      Rune data, recognition, session state, and station
  world/         Levels, environmental systems, and world props
shared/          Cross-feature item, presentation, and VFX code
content/         Authored book and rune resources
tests/           Headless integration tests and test fixtures
tools/           Authoring, capture, inspection, and verification tools
assets/          Runtime-ready project and curated third-party assets
source_assets/   Godot-ignored Blender sources and complete asset packs
docs/            Design notes, specifications, and architecture records
```

See [docs/project-organization.md](docs/project-organization.md) for ownership rules and placement guidance.

## Controls

- `WASD` moves and the mouse looks.
- `Space` jumps during normal play and seals a scroll when held during scribing.
- `E` interacts with focused objects.
- `Left click` opens or closes a held book and draws while scribing.
- `Left` and `Right` turn held-book pages while reading.
- `B` lifts the beard while looking down.
- `A` and `D` turn reference-book pages while scribing.
- `W` and `S` move between the reference book and scroll camera poses while scribing.
- `G` drops the held item.
- `Esc` releases the mouse and `Left click` recaptures it.

## Run

```sh
godot --path .
```

The main scene is `game/world/levels/wizard_tower.tscn`.
Levels and visual composition are authored directly in the Godot editor.

## Verify

Run the full physical-interaction and rune-scribing flow:

```sh
godot --headless --path . -s tests/integration/interaction_test.gd
```

Run every headless integration test:

```sh
for test in tests/integration/*_test.gd; do
  godot --headless --path . -s "$test" || exit 1
done
```

Verify curated runtime assets and the Kenney license:

```sh
godot --headless --path . -s tools/verification/verify_assets.gd
```

## Assets

Runtime assets belong under `assets/`.
Only third-party files referenced by runtime scenes are kept under `assets/third_party/`.
Editable Blender sources and complete downloaded packs are retained under `source_assets/`, where `.gdignore` prevents Godot from importing them.
See [CREDITS.md](CREDITS.md) and [assets/third_party/README.md](assets/third_party/README.md) for provenance notes.
