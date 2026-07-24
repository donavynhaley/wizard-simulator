class_name WizardPlayer
extends CharacterBody3D

## First-person wizard composition root. Locomotion, mouse look, and
## interaction live on child nodes. The viewmodel (hat brim + arms) sits
## directly under the camera; all posing is authored in the editor.

const LocomotionComponent := preload("res://game/player/components/wizard_locomotion.gd")
const LookComponent := preload("res://game/player/components/wizard_look.gd")

@onready var locomotion: LocomotionComponent = $Components/Locomotion
@onready var look: LookComponent = $Components/Look
@onready var viewmodel_motion: ViewmodelMotion = $Components/ViewmodelMotion
@onready var sight: SightController = $Components/SightController
@onready var element_hand: ElementHandController = $Components/ElementHandController
@onready var casting: CastingController = $Components/CastingController
@onready var health: HealthComponent = $Components/HealthComponent
@onready var head: Node3D = $Head
@onready var viewmodel: Node3D = $Head/Camera3D/Viewmodel
@onready var hud: WizardHud = $WizardHud
var look_enabled := true

## Typed accessor for the scene-unique interactor. A plain getter keeps this
## safe regardless of sibling ready order.
var interactor: PlayerInteractor:
	get: return get_node_or_null(^"Head/Camera3D/Interactor") as PlayerInteractor

var _control_enabled: bool = true


func _ready() -> void:
	assert(locomotion != null, "WizardPlayer requires a Locomotion component.")
	assert(look != null, "WizardPlayer requires a Look component.")
	hud.configure(interactor)
	viewmodel_motion.configure(self, head, viewmodel.get_node(^"WizardHat"))
	sight.element_action_requested.connect(element_hand.interact_with_source)
	sight.element_pull_started.connect(element_hand.on_pull_started)
	sight.element_pull_updated.connect(element_hand.on_pull_updated)
	sight.element_pull_canceled.connect(element_hand.on_pull_canceled)
	casting.hurl_requested.connect(_on_hurl_requested)
	_capture_mouse.call_deferred()

func control_enabled() -> bool:
	return _control_enabled


## Freezes or resumes the player wholesale. Stations that take over the camera
## call this instead of reaching into individual player components.
func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		locomotion.reset(self)
	set_physics_process(enabled)
	set_process_input(enabled)
	set_process_unhandled_input(enabled)
	if interactor != null:
		interactor.set_active(enabled)


func apply_mouse_look(relative: Vector2) -> void:
	if not look_enabled:
		return
	look.apply(self, head, relative)


func receive_spell_impact(impact: SpellImpact) -> void:
	if impact == null:
		return
	health.take_damage(impact.damage)
	velocity += impact.impulse
	if impact.damage > 0.0:
		WizardHud.toast(self, "The blast scorches you for %d" % roundi(impact.damage))


func _on_hurl_requested() -> void:
	var element := element_hand.take_for_hurl()
	if element == null:
		casting.refuse_empty_hurl()
		return
	if not casting.fire_hurl(element):
		element_hand.restore_from_failed_hurl(element)


func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_backward")
	locomotion.physics_step(self, input_direction, delta)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_mouse_look((event as InputEventMouseMotion).screen_relative)
		return

	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()


func _notification(what: int) -> void:
	if not _control_enabled:
		return
	match what:
		NOTIFICATION_WM_MOUSE_ENTER, \
		NOTIFICATION_WM_WINDOW_FOCUS_IN, \
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				_capture_mouse()
		_:
			pass


func _capture_mouse() -> void:
	# Offscreen capture and preview SubViewports have no operating-system window
	# to own captured input. A newly created Wayland window may also need one
	# frame before the compositor grants focus.
	var window := get_viewport() as Window
	if window == null or not window.has_focus():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
