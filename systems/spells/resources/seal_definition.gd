class_name SealDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var trigger_scene: PackedScene


func handle_cast_request(_spell: CompiledSpellData, _context: SpellCastContext) -> Dictionary:
	return {
		"execute_now": true,
		"consumes_charge": true,
	}
