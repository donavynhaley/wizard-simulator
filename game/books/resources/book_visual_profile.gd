class_name BookVisualProfile
extends Resource

## Read-only presentation data for one family of book models.
## Imported scenes can use any origin, scale, or axis convention because their
## correction transforms live here instead of leaking into BookVisual.

@export_group("Models")
@export var closed_model_scene: PackedScene
@export var open_model_scene: PackedScene
@export var closed_model_transform: Transform3D = Transform3D.IDENTITY
@export var open_model_transform: Transform3D = Transform3D.IDENTITY

@export_group("Open Page Geometry")
@export var page_geometry_transform: Transform3D = Transform3D(
	Basis.IDENTITY,
	Vector3(0.0, 0.0175, 0.0))
@export var spread_size: Vector2 = Vector2(0.36, 0.18)
@export_range(0.0, 0.04, 0.001) var spine_gap: float = 0.006
@export_range(0.0, 0.04, 0.001) var page_curve_height: float = 0.012
@export_range(0.001, 0.04, 0.001) var page_stack_thickness: float = 0.009
@export_range(4, 32, 1) var page_segments: int = 14
@export_range(0.2, 1.5, 0.01) var page_turn_seconds: float = 0.58

@export_group("Presentation Poses")
@export var world_pose: Transform3D = Transform3D.IDENTITY
@export var held_pose: Transform3D = Transform3D(
	Basis.from_euler(Vector3(1.08, 0.0, -0.12)).scaled(Vector3.ONE * 1.15),
	Vector3(-0.04, 0.025, -0.105))
@export var reading_pose: Transform3D = Transform3D(
	Basis.from_euler(Vector3(1.24, 0.0, 0.0)).scaled(Vector3.ONE * 1.3),
	Vector3(-0.265, -0.08, -0.02))
@export var close_focus_pose: Transform3D = Transform3D(
	Basis.from_euler(Vector3(1.3, 0.0, 0.0)).scaled(Vector3.ONE * 1.62),
	Vector3(-0.265, -0.035, 0.065))
@export var table_pose: Transform3D = Transform3D(
	Basis.IDENTITY.scaled(Vector3.ONE * 0.85),
	Vector3.ZERO)

@export_group("Hand Contacts")
@export var left_hand_grip: Transform3D = Transform3D(
	Basis.from_euler(Vector3(0.0, 0.0, -1.35)),
	Vector3(-0.155, 0.008, 0.065))
@export var right_hand_grip: Transform3D = Transform3D(
	Basis.from_euler(Vector3(0.0, 0.0, 1.35)),
	Vector3(0.155, 0.008, 0.065))

@export_group("Reading Motion")
@export_range(0.0, 0.02, 0.0005) var breathing_lift: float = 0.003
@export_range(0.0, 3.0, 0.05) var breathing_speed: float = 0.8
@export_range(0.0, 2.0, 0.05) var sway_degrees: float = 0.35

@export_group("Optional Audio")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var page_turn_sound: AudioStream
