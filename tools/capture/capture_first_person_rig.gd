extends SceneTree

const REST_OUT := "/tmp/first_person_rig_beard_rest.png"
const UP_OUT := "/tmp/first_person_rig_hat_look_up.png"
const DOWN_OUT := "/tmp/first_person_rig_beard_look_down.png"
const LIFT_OUT := "/tmp/first_person_rig_beard_lift.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var tower := (load("res://game/world/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(tower)
	current_scene = tower
	await process_frame
	await physics_frame
	var player := tower.get_node("Player") as WizardPlayer
	player.global_position = Vector3(0.0, 1.0, 5.5)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	for frame in 12:
		await process_frame
	var first_person_rig := (player.get_node("BodyRig") as WizardBodyRig).get_first_person_rig()
	var beard := first_person_rig.get_beard()
	var rest_error := root.get_viewport().get_texture().get_image().save_png(REST_OUT)
	player.head.rotation.x = deg_to_rad(65.0)
	for frame in 8:
		await process_frame
	var up_error := root.get_viewport().get_texture().get_image().save_png(UP_OUT)
	player.head.rotation.x = deg_to_rad(-40.0)
	for frame in 8:
		await process_frame
	var down_error := root.get_viewport().get_texture().get_image().save_png(DOWN_OUT)
	var beard_input := InputEventAction.new()
	beard_input.action = &"check_beard_inventory"
	beard_input.pressed = true
	first_person_rig._unhandled_input(beard_input)
	for frame in 90:
		await process_frame
	var lift_error := root.get_viewport().get_texture().get_image().save_png(LIFT_OUT)
	print("saved=", REST_OUT, ", ", UP_OUT, ", ", DOWN_OUT, ", and ", LIFT_OUT)
	var result := rest_error if rest_error != OK else up_error
	result = result if result != OK else down_error
	quit(result if result != OK else lift_error)
