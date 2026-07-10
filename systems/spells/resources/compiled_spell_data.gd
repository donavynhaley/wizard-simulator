class_name CompiledSpellData
extends Resource

@export var spell_id: StringName = &""
@export var display_name: String = ""

@export var element: ElementDefinition
@export var form: FormDefinition
@export var effects: Array[EffectDefinition] = []
@export var modifiers: Array[ModifierDefinition] = []
@export var ink: InkDefinition
@export var seal: SealDefinition

@export var power: float = 1.0
@export var speed: float = 1.0
@export var radius: float = 1.0
@export var duration: float = 1.0
@export var range: float = 10.0

@export var repeats: int = 1
@export var forks: int = 0
@export var chain_count: int = 0
@export var homing_strength: float = 0.0

@export var tags: Array[StringName] = []


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
