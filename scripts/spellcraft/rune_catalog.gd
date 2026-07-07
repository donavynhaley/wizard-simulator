class_name RuneCatalog

## Central definition of every rune in the game. Edit numbers here to rebalance;
## RuneStone props and the SpellBench all read from this catalog by id.

static var _runes: Dictionary = {}


static func get_rune(id: String) -> RuneData:
	_ensure()
	return _runes.get(id)


static func all_runes() -> Array[RuneData]:
	_ensure()
	var out: Array[RuneData] = []
	for id: String in _runes:
		out.append(_runes[id])
	return out


static func runes_of_type(rune_type: RuneData.RuneType) -> Array[RuneData]:
	var out: Array[RuneData] = []
	for rune in all_runes():
		if rune.rune_type == rune_type:
			out.append(rune)
	return out


static func _ensure() -> void:
	if not _runes.is_empty():
		return

	# --- Elements -------------------------------------------------------------
	_element("fire", "Fire", "Hungry and loud. Burns what it touches.", "Φ",
		Color(1.0, 0.45, 0.15), 0.10, {"power_scale": 1.25})
	_element("ice", "Ice", "Patient cold. Slow, but it always arrives.", "Ψ",
		Color(0.55, 0.85, 1.0), 0.05, {"power_scale": 0.9, "speed_scale": 0.85, "tags": ["chill"]})
	_element("lightning", "Lightning", "Fast, bright, and rude.", "Ζ",
		Color(1.0, 0.95, 0.4), 0.18, {"power_scale": 1.4, "speed_scale": 1.6})
	_element("shadow", "Shadow", "Magic that prefers not to be seen.", "Ω",
		Color(0.5, 0.25, 0.75), 0.14, {"tags": ["quiet"]})
	_element("wind", "Wind", "Weak on its own, but it moves things.", "Σ",
		Color(0.7, 1.0, 0.85), 0.06, {"power_scale": 0.7, "speed_scale": 1.4, "tags": ["push"]})
	_element("earth", "Earth", "Slow, heavy, dependable.", "Θ",
		Color(0.72, 0.52, 0.28), 0.03, {"power_scale": 1.1, "speed_scale": 0.7, "size_scale": 1.3})

	# --- Shapes ---------------------------------------------------------------
	_shape("beam", "Beam", "A straight lance of magic from the hand.", "Ι",
		{"power_scale": 0.9, "charge_bonus": 4, "cost_scale": 1.2})
	_shape("orb", "Orb", "A thrown sphere. The classic.", "Ο",
		{"charge_bonus": 5, "cost_scale": 1.0})
	_shape("wave", "Wave", "A ring that sweeps outward from the caster.", "Υ",
		{"power_scale": 0.8, "charge_bonus": 3, "cost_scale": 1.4})
	_shape("trap", "Trap", "A patient circle laid on the ground.", "Χ",
		{"power_scale": 1.2, "charge_bonus": 3, "cost_scale": 1.2})
	_shape("shield", "Shield", "A dome that keeps spells out.", "Π",
		{"power_scale": 0.5, "charge_bonus": 2, "cost_scale": 1.6})
	_shape("chain", "Chain", "Magic that leaps from target to target.", "Γ",
		{"power_scale": 0.85, "charge_bonus": 3, "cost_scale": 1.6, "instability": 0.08})
	_shape("aura", "Aura", "A presence that clings to the caster.", "Α",
		{"power_scale": 0.5, "charge_bonus": 2, "cost_scale": 1.8})

	# --- Behaviors --------------------------------------------------------------
	_behavior("bounce", "Bounce", "Rebounds from surfaces instead of stopping.", "β", 0.06)
	_behavior("split", "Split", "Breaks into smaller copies when it triggers.", "ψ", 0.10)
	_behavior("linger", "Linger", "The magic stays behind and keeps working.", "λ", 0.04)
	_behavior("home", "Home", "Seeks the nearest target on its own.", "μ", 0.08)
	_behavior("explode", "Explode", "Ends in a detonation.", "δ", 0.08)
	_behavior("pierce", "Pierce", "Passes through targets instead of stopping.", "ξ", 0.05)

	# --- Triggers ---------------------------------------------------------------
	_trigger("on_impact", "On Impact", "Acts the moment it hits something.", "τ", 0.0)
	_trigger("on_timer", "On Timer", "Waits on a short fuse, then acts.", "η", 0.04)
	_trigger("on_death", "On Death", "Acts when something nearby dies.", "ν", 0.10)
	_trigger("when_touched", "When Touched", "Waits until something steps in.", "κ", 0.02)
	_trigger("when_recast", "When Recast", "Waits for the caster's word.", "ρ", 0.08)

	# --- Modifiers ----------------------------------------------------------------
	_modifier("bigger", "Bigger", "More spell. Slightly slower spell.", "+", 0.06,
		{"size_scale": 1.6, "power_scale": 1.25, "speed_scale": 0.85})
	_modifier("faster", "Faster", "Arrives before second thoughts.", ">", 0.06,
		{"speed_scale": 1.5})
	_modifier("cheaper", "Cheaper", "Cut corners. Mostly safe corners.", "-", 0.05,
		{"cost_scale": 0.6, "power_scale": 0.85})
	_modifier("unstable", "Unstable", "Much stronger. No promises.", "!", 0.22,
		{"power_scale": 1.6, "tags": ["wild"]})
	_modifier("silent", "Silent", "The spell keeps its voice down.", "~", 0.0,
		{"cost_scale": 1.15, "power_scale": 0.95, "tags": ["silent"]})
	_modifier("delayed", "Delayed", "Strikes late, and harder for the wait.", ":", 0.04,
		{"power_scale": 1.3, "tags": ["delayed"]})
	_modifier("charged", "Charged", "The scroll holds more castings.", "#", 0.05,
		{"cost_scale": 1.4, "charge_bonus": 3})
	_modifier("precise", "Precise", "Thin, quick, and exactly where aimed.", "|", -0.05,
		{"size_scale": 0.55, "speed_scale": 1.35, "power_scale": 1.1, "tags": ["precise"]})
	_modifier("raging", "Raging", "Jagged, loud, and proud of it.", "*", 0.12,
		{"power_scale": 1.5, "size_scale": 1.2, "tags": ["raging"]})


static func _element(id: String, display: String, desc: String, glyph: String,
		color: Color, instability: float, extra: Dictionary = {}) -> void:
	_add(id, RuneData.RuneType.ELEMENT, display, desc, glyph, color, instability, extra)


static func _shape(id: String, display: String, desc: String, glyph: String,
		extra: Dictionary = {}) -> void:
	_add(id, RuneData.RuneType.SHAPE, display, desc, glyph, Color(0.85, 0.8, 0.95),
		extra.get("instability", 0.0), extra)


static func _behavior(id: String, display: String, desc: String, glyph: String,
		instability: float, extra: Dictionary = {}) -> void:
	_add(id, RuneData.RuneType.BEHAVIOR, display, desc, glyph, Color(0.65, 0.9, 0.75),
		instability, extra)


static func _trigger(id: String, display: String, desc: String, glyph: String,
		instability: float, extra: Dictionary = {}) -> void:
	_add(id, RuneData.RuneType.TRIGGER, display, desc, glyph, Color(0.95, 0.85, 0.55),
		instability, extra)


static func _modifier(id: String, display: String, desc: String, glyph: String,
		instability: float, extra: Dictionary = {}) -> void:
	_add(id, RuneData.RuneType.MODIFIER, display, desc, glyph, Color(0.9, 0.65, 0.85),
		instability, extra)


static func _add(id: String, rune_type: RuneData.RuneType, display: String, desc: String,
		glyph: String, color: Color, instability: float, extra: Dictionary) -> void:
	var rune := RuneData.new()
	rune.id = id
	rune.rune_type = rune_type
	rune.display_name = display
	rune.description = desc
	rune.glyph = glyph
	rune.color = color
	rune.instability = instability
	rune.power_scale = extra.get("power_scale", 1.0)
	rune.speed_scale = extra.get("speed_scale", 1.0)
	rune.size_scale = extra.get("size_scale", 1.0)
	rune.cost_scale = extra.get("cost_scale", 1.0)
	rune.charge_bonus = extra.get("charge_bonus", 0)
	rune.tags = PackedStringArray(extra.get("tags", []))
	_runes[id] = rune
