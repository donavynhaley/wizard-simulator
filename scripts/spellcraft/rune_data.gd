class_name RuneData
extends Resource

## One modular rune. Spells are forged from a set of these at a SpellBench.
## Runes are defined centrally in RuneCatalog; RuneStone props reference them by id.

enum RuneType { ELEMENT, SHAPE, BEHAVIOR, TRIGGER, MODIFIER }

const TYPE_NAMES := {
	RuneType.ELEMENT: "Element",
	RuneType.SHAPE: "Shape",
	RuneType.BEHAVIOR: "Behavior",
	RuneType.TRIGGER: "Trigger",
	RuneType.MODIFIER: "Modifier",
}

@export var id: String = ""
@export var rune_type: RuneType = RuneType.ELEMENT
@export var display_name: String = ""
@export_multiline var description: String = ""
## Single glyph carved on the rune stone (Greek letters render in the default font).
@export var glyph: String = "?"
@export var color: Color = Color.WHITE
## How much this rune destabilizes a spell (0..1 scale, summed at the forge).
@export var instability: float = 0.0
@export var power_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var size_scale: float = 1.0
@export var cost_scale: float = 1.0
@export var charge_bonus: int = 0
## Free-form flags read by the runtime: "silent", "wild", "precise", "raging",
## "push", "chill", "delayed", ...
@export var tags: PackedStringArray = PackedStringArray()


func type_name() -> String:
	return TYPE_NAMES[rune_type]


func has_tag(tag: String) -> bool:
	return tags.has(tag)
