class_name BookData
extends Resource

@export var id: String = ""
@export var title: String = "Untitled Book"
@export var display_name: String = ""
@export var spreads: Array[BookSpreadData] = []


func get_display_name() -> String:
	if not display_name.strip_edges().is_empty():
		return display_name
	return title


func get_spread_count() -> int:
	return spreads.size()


func get_spread(index: int) -> BookSpreadData:
	if spreads.is_empty():
		return null
	return spreads[clampi(index, 0, spreads.size() - 1)]


func has_rune_template() -> bool:
	for spread in spreads:
		if spread == null:
			continue
		var left := spread.left_page
		var right := spread.right_page
		if left != null and left.has_rune_template():
			return true
		if right != null and right.has_rune_template():
			return true
	return false
