class_name SpellDefinition
extends Resource

## A finished spell as it exists on a scroll. Produced by SpellForge from a set
## of runes; consumed by SpellCast when a scroll is used.

@export var spell_name: String = "Unnamed Spell"
@export var element_id: String = "fire"
@export var shape_id: String = "orb"
@export var behavior_ids: PackedStringArray = PackedStringArray()
@export var trigger_id: String = "on_impact"
@export var modifier_ids: PackedStringArray = PackedStringArray()

@export var power: float = 10.0
@export var speed: float = 14.0
@export var size: float = 1.0
@export var charges: int = 3
@export var essence_cost: int = 10
@export var instability: float = 0.0
## Deterministic side effects earned by overloading the forge:
## "wild_aim", "kickback", "screamer", "sputter".
@export var quirks: PackedStringArray = PackedStringArray()
## Set when the combo matched a hidden rare recipe.
@export var rare_id: String = ""
@export_multiline var flavor: String = ""


func element() -> RuneData:
	return RuneCatalog.get_rune(element_id)


func shape() -> RuneData:
	return RuneCatalog.get_rune(shape_id)


func trigger() -> RuneData:
	return RuneCatalog.get_rune(trigger_id)


func behaviors() -> Array[RuneData]:
	var out: Array[RuneData] = []
	for id in behavior_ids:
		out.append(RuneCatalog.get_rune(id))
	return out


func modifiers() -> Array[RuneData]:
	var out: Array[RuneData] = []
	for id in modifier_ids:
		out.append(RuneCatalog.get_rune(id))
	return out


func all_rune_ids() -> PackedStringArray:
	var ids := PackedStringArray([element_id, shape_id])
	ids.append_array(behavior_ids)
	ids.append(trigger_id)
	ids.append_array(modifier_ids)
	return ids


func has_behavior(id: String) -> bool:
	return behavior_ids.has(id)


func has_rune_tag(tag: String) -> bool:
	for id in all_rune_ids():
		var rune := RuneCatalog.get_rune(id)
		if rune and rune.has_tag(tag):
			return true
	return false


func has_quirk(id: String) -> bool:
	return quirks.has(id)


## Canonical key for the discovery journal: order within a category never matters.
func combo_key() -> String:
	return SpellDefinition.make_combo_key(all_rune_ids())


static func make_combo_key(rune_ids: PackedStringArray) -> String:
	var ids := Array(rune_ids)
	ids.sort()
	return "+".join(PackedStringArray(ids))


# --- Visual personality -------------------------------------------------------

func primary_color() -> Color:
	var rune := element()
	return rune.color if rune else Color.WHITE


## How jagged and loud the spell looks (0 = smooth, 1 = furious).
func jaggedness() -> float:
	var j := 0.0
	if has_rune_tag("raging"):
		j += 0.6
	if has_rune_tag("wild"):
		j += 0.4
	return clampf(j + instability * 0.3, 0.0, 1.0)


## Precise spells render thin and focused.
func thinness() -> float:
	return 0.6 if has_rune_tag("precise") else 0.0


func is_silent() -> bool:
	return has_rune_tag("silent") or has_rune_tag("quiet")


func summary() -> String:
	var parts := PackedStringArray()
	for id in all_rune_ids():
		var rune := RuneCatalog.get_rune(id)
		parts.append(rune.display_name if rune else id)
	return "%s  [%s]  power %.0f, %d charges, instability %.0f%%" % [
		spell_name, " + ".join(parts), power, charges, instability * 100.0]
