class_name RuneDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("form", "effect", "modifier") var category: String = "form"
@export var templates: Array[Resource] = []


func add_template(template: Resource) -> void:
	if template == null:
		return
	if not templates.has(template):
		templates.append(template)
