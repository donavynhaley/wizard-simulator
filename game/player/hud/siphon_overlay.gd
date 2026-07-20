class_name SiphonOverlay
extends Control

## Draws a ring at each on-screen element source (siphonable), filling a progress
## arc on the one the sketch cursor is dwelling over. Fed by CastingController.

const RING_RADIUS := 18.0

var _markers: Array = []


func set_markers(markers: Array) -> void:
	_markers = markers
	queue_redraw()


func _draw() -> void:
	for m in _markers:
		var pos: Vector2 = m["pos"]
		var col: Color = m["color"]
		var progress: float = m["progress"]
		if m.get("empty", false):
			# An empty vessel: thin hollow outline, waiting to be refilled.
			draw_arc(pos, RING_RADIUS, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.14), 1.5, true)
			draw_arc(pos, RING_RADIUS * 0.45, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.22), 1.0, true)
			continue
		# Faint base ring marks a siphonable source on screen.
		draw_arc(pos, RING_RADIUS, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.3), 2.0, true)
		if progress > 0.0:
			# Progress fills clockwise from the top as the cursor dwells.
			draw_arc(pos, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, 48,
				Color(col.r, col.g, col.b, 0.95), 4.0, true)
		if progress >= 1.0:
			# Completion: a filled core so the player knows they got it.
			draw_circle(pos, RING_RADIUS * 0.4, Color(col.r, col.g, col.b, 0.9))
