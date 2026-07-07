class_name SpellForge

## Turns a set of runes into a spell (or a memorable accident).
##
## Outcome rules, tuned for discovery-through-experimentation:
## - A combo's stats and quirks are DETERMINISTIC: the same runes always forge
##   the same spell, so the spellbook is worth keeping.
## - Instability below QUIRK_THRESHOLD forges clean.
## - Above it, the spell works but picks up quirks (chosen by combo hash, so
##   they are a property of the recipe, not a dice roll).
## - In the gamble band below ALWAYS_BACKFIRE the forge MAY backfire on any
##   given attempt. At or above ALWAYS_BACKFIRE it always does; that fact is
##   discoverable and gets logged.
## - Hidden rare recipes trump everything and always forge stable.

const QUIRK_THRESHOLD := 0.35
const BACKFIRE_THRESHOLD := 0.55
const ALWAYS_BACKFIRE := 0.85
const BASE_POWER := 10.0
const BASE_SPEED := 14.0
const BASE_COST := 10.0

const QUIRK_POOL := ["wild_aim", "kickback", "screamer", "sputter"]
const BACKFIRE_POOL := ["frog", "blast", "demon", "scatter"]

## Combos with proper names. Keys are canonical combo keys (sorted rune ids).
static var _named_recipes := {
	SpellDefinition.make_combo_key(["fire", "orb", "bounce", "explode", "on_impact"]):
		"Bouncing Detonator",
	SpellDefinition.make_combo_key(["fire", "beam", "precise", "on_impact"]):
		"Ember Lance",
	SpellDefinition.make_combo_key(["ice", "shield", "on_impact"]):
		"Winter's Bulwark",
	SpellDefinition.make_combo_key(["lightning", "chain", "on_impact"]):
		"Arc Lash",
	SpellDefinition.make_combo_key(["shadow", "trap", "when_touched"]):
		"Umbral Snare",
	SpellDefinition.make_combo_key(["wind", "wave", "on_impact"]):
		"Gale Sweep",
	SpellDefinition.make_combo_key(["earth", "aura", "linger", "on_impact"]):
		"Bones of the Mountain",
}

## Hidden recipes found only by experimenting. Always stable, extra rewards.
static var _rare_recipes := {
	SpellDefinition.make_combo_key(["shadow", "aura", "linger", "silent", "on_impact"]): {
		"rare_id": "veil_of_the_quiet_dark",
		"name": "Veil of the Quiet Dark",
		"flavor": "The library goes quiet around you. So does everything else.",
		"power_scale": 1.2, "charge_bonus": 2,
	},
	SpellDefinition.make_combo_key(["lightning", "orb", "split", "home", "on_death"]): {
		"rare_id": "stormbrood",
		"name": "Stormbrood",
		"flavor": "Every ending hatches three more beginnings.",
		"power_scale": 1.4, "charge_bonus": 1,
	},
	SpellDefinition.make_combo_key(["earth", "orb", "home", "linger", "on_impact"]): {
		"rare_id": "pet_rock",
		"name": "Pet Rock",
		"flavor": "It is not useful. It is yours.",
		"power_scale": 0.5, "charge_bonus": 4,
	},
}

const BACKFIRE_LINES := {
	"frog": "The runes disagree. You are briefly a frog about it.",
	"blast": "The spell forges itself, facing the wrong way.",
	"demon": "Something small and useless answers the call.",
	"scatter": "The runes leap off the bench in protest.",
}


## Forge a spell from runes. Returns a Dictionary:
##   ok = true  -> { ok, definition: SpellDefinition, newly_named: String }
##   ok = false -> { ok, backfire: String, message: String, keep_runes: bool }
static func forge(runes: Array[RuneData], rng: RandomNumberGenerator = null) -> Dictionary:
	var problem := _validate(runes)
	if problem != "":
		return {"ok": false, "backfire": "", "message": problem, "keep_runes": true}

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var def := _build_definition(runes)
	var key := def.combo_key()
	var combo_seed := hash(key)

	var rare: Dictionary = _rare_recipes.get(key, {})
	if not rare.is_empty():
		def.rare_id = rare["rare_id"]
		def.spell_name = rare["name"]
		def.flavor = rare["flavor"]
		def.power *= rare.get("power_scale", 1.0)
		def.charges += rare.get("charge_bonus", 0)
		def.instability = minf(def.instability, QUIRK_THRESHOLD)
		return {"ok": true, "definition": def}

	if def.instability >= ALWAYS_BACKFIRE:
		return _backfire(combo_seed, true)
	if def.instability >= BACKFIRE_THRESHOLD:
		var chance := (def.instability - BACKFIRE_THRESHOLD) / (ALWAYS_BACKFIRE - BACKFIRE_THRESHOLD)
		if rng.randf() < chance * 0.8:
			return _backfire(combo_seed + rng.randi(), false)

	if def.instability >= QUIRK_THRESHOLD:
		_assign_quirks(def, combo_seed)

	def.spell_name = _named_recipes.get(key, _generate_name(def))
	return {"ok": true, "definition": def}


static func _validate(runes: Array[RuneData]) -> String:
	var counts := {}
	for rune in runes:
		counts[rune.rune_type] = counts.get(rune.rune_type, 0) + 1
	if counts.get(RuneData.RuneType.ELEMENT, 0) != 1:
		return "A spell needs exactly one element rune."
	if counts.get(RuneData.RuneType.SHAPE, 0) != 1:
		return "A spell needs exactly one shape rune."
	if counts.get(RuneData.RuneType.BEHAVIOR, 0) > 2:
		return "Two behavior runes at most."
	if counts.get(RuneData.RuneType.TRIGGER, 0) > 1:
		return "One trigger rune at most."
	if counts.get(RuneData.RuneType.MODIFIER, 0) > 2:
		return "Two modifier runes at most."
	return ""


static func _build_definition(runes: Array[RuneData]) -> SpellDefinition:
	var def := SpellDefinition.new()
	def.behavior_ids = PackedStringArray()
	def.modifier_ids = PackedStringArray()
	def.trigger_id = "on_impact"

	var power := BASE_POWER
	var speed := BASE_SPEED
	var size := 1.0
	var cost := BASE_COST
	var charges := 0
	var instability := 0.0

	for rune in runes:
		match rune.rune_type:
			RuneData.RuneType.ELEMENT:
				def.element_id = rune.id
			RuneData.RuneType.SHAPE:
				def.shape_id = rune.id
			RuneData.RuneType.BEHAVIOR:
				def.behavior_ids.append(rune.id)
			RuneData.RuneType.TRIGGER:
				def.trigger_id = rune.id
			RuneData.RuneType.MODIFIER:
				def.modifier_ids.append(rune.id)
		power *= rune.power_scale
		speed *= rune.speed_scale
		size *= rune.size_scale
		cost *= rune.cost_scale
		charges += rune.charge_bonus
		instability += rune.instability

	# Cramming many runes into one spell strains it beyond their own natures.
	instability += maxf(0.0, runes.size() - 4) * 0.05

	def.power = power
	def.speed = speed
	def.size = size
	def.essence_cost = int(round(cost))
	def.charges = maxi(1, charges)
	def.instability = clampf(instability, 0.0, 1.0)
	return def


static func _assign_quirks(def: SpellDefinition, combo_seed: int) -> void:
	var count := 1 + int((def.instability - QUIRK_THRESHOLD) / 0.25)
	var pool := QUIRK_POOL.duplicate()
	if def.is_silent():
		pool.erase("screamer")
	var rng := RandomNumberGenerator.new()
	rng.seed = combo_seed
	pool.sort()
	var picked := PackedStringArray()
	for i in mini(count, pool.size()):
		var idx := rng.randi_range(0, pool.size() - 1)
		picked.append(pool.pop_at(idx))
	def.quirks = picked


static func _backfire(seed_value: int, deterministic: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kind: String = BACKFIRE_POOL[rng.randi_range(0, BACKFIRE_POOL.size() - 1)]
	return {
		"ok": false,
		"backfire": kind,
		"message": BACKFIRE_LINES[kind],
		"keep_runes": kind == "scatter",
		"deterministic": deterministic,
	}


static func _generate_name(def: SpellDefinition) -> String:
	var element := def.element()
	var shape := def.shape()
	var words := PackedStringArray()
	for rune in def.behaviors():
		match rune.id:
			"bounce": words.append("Bouncing")
			"split": words.append("Splitting")
			"linger": words.append("Lingering")
			"home": words.append("Seeking")
			"pierce": words.append("Piercing")
	var name := " ".join(words)
	name += (" " if name != "" else "") + element.display_name + " " + shape.display_name
	if def.has_behavior("explode"):
		name += " of Detonation"
	elif def.trigger_id == "on_death":
		name += " of Last Rites"
	elif def.trigger_id == "when_recast":
		name += " of the Held Word"
	for rune in def.modifiers():
		match rune.id:
			"unstable": name = "Volatile " + name
			"raging": name = "Raging " + name
			"precise": name = "Keen " + name
			"silent": name = "Hushed " + name
	return name.strip_edges()
