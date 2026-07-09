class_name VisualLayers

## Render-layer helpers shared by anything that moves meshes between the world
## and first-person presentation (held items, the body rig).


static func apply_layer(node: Node, layer_mask: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer_mask
	for child in node.get_children():
		apply_layer(child, layer_mask)
