class_name SketchStroke
extends RefCounted

## One drawn stroke in an air-cast rune: its captured cursor points (viewport
## pixels) plus its age. A single age drives both the visual fade and the
## stroke's inclusion in recognition, so a stroke dims and drops out together.

var points: PackedVector2Array = PackedVector2Array()
## Per-point age, parallel to points; the point at the cursor is youngest. Each
## point fades and expires on its own so the ink trails behind the cursor and
## drops off the tail, instead of the whole stroke expiring as one block.
var point_ages: PackedFloat32Array = PackedFloat32Array()
## True once this stroke was part of a recognized rune: it keeps rendering (in
## the recognized tint) while it fades, but no longer counts toward recognition.
var consumed: bool = false
