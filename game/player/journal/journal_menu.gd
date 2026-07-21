class_name JournalMenu
extends Node

## The wizard's journal as the pause menu (game-bible.md kernel: the journal
## is the infinite book, and it is also the main menu). Escape summons the
## book into the held reading pose using the normal book rendering; bookmarks
## on the page edge mark the sections, Tab flips between them, and the menu
## page acts on number keys. The world keeps breathing while the wizard reads
## - only the player stops.
##
## Sections today: Menu (resume / settings stub / quit) and Runes (the six
## verb glyphs with stroke playback). The journal's knowledge pages arrive
## with the knowledge system.

@export var book_scene: PackedScene
## Where the book root mounts under the camera. The visual profile's reading
## pose is authored relative to this root (the old custody anchor is gone), so
## this stands in for the holder: roughly a held book's arm distance.
@export var held_offset := Vector3(-0.35, -0.13, -0.235)
## Soft warm fill so the pages read in dark rooms.
@export var reading_light_energy := 0.6

var _player: WizardPlayer
var _camera: Camera3D
var _casting: CastingController
var _sight: SightController
var _book: Book
var _open := false
var _sections: Array[Dictionary] = []


func _ready() -> void:
	_player = owner as WizardPlayer
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as WizardPlayer
	assert(_player != null, "JournalMenu must live under a WizardPlayer.")
	_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_casting = get_parent().get_node_or_null("CastingController") as CastingController
	_sight = get_parent().get_node_or_null("SightController") as SightController
	_build_book.call_deferred()


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"ui_cancel") and _can_open():
			_open_menu()
			get_viewport().set_input_as_handled()
		return
	# Escape and page arrows are the Book's own input; the journal only adds
	# the menu actions and bookmark flipping.
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				_resume()
			KEY_2:
				WizardHud.toast(self, "Settings: this page is not yet written")
			KEY_3:
				get_tree().quit()
			KEY_TAB:
				_next_section()


func _can_open() -> bool:
	if _book == null or _player == null or not _player.control_enabled():
		return false
	# Never mid-sentence: sketching runs at scaled time and a held verb has
	# its own input meaning.
	if _casting != null and _casting.current_state != CastingController.CASTING_STATE.IDLE:
		return false
	return true


func _open_menu() -> void:
	_open = true
	_player.set_control_enabled(false)
	if _sight != null:
		_sight.deactivate()
		_sight.set_process(false)
	if _casting != null:
		_casting.set_process(false)
		_casting.set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_book.visible = true
	_book.jump_to_spread(0)
	if not _book.is_reading():
		_book.cast_from(null, Transform3D.IDENTITY)
	_refresh_bookmarks()


## The Book closes itself (Escape inside its own input, or _resume below);
## everything player-side is restored here.
func _on_reading_finished(_closed_book: Book) -> void:
	if not _open:
		return
	_open = false
	_book.visible = false
	if _sight != null:
		_sight.set_process(true)
	if _casting != null:
		_casting.set_process(true)
		_casting.set_process_input(true)
	_player.set_control_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _resume() -> void:
	if _book != null and _book.is_reading():
		_book.cast_from(null, Transform3D.IDENTITY)  # toggles reading closed


func _next_section() -> void:
	if _sections.is_empty() or _book == null:
		return
	var next := (_section_for(_book.current_page) + 1) % _sections.size()
	_book.jump_to_spread(_sections[next]["spread"])
	_refresh_bookmarks()


func _section_for(spread: int) -> int:
	var current := 0
	for i in _sections.size():
		if spread >= int(_sections[i]["spread"]):
			current = i
	return current


func _refresh_bookmarks() -> void:
	if _book == null:
		return
	var names: Array[String] = []
	for section in _sections:
		names.append(section["name"])
	_book.set_bookmarks(names, _section_for(_book.current_page))


func _build_book() -> void:
	if book_scene == null or _camera == null:
		return
	_book = book_scene.instantiate() as Book
	if _book == null:
		return
	_book.book_data = _build_journal_data()
	_camera.add_child(_book)
	var pose: Dictionary = _book.get_held_pose()
	_book.position = (pose["position"] as Vector3) + held_offset
	# Without the old custody anchor the pages come up inverted. A half-turn
	# about the measured PAGE NORMAL (mesh +Y at the reading tilt) rights the
	# text without exposing the backface; held_offset compensates the rotated
	# pose offset. The in-plane turn swaps which side each physical page mesh
	# ends up on, so _build_journal_data authors content right-page-first.
	_book.basis = Basis(Vector3(0.0, cos(1.24), sin(1.24)).normalized(), PI) \
		* Basis.from_euler(pose["rotation"]).scaled(pose["scale"])
	_book.set_held(true)
	_book.visible = false
	var reading_light := OmniLight3D.new()
	reading_light.light_color = Color(1.0, 0.9, 0.75)
	reading_light.light_energy = reading_light_energy
	reading_light.omni_range = 0.9
	reading_light.position = Vector3(-0.1, 0.15, 0.1)
	_book.add_child(reading_light)
	_book.reading_finished.connect(_on_reading_finished)
	_book.page_changed.connect(func(_spread: int) -> void:
		if _open:
			_refresh_bookmarks())


## The journal's spreads, built in code: the menu spread, then one spread per
## rune pair with glyph stroke playback.
func _build_journal_data() -> BookData:
	var data := BookData.new()
	data.id = "wizard_journal"
	data.title = "The Wizard's Journal"
	data.visual_profile = load("res://content/books/default_book_visual_profile.tres")

	var menu_left := BookPageData.new()
	menu_left.title = "The Wizard's Journal"
	menu_left.body = "\n".join([
		"[1]  Resume",
		"[2]  Settings",
		"[3]  Quit",
		"",
		"[Esc] closes the journal.",
		"[Tab] flips to the next bookmark.",
		"[Left] and [Right] turn pages.",
	])
	var menu_right := BookPageData.new()
	menu_right.title = "Bookmarks"
	menu_right.body = "\n".join([
		"Menu - this page.",
		"Runes - the six verbs and their glyphs.",
		"",
		"More pages will ink themselves in",
		"as the journal learns.",
	])
	# The mount's in-plane flip swaps which side each physical page shows on,
	# so reading order assigns visually-left content to right_page and vice
	# versa (here and in the rune spreads below).
	var menu_spread := BookSpreadData.new()
	menu_spread.right_page = menu_left
	menu_spread.left_page = menu_right
	data.spreads.append(menu_spread)

	_sections = [
		{"name": "Menu", "spread": 0},
		{"name": "Runes", "spread": 1},
	]

	for i in range(0, RuneGlyphs.VERBS.size(), 2):
		var spread := BookSpreadData.new()
		spread.right_page = _rune_page(RuneGlyphs.VERBS[i])
		if i + 1 < RuneGlyphs.VERBS.size():
			spread.left_page = _rune_page(RuneGlyphs.VERBS[i + 1])
		data.spreads.append(spread)
	return data


func _rune_page(id: StringName) -> BookPageData:
	var page := BookPageData.new()
	page.title = "%s - %s" % [RuneGlyphs.display_name(id), RuneGlyphs.glyph_name(id)]
	page.body = "%s\n\n%s" % [RuneGlyphs.meaning(id), RuneGlyphs.drawing_hint(id)]
	page.rune_template = RuneGlyphs.template(id)
	page.show_rune_playback = true
	return page
