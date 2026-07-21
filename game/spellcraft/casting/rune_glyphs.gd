class_name RuneGlyphs
extends RefCounted

## The canonical glyphs of the six-verb rune language (game-bible.md rune
## table), shared by the casting recognizer (as fallback templates - recorded
## exemplars always win) and the journal (as drawing guides with playback).
## All glyphs are one stroke in unit-square coordinates.

const VERBS: Array[StringName] = [&"draw", &"pour", &"bind", &"sever", &"seal", &"open"]

const _INFO := {
	&"draw": {
		"name": "Draw",
		"glyph": "the Inward Spiral",
		"meaning": "Pull essence out of a subject and into the off hand.",
		"hint": "Coil inward to the centre, two full turns or more. Everything converges on the hand.",
	},
	&"pour": {
		"name": "Pour",
		"glyph": "the Falling Triangle",
		"meaning": "Push carried essence into a subject, or send it home to an empty vessel.",
		"hint": "Across the top, then down to the point. The tipped cup narrows to where it goes.",
	},
	&"bind": {
		"name": "Bind",
		"glyph": "the Knot",
		"meaning": "Create a link between two subjects.",
		"hint": "One flowing figure-eight: two lobes tied by a single crossing.",
	},
	&"sever": {
		"name": "Sever",
		"glyph": "the Lightning Slash",
		"meaning": "Cut a link.",
		"hint": "A tall jagged slash, drawn fast. Cut through the knot; do not draw it, strike it.",
	},
	&"seal": {
		"name": "Seal",
		"glyph": "the Ritual Circle",
		"meaning": "Close a boundary: wards, locks, containment.",
		"hint": "One calm, closed ring. Deliberate. A seal left unclosed is an opening.",
	},
	&"open": {
		"name": "Open",
		"glyph": "the Broken Ring",
		"meaning": "Undo a boundary.",
		"hint": "The seal's ring, stopped three quarters of the way around. The gap is the door.",
	},
}


static func display_name(id: StringName) -> String:
	return _INFO.get(id, {}).get("name", String(id).capitalize())


static func glyph_name(id: StringName) -> String:
	return _INFO.get(id, {}).get("glyph", "")


static func meaning(id: StringName) -> String:
	return _INFO.get(id, {}).get("meaning", "")


static func drawing_hint(id: StringName) -> String:
	return _INFO.get(id, {}).get("hint", "")


## Unit-square stroke for a verb's glyph.
static func points(id: StringName) -> PackedVector2Array:
	match id:
		&"draw":
			return _spiral()
		&"pour":
			return PackedVector2Array([
				Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0), Vector2(0.0, 0.0)])
		&"bind":
			return _eight()
		&"sever":
			return PackedVector2Array([
				Vector2(0.6, 0.0), Vector2(0.35, 0.4), Vector2(0.65, 0.5), Vector2(0.4, 1.0)])
		&"seal":
			return _ring(1.0)
		&"open":
			return _ring(0.75)
	return PackedVector2Array()


## A RuneTemplate of the glyph, for journal pages and anywhere else that wants
## stroke playback of the canonical form. RuneTemplate stores normalized [0,1]
## coordinates, which is the glyphs' native space.
static func template(id: StringName) -> RuneTemplate:
	var out := RuneTemplate.new()
	out.rune_id = String(id)
	out.display_name = display_name(id)
	var strokes: Array[PackedVector2Array] = [points(id)]
	out.set_strokes(strokes)
	return out


## Draw's glyph: 2.25 turns coiling to the centre. The coil must fill the
## interior so it separates cleanly from Seal's empty ring.
static func _spiral() -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var t := float(i) / float(steps)
		var angle := t * TAU * 2.25
		var radius := 0.5 * (1.0 - 0.85 * t)
		out.append(Vector2(0.5 + radius * cos(angle), 0.5 + radius * sin(angle)))
	return out


## Bind's glyph: a vertical figure-eight, two lobes joined by a crossing.
static func _eight() -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		out.append(Vector2(0.5 + 0.3 * sin(2.0 * a), 0.5 + 0.45 * cos(a)))
	return out


## Seal's closed ring (closure 1.0) and Open's broken ring (closure 0.75:
## the missing quarter is the door).
static func _ring(closure: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 48
	var start := TAU * (1.0 - closure) * 0.5
	for i in steps + 1:
		var a := start + TAU * closure * float(i) / float(steps)
		out.append(Vector2(0.5 + 0.45 * cos(a), 0.5 + 0.45 * sin(a)))
	return out
