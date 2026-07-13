class_name BookSpreadData
extends Resource

@export var left_page: BookPageData
@export var right_page: BookPageData


func get_left_page() -> BookPageData:
	if left_page == null:
		left_page = BookPageData.new()
	return left_page


func get_right_page() -> BookPageData:
	if right_page == null:
		right_page = BookPageData.new()
	return right_page
