# Wizard Simulator

First-person 3D wizard game built in Godot 4.7.

## Premise

The wizard has lost his memories and does not know why he is trapped in his own tower.
He watches over the local village kingdom and takes quests to help it, plus timed decrees from the king that must be completed on a deadline.
Fulfilling them means diving into the library, discovering and crafting spells and potions, and casting them; success grows the wizard's renown and coffers.

Four core mechanics are planned: **spell crafting** (in progress), potion alchemy, kingdom monitoring/quests, and royal decrees.

## Spell crafting

Planned design - spells are forged from modular **rune stones** at a physical **spell bench** (no menus):

- Categories: one **Element** (fire, ice, lightning, shadow, wind, earth), one **Shape** (beam, orb, wave, trap, shield, chain, aura), up to two **Behaviors** (bounce, split, linger, home, explode, pierce), one **Trigger** (on impact, on timer, on death, when touched, when recast), up to two **Modifiers** (bigger, faster, cheaper, unstable, silent, delayed, charged, precise, raging).
- Carry stones to the bench's floating sockets, then channel the focus crystal.
- A successful forge rolls a **scroll** onto the tray; holding a scroll is the only way to cast, each cast spends a charge, and a spent scroll crumbles.
- Every rune adds **instability**: past 35% the spell gains deterministic quirks (wild aim, kickback, screaming, sputter); past 55% the forge can backfire; past 85% it always does. Backfires are comedy: frog curse, launch-everyone blast, a tiny useless demon, or the runes scattering across the room.
- The same runes always forge the same spell, so experiments are worth logging: the **Spellbook** autoload journals every combination to `user://spellbook.json` (named recipes, hidden rares, and known-bad combos alike).
- Spells wear their recipe: element sets the color, `precise` runs thin, `raging`/`unstable` grow jagged flickering spikes.

## Drop-in assets

The tower itself is being hand-built in the editor; these scenes are self-contained and can be placed anywhere:

| Scene | What it does |
| --- | --- |
| `assets/artifacts/crafting-table.tscn` | The crafting table: element holder socket + scribing station |
| `scenes/props/rune_cabinet.tscn` | Shelf stocked with one stone per rune; restocks itself |
| `scenes/props/rune_stone.tscn` | One rune (set `rune_id`); pick up with E |
| `scenes/props/spell_scroll.tscn` | A castable spell with charges (usually forged, not placed) |
| `scenes/props/training_dummy.tscn` | Damageable target with HP label; respawns |
| `scenes/props/tiny_demon.tscn` | The useless demon backfires summon |
| `scripts/components/book.tscn` | Physical readable book with swappable visual and page-renderer scenes |
| `scenes/characters/player.tscn` | FPS wizard: controller + interactor + hands + HUD |

The player scene carries the look-to-focus `PlayerInteractor` (duck-typed contract: `focus_prompt(player, collider)` / `interact(player, collider)`), the `WizardHands` held-item component (`%HandAnchor`), and the `WizardHud` (prompts, held item, discovery toasts).
Spell runtime lives in `scripts/spellcraft/` (rune catalog, forge, journal) and `scripts/spellcraft/casting/` (per-shape effects and backfires).
Levels are editor-authored scenes.

## External assets

Downloaded CC0 assets live in `assets/external/kenney` (see its `ASSET_MANIFEST.md`).
The first-person arms are a CC-BY model (`assets/external/polypizza/fps_arms.glb`; see `CREDITS.md`).

## Controls

- `WASD` - move, `Mouse` - look, `Space` - jump
- `E` - interact (take runes/scrolls, socket runes, channel the crystal)
- `Left click` - cast the held scroll
- `Left click` while holding a book - open or close its physical reading pose
- `Left/Right arrows` - turn held-book pages while reading
- `A/D` while scribing - turn pages in the open reference book on the table
- `W/S` while scribing - look up at the reference book / return to the scroll
- `G` - drop the held item
- `Esc` - release mouse, `Left click` - recapture

## Run

```sh
godot --path .
```

Main scene is `scenes/levels/wizard_tower.tscn`.
Use the Godot editor to build and arrange level geometry directly.

## Verify

End-to-end interaction test (fountain -> hands -> element holder -> scribing lock; headless):

```sh
godot --headless --path . -s tools/interaction_test.gd
```

Verify external CC0 asset packs and licenses:

```sh
godot --headless --path . -s tools/verify_assets.gd
```

## Status

In place:

- Hand-built wizard tower as the main scene, with a day/night cycle and the Fountain of Endless Spring.
- Crafting table with an element holder socket and the scroll-scribing station (draw strokes, hold Space to seal).
- Player components: look-to-focus interaction, held-item hands, HUD with toasts.
- First-person arms viewmodel (CC-BY, see `CREDITS.md`) with idle sway and a recurring gesture.

Next: Donavyn builds levels in the editor from these assets; then potion alchemy, kingdom monitoring/quests, and royal decrees.
