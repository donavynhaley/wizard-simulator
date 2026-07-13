extends Node3D
class_name OpenBookPlacement

signal book_placed(book: Book)
signal book_taken(book: Book)

@export var place_prompt := "Place book reference"
@export var take_prompt := "Take book reference"
@export var held_item_prompt := "Empty your hands first"
@export_node_path("Node3D") var placement_anchor_path: NodePath = ^"StaticBody3D/CollisionShape3D"

var placed_book: Book


func focus_prompt(player: WizardPlayer, _collider: Object) -> String:
	if player == null or player.hands == null:
		return ""
	if player.hands.held_item is Book and placed_book == null:
		return place_prompt
	if player.hands.held_item == null and placed_book != null:
		return take_prompt
	if player.hands.held_item != null and placed_book != null:
		return held_item_prompt
	return ""


func interact(player: WizardPlayer, _collider: Object) -> void:
	if player == null or player.hands == null:
		return
	if player.hands.held_item is Book and placed_book == null:
		place_book(player.hands.held_item as Book, player)
	elif player.hands.held_item == null and placed_book != null:
		take_book(player)


func place_book(book: Book, player: WizardPlayer = null) -> void:
	if book == null or placed_book != null:
		return
	if player != null and player.hands != null:
		player.hands.release_item(book)
	placed_book = book
	book.reparent(self)
	_apply_anchor_transform(book)
	book.set_stationed(true)
	book.open_for_reference()
	book_placed.emit(book)


func take_book(player: WizardPlayer) -> void:
	if placed_book == null or player == null or player.hands == null:
		return
	var book := placed_book
	placed_book = null
	book.set_stationed(false)
	player.hands.pick_up(book)
	book_taken.emit(book)


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
