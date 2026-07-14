class_name WizardBodyRig
extends Node3D

## Coordinates the editor-authored first-person rig with the player's held item.
## The beard supplies the downward-facing body silhouette, so no world-body model
## is needed for this first-person-only character.

var _first_person_rig: FirstPersonWizardRig
var _held_book: Book


func configure(first_person_rig: FirstPersonWizardRig, hands: WizardHands) -> void:
	_first_person_rig = first_person_rig
	if hands == null:
		return
	hands.held_changed.connect(_on_held_changed)
	_on_held_changed(hands.held_item)


func set_active(active: bool) -> void:
	if _first_person_rig != null:
		_first_person_rig.set_active(active)


func get_first_person_rig() -> FirstPersonWizardRig:
	return _first_person_rig


func _on_held_changed(item: Node3D) -> void:
	_disconnect_held_book()
	if _first_person_rig != null:
		_first_person_rig.set_holding_item(item != null)
	if item is Book:
		_held_book = item as Book
		_held_book.reading_started.connect(_on_book_reading_started)
		_held_book.reading_finished.connect(_on_book_reading_finished)
		if _held_book.is_reading():
			_on_book_reading_started(_held_book)


func _disconnect_held_book() -> void:
	if _held_book != null and is_instance_valid(_held_book):
		if _held_book.reading_started.is_connected(_on_book_reading_started):
			_held_book.reading_started.disconnect(_on_book_reading_started)
		if _held_book.reading_finished.is_connected(_on_book_reading_finished):
			_held_book.reading_finished.disconnect(_on_book_reading_finished)
	if _first_person_rig != null:
		_first_person_rig.set_reading_book(null)
	_held_book = null


func _on_book_reading_started(book: Book) -> void:
	if _first_person_rig != null and book == _held_book:
		_first_person_rig.set_reading_book(book)


func _on_book_reading_finished(book: Book) -> void:
	if _first_person_rig != null and book == _held_book:
		_first_person_rig.set_reading_book(null)
