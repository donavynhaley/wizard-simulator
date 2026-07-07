extends SceneTree

# Headless test of the interaction + dialogue system. The player spawns looking at
# the entry door, so it should be the focused hotspot; we then run a full dialogue.
#   godot --headless --path . -s tools/interact_test.gd

var _fail := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := (load("res://legacy/scenes/levels/wizard_tower.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	await physics_frame
	await physics_frame

	var focused: Dictionary = scene.get("_focused")
	_check(not focused.is_empty(), "a hotspot is focused on spawn")
	_check(focused.get("name", "") == "EntryDoor_Interact" or focused.get("name", "") == "EntryCarpet_Interact", "an entry hotspot is focused (got '%s')" % focused.get("name", "none"))

	scene.call("_start_dialogue", focused)
	_check(scene.get("_dialogue_active") == true, "dialogue starts")
	var panel = scene.get("_dlg_panel")
	_check(panel != null and panel.visible, "dialogue panel visible")
	var txt = scene.get("_dlg_text")
	_check(txt != null and txt.text.length() > 0, "first line has text: \"%s\"" % (txt.text if txt else ""))

	scene.call("_advance_dialogue")
	_check(scene.get("_dialogue_active") == true and scene.get("_dialogue_index") == 1, "advances to second line")
	for i in 6:
		scene.call("_advance_dialogue")
	_check(scene.get("_dialogue_active") == false, "dialogue closes after the last line")
	_check(panel.visible == false, "panel hidden after dialogue")

	# Count registered hotspots across all floors.
	var count: int = scene.get("_interactables").size()
	_check(count >= 11, "all hotspots registered (%d)" % count)

	if _fail == 0:
		print("INTERACT TEST OK")
	else:
		print("INTERACT TEST FAILURES: ", _fail)
	quit(_fail)


func _check(cond: bool, label: String) -> void:
	print(("[PASS] " if cond else "[FAIL] ") + label)
	if not cond:
		_fail += 1
