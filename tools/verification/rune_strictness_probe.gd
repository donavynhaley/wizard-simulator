extends SceneTree

## Tuning probe for the casting recognizer: scores noisy variants of each verb
## glyph and reports acceptance under the absolute-threshold and relative-
## margin rules. Run headless after touching glyphs, templates, or scoring:
##   godot --headless --path . -s tools/verification/rune_strictness_probe.gd
## threshold (0.75) versus a relative margin rule (best wins if it decisively
## beats the runner-up).

const TRIALS := 200
const THRESHOLD := 0.75
const MARGIN_FLOOR := 0.45
const MARGIN := 0.15


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var recognizer := ShapeRecognizer.new()
	for id in RuneGlyphs.VERBS:
		for strokes: Array in RuneGlyphs.exemplar_strokes(id):
			recognizer.add_template(id, strokes)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260723

	for noise_sigma in [0.02, 0.04, 0.06]:
		print("\n=== noise sigma ", noise_sigma, " (fraction of glyph size) ===")
		print("verb    | mean  p25   | acc@0.75 | acc@margin | wrong@0.75 | wrong@margin")
		for id in RuneGlyphs.VERBS:
			var scores: Array[float] = []
			var accept_threshold := 0
			var accept_margin := 0
			var wrong_threshold := 0
			var wrong_margin := 0
			for _t in TRIALS:
				var strokes := [_noisy_variant(RuneGlyphs.points(id), rng, noise_sigma)]
				var detailed := recognizer.evaluate_detailed(strokes)
				detailed.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
				var best := detailed[0]
				var best_score := float(best["score"])
				var correct: bool = best["id"] == id
				scores.append(best_score if correct else 0.0)
				if best_score >= THRESHOLD:
					accept_threshold += 1
					if not correct:
						wrong_threshold += 1
				# Margin acceptance goes through the REAL rule (resolve skips
				# same-verb exemplars for the runner-up) - never reimplement it.
				var resolution := recognizer.resolve(strokes, MARGIN_FLOOR, MARGIN)
				if bool(resolution["decisive"]):
					accept_margin += 1
					if resolution["id"] != id:
						wrong_margin += 1
			scores.sort()
			var mean := 0.0
			for s in scores:
				mean += s
			mean /= scores.size()
			var p25 := scores[scores.size() / 4]
			print("%-7s | %.2f  %.2f  | %5.1f%%   | %5.1f%%     | %d          | %d" % [
				id, mean, p25,
				100.0 * accept_threshold / TRIALS,
				100.0 * accept_margin / TRIALS,
				wrong_threshold, wrong_margin])
	quit(0)


## Resamples the glyph densely, then applies rotation, per-axis scale wobble,
## point jitter, and endpoint trimming - a rough model of a hand-drawn trace.
func _noisy_variant(
	glyph: PackedVector2Array, rng: RandomNumberGenerator, sigma: float,
) -> PackedVector2Array:
	var dense := _resample(glyph, 40)
	var centroid := Vector2.ZERO
	for p in dense:
		centroid += p
	centroid /= dense.size()

	var angle := rng.randfn(0.0, deg_to_rad(6.0))
	var scale := Vector2(
		1.0 + rng.randfn(0.0, 0.08), 1.0 + rng.randfn(0.0, 0.08))
	var out := PackedVector2Array()
	var start := 0
	var stop := dense.size()
	# Occasionally under-draw: lose up to 12% from one end.
	if rng.randf() < 0.35:
		if rng.randf() < 0.5:
			start = int(dense.size() * rng.randf_range(0.0, 0.12))
		else:
			stop = dense.size() - int(dense.size() * rng.randf_range(0.0, 0.12))
	for i in range(start, stop):
		var p := dense[i] - centroid
		p = p.rotated(angle) * scale
		p += Vector2(rng.randfn(0.0, sigma), rng.randfn(0.0, sigma))
		out.append(p + centroid)
	return out


func _resample(points: PackedVector2Array, count: int) -> PackedVector2Array:
	var lengths: Array[float] = [0.0]
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
		lengths.append(total)
	var out := PackedVector2Array()
	if total <= 0.0001:
		return points.duplicate()
	for i in count:
		var target := total * float(i) / float(count - 1)
		var j := 1
		while j < lengths.size() - 1 and lengths[j] < target:
			j += 1
		var span := lengths[j] - lengths[j - 1]
		var t := 0.0 if span <= 0.0001 else (target - lengths[j - 1]) / span
		out.append(points[j - 1].lerp(points[j], t))
	return out
