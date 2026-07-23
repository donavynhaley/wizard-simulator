class_name SiphonOverlay
extends Control

## Draws a Sight ring at each on-screen element source and a diamond at each
## binding strand. The aimed marker brightens and expands; a pull hold sweeps a
## fill arc; a completed transfer leaves a brief expanding flash. During an
## attunement the diamond breathes with the approaching read-pulse, shakes on a
## miss, and every other marker dims - the world recedes around the one thread
## you are gripping. A hollow inner ring marks an empty vessel.

const RING_RADIUS := 18.0

var _markers: Array = []


func set_markers(markers: Array) -> void:
	_markers = markers
	queue_redraw()


func _draw() -> void:
	for m in _markers:
		var pos: Vector2 = m["pos"]
		var col: Color = m["color"]
		var dim: float = 0.3 if m.get("dim", false) else 1.0
		if m.has("flash"):
			# The transfer landed: one expanding, thinning, fading ring.
			var t: float = m["flash"]
			draw_arc(pos, RING_RADIUS * (1.0 + 0.9 * t), 0.0, TAU, 48,
				Color(col.r, col.g, col.b, (1.0 - t) * 0.85),
				0.5 + 3.0 * (1.0 - t), true)
			continue
		var aimed: bool = m.get("aimed", false)
		var progress: float = m.get("progress", 0.0)
		var radius := RING_RADIUS * (1.12 if aimed else 1.0)
		if m.get("kind", "") == "anchor":
			# A link anchor (Bind mode): a bracket the thread can grab. Held
			# anchors (thread already grabbed) show a filled centre.
			var reach := radius * (1.0 if aimed else 0.8)
			var acol := Color(col.r, col.g, col.b, 0.85 if aimed else 0.4)
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var c: Vector2 = pos + corner * reach
				draw_line(c, c - corner * Vector2(reach * 0.45, 0), acol, 2.0)
				draw_line(c, c - corner * Vector2(0, reach * 0.45), acol, 2.0)
			if m.get("held", false):
				draw_circle(pos, 3.5, Color(col.r, col.g, col.b, 0.9))
			continue
		if m.get("kind", "") == "link":
			# A strand's aim point: a diamond, dotted centre once studied.
			# It breathes as the read-pulse nears and flares inside the window.
			var glow: float = m.get("window_glow", 0.0)
			var in_window: bool = m.get("window", false)
			pos.x += m.get("shake_x", 0.0)
			var half := radius * (0.85 + 0.18 * glow + (0.07 if in_window else 0.0))
			var alpha := 0.9 if aimed else 0.55
			alpha = maxf(alpha, 0.5 + 0.5 * glow)
			if in_window:
				alpha = 0.95
			var points := PackedVector2Array([
				pos + Vector2(0.0, -half), pos + Vector2(half, 0.0),
				pos + Vector2(0.0, half), pos + Vector2(-half, 0.0),
				pos + Vector2(0.0, -half)])
			draw_polyline(points, Color(col.r, col.g, col.b, alpha * dim),
				(3.5 if in_window else (2.5 if aimed else 2.0)) + 1.2 * glow, true)
			if m.get("analyzed", false):
				draw_circle(pos, 2.5, Color(col.r, col.g, col.b, 0.6 * dim))
			if progress > 0.0:
				draw_arc(pos, half * 0.7, -PI * 0.5, -PI * 0.5 + TAU * progress, 40,
					Color(minf(col.r * 1.3, 1.0), minf(col.g * 1.3, 1.0),
						minf(col.b * 1.3, 1.0), 0.9 * dim), 3.0, true)
			continue
		# Element sources signify in-world (their vessel's rim burns the element's
		# colour in Sight), so the HUD no longer paints a ring per source. All
		# that remains here is the pull gauge while the aimed source siphons.
		if progress > 0.0:
			# The hold gauge: sweeps from twelve o'clock as the pull commits.
			draw_arc(pos, radius * 0.78, -PI * 0.5, -PI * 0.5 + TAU * progress, 40,
				Color(minf(col.r * 1.3, 1.0), minf(col.g * 1.3, 1.0),
					minf(col.b * 1.3, 1.0), 0.9 * dim), 3.0, true)
