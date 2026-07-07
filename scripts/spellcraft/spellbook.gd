class_name SpellbookJournal
extends Node

## Autoload ("Spellbook"): the wizard's discovery journal. Every forge attempt
## is logged by combo key, so players build a real record of what works, what
## screams, and what turns them into a frog. Persists to user://spellbook.json.
##
## Other scripts reach it with SpellbookJournal.find(get_tree()) rather than
## the autoload identifier, so headless -s test harnesses can compile too.

signal discovery_made(entry: Dictionary)
signal toast(text: String)

const SAVE_PATH := "user://spellbook.json"

## combo_key -> { name, outcome ("spell"|"backfire"), backfire, rare, quirks, times }
var entries: Dictionary = {}


static func find(tree: SceneTree) -> SpellbookJournal:
	return tree.root.get_node_or_null(^"Spellbook") as SpellbookJournal


func _ready() -> void:
	load_book()


func is_known(combo_key: String) -> bool:
	return entries.has(combo_key)


func discovered_count() -> int:
	return entries.size()


## Log a forge result. Returns true when this combo is a brand new discovery.
func record_forge(combo_key: String, result: Dictionary) -> bool:
	var is_new := not entries.has(combo_key)
	var entry: Dictionary = entries.get(combo_key, {"times": 0})
	entry["times"] = int(entry["times"]) + 1
	if result.get("ok", false):
		var def: SpellDefinition = result["definition"]
		entry["name"] = def.spell_name
		entry["outcome"] = "spell"
		entry["rare"] = def.rare_id
		entry["quirks"] = Array(def.quirks)
	else:
		entry["name"] = "Backfire"
		entry["outcome"] = "backfire"
		entry["backfire"] = result.get("backfire", "")
	entries[combo_key] = entry
	save_book()
	if is_new:
		discovery_made.emit(entry.duplicate())
		if entry["outcome"] == "spell":
			var label := "Rare discovery" if entry.get("rare", "") != "" else "New spell discovered"
			toast.emit("%s: %s" % [label, entry["name"]])
		else:
			toast.emit("Discovery logged: that combination backfires.")
	return is_new


func announce(text: String) -> void:
	toast.emit(text)


func save_book() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Spellbook: cannot write " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(entries, "\t"))


func load_book() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		entries = parsed
