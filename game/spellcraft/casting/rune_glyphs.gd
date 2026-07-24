class_name RuneGlyphs
extends RefCounted

## The canonical glyphs of the five-verb rune language (game-bible.md rune
## table), shared by the casting recognizer (as fallback templates - recorded
## exemplars always win) and the journal (as drawing guides with playback).
## All glyphs are one stroke in unit-square coordinates.

const VERBS: Array[StringName] = [&"hurl", &"bind", &"sever", &"seal", &"open"]

const _INFO := {
	&"hurl": {
		"name": "Hurl",
		"glyph": "the Outward Spear",
		"meaning": "Weaponize carried essence and drive it outward.",
		"hint": "Thrust from the hand to the point, then cut both barbs. The element decides how the strike travels.",
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
		"hint": "The seal's ring, stopped three quarters of the way around, then hooked inward. The gap is the door; the hook is its handle.",
	},
}

## Stability tier boundaries for a trace score. Quality no longer gates whether
## a verb resolves (ambiguity does); it shapes how the spell expresses.
const STEADY_SCORE := 0.75
const WAVERING_SCORE := 0.6


static func stability_label(score: float) -> String:
	if score >= STEADY_SCORE:
		return "steady"
	if score >= WAVERING_SCORE:
		return "wavering"
	return "unstable"


static func display_name(id: StringName) -> String:
	return _INFO.get(id, {}).get("name", String(id).capitalize())


static func glyph_name(id: StringName) -> String:
	return _INFO.get(id, {}).get("glyph", "")


static func meaning(id: StringName) -> String:
	return _INFO.get(id, {}).get("meaning", "")


static func drawing_hint(id: StringName) -> String:
	return _INFO.get(id, {}).get("hint", "")


## Air traces have no horizon - nothing tells the hand where vertical is - and
## the bbox-normalized scorer is tilt-sensitive (a 12-degree tilt cost Bind
## half its score). Registering slightly tilted canon copies absorbs natural
## hand rotation for every verb.
const EXEMPLAR_TILT_DEGREES: Array[float] = [0.0, -14.0, 14.0]


## Canonical exemplar stroke-sets for a verb: the glyph plus tilted copies.
## Each entry is one template (an Array of strokes) for ShapeRecognizer.
static func exemplar_strokes(id: StringName) -> Array:
	var out: Array = []
	for tilt_degrees in _exemplar_tilts(id):
		out.append([_rotated(points(id), deg_to_rad(tilt_degrees))])
	return out


## Rings keep only the upright canon: Seal is rotation-symmetric (tilted copies
## are duplicates) and a tilted Open would swing its gap and hook into shapes
## that shadow sloppy Seals, shrinking Seal's margin for no leniency gain.
static func _exemplar_tilts(id: StringName) -> Array[float]:
	if id == &"seal" or id == &"open":
		return [0.0]
	return EXEMPLAR_TILT_DEGREES


static func _rotated(stroke: PackedVector2Array, angle: float) -> PackedVector2Array:
	if is_zero_approx(angle):
		return stroke
	var out := PackedVector2Array()
	var center := Vector2(0.5, 0.5)
	for point in stroke:
		out.append(center + (point - center).rotated(angle))
	return out


## Unit-square stroke for a verb's glyph.
static func points(id: StringName) -> PackedVector2Array:
	match id:
		&"hurl":
			return PackedVector2Array([
				Vector2(0.12, 0.78), Vector2(0.86, 0.22), Vector2(0.62, 0.24),
				Vector2(0.86, 0.22), Vector2(0.76, 0.45)])
		&"bind":
			return _eight()
		&"sever":
			return PackedVector2Array([
				Vector2(0.6, 0.0), Vector2(0.35, 0.4), Vector2(0.65, 0.5), Vector2(0.4, 1.0)])
		&"seal":
			return _ring(1.0)
		&"open":
			return _broken_ring_with_hook()
	return PackedVector2Array()


## Open's glyph: the broken ring, its loose end hooked deep inward toward the
## center. The hook is ink Seal never has, so an under-drawn circle can no
## longer read as Open - the two were a subset pair, and disambiguating them by
## absolute strictness was what made every verb feel harsh. The hook reaches
## well inside the ring on purpose: a shallow tick normalizes away.
static func _broken_ring_with_hook() -> PackedVector2Array:
	var out := _ring(0.75)
	var tail := out[out.size() - 1]
	var inward := (Vector2(0.5, 0.5) - tail).normalized()
	out.append(tail + inward * 0.12)
	out.append(tail + inward * 0.24)
	out.append(tail + inward * 0.36)
	return out


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
