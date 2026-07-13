extends SceneTree

const REQUIRED_FILES: Array[String] = [
	"res://assets/third_party/README.md",
	"res://assets/third_party/kenney/LICENSE.txt",
	"res://assets/third_party/kenney/fantasy_town/pillar-wood.glb",
	"res://assets/third_party/kenney/fantasy_town/planks.glb",
	"res://assets/third_party/kenney/fantasy_town/overhang.glb",
	"res://assets/third_party/kenney/fantasy_town/chimney-base.glb",
	"res://assets/third_party/kenney/fantasy_town/fountain-square-detail.glb",
	"res://assets/third_party/kenney/fantasy_town/Textures/colormap.png",
	"res://assets/third_party/polypizza/Wizardus Maximus.glb",
	"res://assets/third_party/polypizza/Wizardus Maximus_56x56texture.png",
	"res://assets/third_party/seal/seal_animated_low_poly.glb",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("External asset verification started.")
	_verify_required_files()
	_verify_license_text()
	_finish()


func _verify_required_files() -> void:
	for file_path in REQUIRED_FILES:
		_expect(FileAccess.file_exists(file_path), "Required asset exists: " + file_path)


func _verify_license_text() -> void:
	var license_path := "res://assets/third_party/kenney/LICENSE.txt"
	var license_text := FileAccess.get_file_as_string(license_path)
	_expect(
		license_text.contains("Creative Commons Zero") or license_text.contains("CC0"),
		"Kenney runtime assets preserve their CC0 license.")


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
