class_name BookPageData
extends Resource

@export var title: String = ""
@export_multiline var body: String = ""
@export var rune_template: RuneTemplate
@export var show_rune_playback: bool = true


func has_rune_template() -> bool:
	return rune_template != null and rune_template.stroke_count() > 0
