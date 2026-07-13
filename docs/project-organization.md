# Project Organization

The project uses feature-first ownership for gameplay and separates runtime assets from authoring sources.

## Ownership Rules

- Put feature-specific runtime code and scenes together under `game/<feature>/`.
- Split a feature into small responsibility folders only when the distinction is useful, such as `player/body/`, `player/viewmodel/`, and `player/interaction/`.
- Put authored game data under `content/`, grouped by the feature that consumes it.
- Put code used by several unrelated features under `shared/`.
- Put executable headless tests under `tests/integration/` and test-only scenes under `tests/fixtures/`.
- Put editor-facing authoring helpers under `tools/authoring/` and operational scripts under the matching `capture/`, `inspection/`, or `verification/` folder.
- Put only importable runtime assets under `assets/`.
- Put editable source files and complete downloaded packs under `source_assets/`, which is excluded from Godot imports by `.gdignore`.

## Feature Boundaries

`game/player/` owns player control, the body scene, the first-person viewmodel, interactions, held-item presentation, and the HUD.
The player root composes `wizard_body.tscn`, `first_person_viewmodel.tscn`, and `wizard_hud.tscn` while preserving stable node paths used by runtime code.

`game/scribing/` owns the physical station, stroke canvas, scribe arm, rune resources, recognition, and session state.
`ScribingSession` stores strokes and recognized rune results while `rune_scribing_station.gd` coordinates input, cameras, props, books, and completion.
Sealing is deliberately output-neutral until a new spell design is implemented.

`game/books/` owns book data, page rendering, physical presentation, and book-specific props.

`game/alchemy/` owns the flask, burner, ingredients, element holder, and alchemy storage.

`game/world/` owns levels, environmental systems, and props that are not exclusive to another feature.

## Adding Future Spell Work

Create `game/spells/` only when the replacement spell design has a concrete runtime boundary.
Keep rune scribing independent and consume its completion signal or recognized-rune accessors instead of coupling spell construction back into the station.
Add new tests for the output contract before connecting inventory, casting, delivery, or effects.
