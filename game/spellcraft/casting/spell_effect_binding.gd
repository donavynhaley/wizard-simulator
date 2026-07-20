class_name SpellEffectBinding
extends Resource

## Maps a recognized rune id to the effect scene shown in the palm while the
## spell is held. Authored as entries in CastingController.spell_effect_bindings;
## a rune with no entry falls back to the controller's default_spell_effect.
## The element system later tints the spawned effect through set_color().

@export var rune_id: StringName = &""
## The held-in-palm visual (energy orb) presented while the spell is formed.
@export var effect_scene: PackedScene
## The cast behaviour (a SpellCast scene: bolt, ground AoE, ...) run on commit.
@export var cast_scene: PackedScene
