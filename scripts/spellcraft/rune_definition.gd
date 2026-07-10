class_name RuneDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("form", "effect", "modifier") var category: String = "form"
@export var mastery_required: float = 100.0
@export var templates: Array[Resource] = []


func add_template(template: Resource) -> void:
	if template == null:
		return
	if not templates.has(template):
		templates.append(template)


func get_templates() -> Array[Resource]:
	var out: Array[Resource] = []
	for template in templates:
		if template != null:
			out.append(template)
	return out
