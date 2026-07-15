extends Node3D
class_name OpenBookPlacement

## Physical marker that holds an open reference book on the crafting table.
## Placing/taking by hand is dormant until the held-item custody rework lands;
## place_book() stays callable from code and the editor.

signal book_placed(book: Book)
signal book_taken(book: Book)

@export_node_path("Node3D") var placement_anchor_path: NodePath = ^"StaticBody3D/CollisionShape3D"

var placed_book: Book


func place_book(book: Book) -> void:
	if book == null or placed_book != null:
		return
	placed_book = book
	book.reparent(self)
	_apply_anchor_transform(book)
	book.set_stationed(true)
	book.open_for_reference()
	book_placed.emit(book)


func _apply_anchor_transform(book: Book) -> void:
	var anchor := get_node_or_null(placement_anchor_path) as Node3D
	if anchor == null:
		book.position = Vector3.ZERO
		book.rotation = Vector3.ZERO
		book.scale = Vector3.ONE
		return
	var target_transform := anchor.global_transform
	target_transform.basis = target_transform.basis.orthonormalized()
	book.global_transform = target_transform
