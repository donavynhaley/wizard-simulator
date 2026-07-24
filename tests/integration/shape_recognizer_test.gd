extends SceneTree

## Regression coverage for live air-rune recognition. Hurl's arrowhead must be
## present, while scale, position, and drawing direction remain irrelevant.

const MATCH_THRESHOLD := 0.75
const COMFORTABLE_MATCH_SCORE := 0.78

var _fail := 0


func _init() -> void:
	var recognizer := ShapeRecognizer.new()
	for id in RuneGlyphs.VERBS:
		recognizer.add_template(id, [RuneGlyphs.points(id)])

	var canonical_hurl := RuneGlyphs.points(&"hurl")
	_check(_score_for(recognizer, [canonical_hurl], &"hurl") > 0.95,
		"the canonical Outward Spear recognizes as Hurl")
	var reversed_hurl := canonical_hurl.duplicate()
	reversed_hurl.reverse()
	_check(_score_for(recognizer, [reversed_hurl], &"hurl") > 0.95,
		"Hurl recognition remains direction invariant")
	var hand_drawn_hurl := PackedVector2Array([
		Vector2(98.0, 302.0), Vector2(306.0, 94.0), Vector2(235.0, 101.0),
		Vector2(306.0, 94.0), Vector2(278.0, 177.0),
	])
	_check(_score_for(recognizer, [hand_drawn_hurl], &"hurl") >= MATCH_THRESHOLD,
		"a slightly uneven complete Hurl remains castable")
	var split_hurl: Array = [
		PackedVector2Array([Vector2(0.12, 0.78), Vector2(0.86, 0.22)]),
		PackedVector2Array([Vector2(0.62, 0.24), Vector2(0.86, 0.22), Vector2(0.76, 0.45)]),
	]
	_check(_score_for(recognizer, split_hurl, &"hurl") >= MATCH_THRESHOLD,
		"a complete Hurl remains castable when its shaft and arrowhead are separate strokes")
	var broad_hand_drawn_hurl: Array = [
		PackedVector2Array([Vector2(100.0, 300.0), Vector2(300.0, 100.0)]),
		PackedVector2Array([Vector2(205.0, 112.0), Vector2(300.0, 100.0),
			Vector2(258.0, 215.0)]),
	]
	_check(_score_for(recognizer, broad_hand_drawn_hurl, &"hurl") >= COMFORTABLE_MATCH_SCORE,
		"a broad asymmetric hand-drawn arrowhead remains castable")
	var skewed_hand_drawn_hurl: Array = [
		PackedVector2Array([Vector2(112.0, 306.0), Vector2(318.0, 82.0)]),
		PackedVector2Array([Vector2(226.0, 111.0), Vector2(318.0, 82.0),
			Vector2(274.0, 196.0)]),
	]
	_check(_score_for(recognizer, skewed_hand_drawn_hurl, &"hurl") >= COMFORTABLE_MATCH_SCORE,
		"a skewed two-stroke Hurl remains castable")

	var ascending_line := PackedVector2Array([
		Vector2(100.0, 300.0), Vector2(300.0, 100.0),
	])
	_check(_score_for(recognizer, [ascending_line], &"hurl") < MATCH_THRESHOLD,
		"a 45-degree line without arrowhead cuts does not recognize as Hurl")
	var wobbly_line := PackedVector2Array([
		Vector2(100.0, 300.0), Vector2(145.0, 252.0), Vector2(198.0, 205.0),
		Vector2(249.0, 151.0), Vector2(300.0, 100.0),
	])
	_check(_score_for(recognizer, [wobbly_line], &"hurl") < MATCH_THRESHOLD,
		"a slightly wobbly diagonal without arrowhead cuts does not recognize as Hurl")
	var partial_hurl := PackedVector2Array([
		Vector2(0.12, 0.78), Vector2(0.86, 0.22), Vector2(0.62, 0.24),
	])
	_check(_score_for(recognizer, [partial_hurl], &"hurl") < MATCH_THRESHOLD,
		"a Hurl missing either arrowhead cut remains incomplete")
	var broad_partial_hurl: Array = [
		PackedVector2Array([Vector2(100.0, 300.0), Vector2(300.0, 100.0)]),
		PackedVector2Array([Vector2(300.0, 100.0), Vector2(190.0, 112.0)]),
	]
	_check(_score_for(recognizer, broad_partial_hurl, &"hurl") < MATCH_THRESHOLD,
		"one broad arrowhead cut cannot substitute for both Hurl cuts")

	if _fail == 0:
		print("SHAPE RECOGNIZER TEST OK")
	quit(_fail)


func _score_for(
	recognizer: ShapeRecognizer,
	strokes: Array,
	rune_id: StringName,
) -> float:
	for candidate in recognizer.evaluate_detailed(strokes):
		if candidate["id"] == rune_id:
			return float(candidate["score"])
	return 0.0


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1
