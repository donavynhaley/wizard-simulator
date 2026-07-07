extends SceneTree

const REQUIRED_PACKS: Array[String] = [
	"res://assets/external/kenney/modular-dungeon-kit",
	"res://assets/external/kenney/fantasy-town-kit",
	"res://assets/external/kenney/retro-fantasy-kit",
	"res://assets/external/kenney/graveyard-kit",
	"res://assets/external/kenney/retro-textures-fantasy",
]

const REQUIRED_FILES: Array[String] = [
	"res://assets/external/kenney/ASSET_MANIFEST.md",
	"res://assets/external/kenney/modular-dungeon-kit/License.txt",
	"res://assets/external/kenney/fantasy-town-kit/License.txt",
	"res://assets/external/kenney/retro-fantasy-kit/License.txt",
	"res://assets/external/kenney/graveyard-kit/License.txt",
	"res://assets/external/kenney/retro-textures-fantasy/License.txt",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/room-large.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/template-wall.glb",
	"res://assets/external/kenney/modular-dungeon-kit/Models/GLB format/stairs.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/stairs-stone.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/wall-window-glass.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/windmill.glb",
	"res://assets/external/kenney/fantasy-town-kit/Models/GLB format/road.glb",
	"res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/tower-base.glb",
	"res://assets/external/kenney/retro-fantasy-kit/Models/GLB format/wall-fortified.glb",
	"res://assets/external/kenney/graveyard-kit/Models/GLB format/candle.glb",
	"res://assets/external/kenney/graveyard-kit/Models/GLB format/fire-basket.glb",
	"res://assets/external/kenney/retro-textures-fantasy/PNG/wall_stone.png",
	"res://assets/external/kenney/retro-textures-fantasy/PNG/floor_stone.png",
	"res://assets/external/kenney/retro-textures-fantasy/PNG/window_tall_rounded_lit.png",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("External asset verification started.")
	_verify_pack_folders()
	_verify_required_files()
	_verify_license_text()
	_verify_inventory()
	_finish()


func _verify_pack_folders() -> void:
	for pack_path in REQUIRED_PACKS:
		_expect(DirAccess.dir_exists_absolute(pack_path), "Pack folder exists: " + pack_path)


func _verify_required_files() -> void:
	for file_path in REQUIRED_FILES:
		_expect(FileAccess.file_exists(file_path), "Required asset exists: " + file_path)


func _verify_license_text() -> void:
	for pack_path in REQUIRED_PACKS:
		var license_path := pack_path + "/License.txt"
		var text := FileAccess.get_file_as_string(license_path)
		_expect(text.contains("Creative Commons Zero") or text.contains("CC0"), "License is CC0: " + license_path)


func _verify_inventory() -> void:
	var counts := _count_extensions("res://assets/external/kenney")
	_expect(counts.get("glb", 0) >= 400, "At least 400 GLB models are available.")
	_expect(counts.get("png", 0) >= 500, "At least 500 PNG textures/previews are available.")
	_expect(counts.get("fbx", 0) >= 400, "At least 400 FBX models are available.")
	_expect(counts.get("obj", 0) >= 400, "At least 400 OBJ models are available.")


func _count_extensions(root_path: String) -> Dictionary:
	var counts: Dictionary = {}
	_count_extensions_recursive(root_path, counts)
	return counts


func _count_extensions_recursive(root_path: String, counts: Dictionary) -> void:
	var directory := DirAccess.open(root_path)
	if not directory:
		_failures.append("Could not open directory: " + root_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var entry_path := root_path.path_join(entry)
		if directory.current_is_dir():
			_count_extensions_recursive(entry_path, counts)
		else:
			var extension := entry.get_extension().to_lower()
			counts[extension] = counts.get(extension, 0) + 1
		entry = directory.get_next()
	directory.list_dir_end()


func _finish() -> void:
	if _failures.is_empty():
		print("External asset verification passed.")
		quit(0)
		return

	push_error("External asset verification failed with %d issue(s)." % _failures.size())
	for failure in _failures:
		push_error("- " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_failures.append(message)
		print("[FAIL] " + message)
