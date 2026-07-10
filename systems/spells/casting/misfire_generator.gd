class_name MisfireGenerator
extends RefCounted


static func generate(spell: CompiledSpellData) -> CompiledSpellData:
	if spell == null:
		return null
	var result := spell.duplicate(true) as CompiledSpellData
	if not result.tags.has(&"misfire"):
		result.tags.append(&"misfire")

	match randi_range(0, 3):
		0:
			result.power *= 0.25
			result.tags.append(&"weak_misfire")
		1:
			result.radius *= 0.25
			result.duration *= 0.5
			result.tags.append(&"tiny_misfire")
		2:
			result.power *= 2.0
			result.tags.append(&"wild_misfire")
		3:
			result.tags.append(&"cosmetic_misfire")

	return result
