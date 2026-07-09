class_name CastOnUseSeal
extends SealDefinition


func handle_cast_request(_spell: CompiledSpellData, _context: SpellCastContext) -> Dictionary:
	return {
		"execute_now": true,
		"consumes_charge": true,
	}
