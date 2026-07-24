# Wizard Sight Element Manipulation and Hurl Plan

## Goals

- Remove Draw and Pour from the rune vocabulary and runtime casting flow.
- Let Wizard Sight move elemental essence directly between world sources and the player's left hand.
- Add Hurl as the explicit offensive rune.
- Give fire, water, earth, and air mechanically distinct Hurl expressions.
- Make Fire Hurl a small long-range bolt that creates a large explosion on impact or at maximum range.
- Let the fire explosion damage and launch the caster as well as other valid targets.

## Approved Interaction

Wizard Sight active plus left click grabs from a filled source or places carried essence into a matching empty source.
Wizard Sight and rune casting are mutually exclusive: the first mode entered remains active until its input is released or its primed rune is used or dismissed.
With Wizard Sight inactive, a primed Hurl consumes carried essence and launches that element's attack expression.
Carried essence survives rune tracing, rune dismissal, and temporary journal presentation.

## Scene Composition

```text
Player
└── Components
    ├── SightController
    │   └── Reveals and selects elemental sources
    ├── ElementHandController
    │   └── Owns carried essence, transfers, left-hand VFX, and carry animation
    └── CastingController
        └── Traces runes and executes Hurl using carried essence
```

## Hurl Expressions

| Element | Expression | Core behavior |
| --- | --- | --- |
| Fire | Fireball | Small compressed bolt with a large radial explosion on collision or at maximum range |
| Water | Water jet | Short sustained stream with continuous push and extinguishing tags |
| Earth | Stone shard | Heavy ballistic projectile with strong impact and stagger tags |
| Air | Air gust | Immediate expanding cone with knockback and disruption tags |

## Tasks

- [x] Reproduce and preserve the existing source-transfer flow before changing it.
  Skills: `godot-prompter:godot-testing`
- [x] Extract carried essence, source transfer, left-hand presentation, and carry animation into `ElementHandController`.
  Skills: `godot-prompter:component-system`, `godot-prompter:input-handling`
- [x] Route Wizard Sight clicks to the element hand and make Sight and rune casting mutually exclusive.
  Skills: `godot-prompter:input-handling`, `godot-prompter:component-system`
- [x] Replace Draw and Pour resources, glyphs, and casting branches with Hurl.
  Skills: `godot-prompter:resource-pattern`, `godot-prompter:gdscript-patterns`
- [x] Add data-driven element-specific Hurl cast bindings and the four expression scenes.
  Skills: `godot-prompter:resource-pattern`, `godot-prompter:component-system`, `godot-prompter:physics-system`
- [x] Build the Fire Hurl bolt, maximum-range airburst, radial impact contract, self-knockback, and large explosion presentation.
  Skills: `godot-prompter:physics-system`, `godot-prompter:particles-vfx`, `godot-prompter:camera-system`, `godot-prompter:audio-system`
- [x] Update the game bible, design document, player controls, and automated integration coverage.
  Skills: `godot-prompter:godot-testing`
- [x] Run the full integration suite, inspect the feature in the playable scene, and review the implementation.
  Skills: `godot-prompter:godot-testing`, `godot-prompter:godot-code-review`

## Failure Rules

- A full element hand cannot grab another filled source.
- An empty hand cannot place essence or fuel Hurl.
- A source accepts only matching essence while depleted.
- An invalid placement leaves the carried essence untouched.
- Hurl with no carried essence remains primed after refusing to fire.
- An elemental attack takes ownership of its essence atomically when firing so it cannot be duplicated or reused.
