class_name JournalMenu
extends Node

## The wizard's journal as the pause menu (game-bible.md kernel: the journal
## is the infinite book, and it is also the main menu). Escape summons the
## book into the held reading pose using the normal book rendering; bookmarks
## on the page edge mark the sections, Tab flips between them, and the menu
## page acts on number keys. The world keeps breathing while the wizard reads
## - only the player stops.
##
## Sections today: Menu (resume / settings stub / quit) and Runes (the five
## verb glyphs with stroke playback). The journal's knowledge pages arrive
## with the knowledge system.

const DEFAULT_BOOK_VISUAL_PROFILE: BookVisualProfile = preload(
	"res://content/books/default_book_visual_profile.tres")
const BOOK_FRAME_WIDTH_MARGIN := 0.05

@export var book_scene: PackedScene
@export_node_path("AnimationPlayer") var summon_animation_path: NodePath = \
	^"SummonAnimation"
@export_node_path("Node3D") var belt_anchor_path: NodePath = \
	^"../../JournalBeltAnchor"
@export var summon_arm_animation: StringName = \
	&"journal/journal_unhook_open_left"
@export_range(0.5, 1.0, 0.01) var final_screen_coverage := 0.9
@export_range(0.5, 2.0, 0.01) var final_book_scale := 1.0
@export_range(0.25, 1.0, 0.01) var belt_book_scale := 0.48
@export_range(0.0, 0.5, 0.01) var belt_release_start := 0.08
@export_range(0.1, 0.65, 0.01) var hand_attach_progress := 0.24
@export_range(0.35, 0.85, 0.01) var hand_to_face_progress := 0.65
@export_range(0.35, 0.85, 0.01) var book_open_progress := 0.58

@export_range(0.0, 1.0, 0.001) var summon_progress := 0.0:
	set(value):
		summon_progress = clampf(value, 0.0, 1.0)
		_update_summon_pose()

var _player: WizardPlayer
var _camera: Camera3D
var _casting: CastingController
var _element_hand: ElementHandController
var _sight: SightController
var _book: Book
var _book_visual: BookVisual
var _summon_mount: Node3D
var _summon_animation: AnimationPlayer
var _left_hand_anchor: Node3D
var _belt_anchor: Node3D
var _open := false
var _transitioning := false
var _stowing := false
var _summon_book_opened := false
var _sections: Array[Dictionary] = []


func _ready() -> void:
	_player = owner as WizardPlayer
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as WizardPlayer
	assert(_player != null, "JournalMenu must live under a WizardPlayer.")
	_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_casting = get_parent().get_node_or_null("CastingController") as CastingController
	_element_hand = get_parent().get_node_or_null(
		"ElementHandController") as ElementHandController
	_sight = get_parent().get_node_or_null("SightController") as SightController
	_summon_animation = get_node_or_null(summon_animation_path) as AnimationPlayer
	_belt_anchor = get_node_or_null(belt_anchor_path) as Node3D
	_left_hand_anchor = _camera.get_node_or_null(
		"Viewmodel/WizardArms/arms/Skeleton3D/LeftHandAttachment/SpellAnchor") as Node3D
	if _left_hand_anchor == null:
		_left_hand_anchor = _camera.get_node_or_null("Viewmodel/LeftHandAnchor") as Node3D
	if _summon_animation != null:
		_summon_animation.animation_finished.connect(_on_summon_animation_finished)
	set_process_unhandled_input(true)
	set_process(false)
	_build_book.call_deferred()


func _process(_delta: float) -> void:
	if _transitioning:
		_sync_summon_to_arm()
		_update_summon_pose()


func is_open() -> bool:
	return _open


func is_transitioning() -> bool:
	return _transitioning


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseMotion:
		_update_mouse_cursor((event as InputEventMouseMotion).position)
		return
	if event is not InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed \
			and _handle_page_click(mouse_button.position):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed(&"ui_cancel") and _can_open():
			_open_menu()
			get_viewport().set_input_as_handled()
		return
	# Escape and page-turn controls are the Book's own input; the journal adds
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
		_casting.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_book.visible = true
	_book.jump_to_spread(0)
	if not _book.is_reading():
		_book.cast_from(null, Transform3D.IDENTITY)
	_start_summon()
	_refresh_bookmarks()


## The Book closes itself (Escape inside its own input, or _resume below);
## everything player-side is restored here.
func _on_reading_finished(_closed_book: Book) -> void:
	if not _open:
		return
	_open = false
	_stowing = true
	_transitioning = true
	set_process(true)
	if _sight != null:
		_sight.set_process(true)
	if _summon_animation != null and _summon_animation.has_animation(&"summon"):
		_summon_animation.play_backwards(&"summon")
		_summon_animation.seek(
			_summon_animation.current_animation_length, true)
		if _element_hand != null:
			_element_hand.play_journal_stow_animation(summon_arm_animation)
	else:
		_finish_stow()


func _finish_stow() -> void:
	_stowing = false
	_transitioning = false
	summon_progress = 0.0
	set_process(false)
	if _book_visual != null:
		_book_visual.show_held_closed()
	_summon_book_opened = false
	if _element_hand != null:
		_element_hand.restore_animation()
	if _casting != null:
		_casting.set_process(true)
		_casting.set_process_input(true)
		_casting.set_process_unhandled_input(true)
	_player.set_control_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _resume() -> void:
	if _book != null and _book.is_reading():
		_book.cast_from(null, Transform3D.IDENTITY)  # toggles reading closed


func _next_section() -> void:
	if _sections.is_empty() or _book == null:
		return
	var next := (_section_for(_book.current_page) + 1) % _sections.size()
	_open_section(next)


func _open_section(section_index: int) -> void:
	if _book == null or section_index < 0 or section_index >= _sections.size():
		return
	var target := int(_sections[section_index]["spread"])
	_refresh_bookmarks_for_spread(target)
	_book.turn_to_spread(target)


func _handle_page_click(screen_position: Vector2) -> bool:
	if _book == null or _camera == null or summon_progress < 1.0:
		return false
	var page_uv := _book.page_uv_from_screen(_camera, screen_position)
	if page_uv.x < 0.0:
		return false
	if _book.is_page_turning():
		return true
	var bookmark := _book.bookmark_at_page_uv(page_uv)
	if bookmark >= 0:
		_open_section(bookmark)
		return true
	var target := _book.current_page + (-1 if page_uv.x < 0.5 else 1)
	_book.turn_to_spread(target)
	return true


func _update_mouse_cursor(screen_position: Vector2) -> void:
	var over_page := _book != null and _camera != null \
		and _book.page_uv_from_screen(_camera, screen_position).x >= 0.0
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if over_page else Input.CURSOR_ARROW)


func _section_for(spread: int) -> int:
	var current := 0
	for i in _sections.size():
		if spread >= int(_sections[i]["spread"]):
			current = i
	return current


func _refresh_bookmarks() -> void:
	if _book == null:
		return
	_refresh_bookmarks_for_spread(_book.current_page)


func _refresh_bookmarks_for_spread(spread: int) -> void:
	if _book == null:
		return
	var names: Array[String] = []
	for section in _sections:
		names.append(section["name"])
	_book.set_bookmarks(names, _section_for(spread))


func _build_book() -> void:
	if book_scene == null or _camera == null:
		return
	_summon_mount = Node3D.new()
	_summon_mount.name = "JournalBookMount"
	_player.add_child(_summon_mount)
	_book = book_scene.instantiate() as Book
	if _book == null:
		_summon_mount.queue_free()
		_summon_mount = null
		return
	_book.book_data = _build_journal_data()
	_summon_mount.add_child(_book)
	_book_visual = _book.get_node_or_null("Visual") as BookVisual
	var pose: Dictionary = _book.get_held_pose()
	_book.position = pose["position"] as Vector3
	# Mirror the page's vertical axis without reversing left/right. The outer
	# summon mount remains right-handed so it can interpolate cleanly from the
	# animated hand into the camera-space reading pose.
	_book.basis = Basis.from_scale(Vector3(1.0, -1.0, 1.0)) \
		* Basis.from_euler(pose["rotation"]).scaled(pose["scale"])
	_book.set_held(true)
	_book.visible = true
	_book.reading_finished.connect(_on_reading_finished)
	_book.page_turn_started.connect(func(_from_spread: int, to_spread: int) -> void:
		if _open:
			_refresh_bookmarks_for_spread(to_spread))
	_book.page_changed.connect(func(_spread: int) -> void:
		if _open:
			_refresh_bookmarks())
	summon_progress = 0.0
	if _book_visual != null:
		_book_visual.show_held_closed()
	_update_summon_pose()


func _start_summon() -> void:
	_stowing = false
	_transitioning = true
	_summon_book_opened = false
	if _book_visual != null:
		_book_visual.show_held_closed()
	summon_progress = 0.0
	set_process(true)
	if _element_hand != null:
		_element_hand.play_journal_summon_animation(summon_arm_animation)
	if _summon_animation != null and _summon_animation.has_animation(&"summon"):
		_summon_animation.play(&"summon")
		_summon_animation.seek(0.0, true)
	else:
		summon_progress = 1.0
		_finish_summon()


func _on_summon_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"summon":
		return
	if _stowing:
		_finish_stow()
		return
	_finish_summon()


func _finish_summon() -> void:
	summon_progress = 1.0
	_transitioning = false
	set_process(false)
	if _book_visual != null and not _summon_book_opened:
		_book_visual.open_held()
		_summon_book_opened = true


func _update_summon_pose() -> void:
	if _summon_mount == null or _camera == null or _player == null:
		return
	if not _open and not _transitioning:
		_summon_mount.transform = _belt_mount_transform()
		return
	_update_summon_book_state()
	var final_transform := _final_mount_transform()
	if summon_progress >= 1.0:
		_summon_mount.transform = final_transform
		return
	var belt_transform := _belt_mount_transform()
	if _left_hand_anchor == null:
		_summon_mount.transform = belt_transform.interpolate_with(
			final_transform, smoothstep(0.0, 1.0, summon_progress))
		return
	var hand_transform := _hand_mount_transform()
	if summon_progress <= belt_release_start:
		_summon_mount.transform = belt_transform
		return
	if summon_progress < hand_attach_progress:
		var release_progress := inverse_lerp(
			belt_release_start, hand_attach_progress, summon_progress)
		_summon_mount.transform = _unhook_mount_transform(
			belt_transform, hand_transform, release_progress)
		return
	if summon_progress <= hand_to_face_progress:
		_summon_mount.transform = hand_transform
		return
	var face_progress := inverse_lerp(
		hand_to_face_progress, 1.0, summon_progress)
	_summon_mount.transform = hand_transform.interpolate_with(
		final_transform, smoothstep(0.0, 1.0, face_progress))


func _sync_summon_to_arm() -> void:
	if _element_hand == null:
		return
	var arm_progress := _element_hand.journal_animation_progress(
		summon_arm_animation)
	if arm_progress < 0.0:
		return
	# The editable journal AnimationPlayer remains the authored curve. The arm
	# playhead is a fail-safe clock: if that clip visibly advances first, the
	# book catches up in the same frame instead of remaining below the camera.
	if _stowing:
		if arm_progress < summon_progress:
			summon_progress = arm_progress
	elif arm_progress > summon_progress:
		summon_progress = arm_progress
	if _stowing and arm_progress <= 0.0:
		_settle_summon_animation(false)
		_finish_stow()
	elif not _stowing and arm_progress >= 1.0:
		_settle_summon_animation(true)
		_finish_summon()


func _settle_summon_animation(at_end: bool) -> void:
	if _summon_animation == null \
			or not _summon_animation.has_animation(&"summon"):
		return
	if _summon_animation.current_animation != &"summon":
		_summon_animation.play(&"summon")
	_summon_animation.seek(
		_summon_animation.current_animation_length if at_end else 0.0,
		true)
	_summon_animation.pause()


func _update_summon_book_state() -> void:
	if _book_visual == null:
		return
	if not _stowing and not _summon_book_opened \
			and summon_progress >= book_open_progress:
		_book_visual.open_held()
		_summon_book_opened = true
	elif _stowing and _summon_book_opened \
			and summon_progress <= book_open_progress:
		_book_visual.show_held_closed()
		_summon_book_opened = false


func _belt_mount_transform() -> Transform3D:
	if _belt_anchor == null:
		return Transform3D(
			Basis.IDENTITY.scaled(Vector3.ONE * belt_book_scale),
			Vector3(-0.28, 0.18, -0.18))
	var local_transform := _player.global_transform.affine_inverse() \
		* _belt_anchor.global_transform
	local_transform.basis = local_transform.basis.orthonormalized().scaled(
		Vector3.ONE * belt_book_scale)
	return local_transform


func _hand_mount_transform() -> Transform3D:
	var local_transform := _player.global_transform.affine_inverse() \
		* _left_hand_anchor.global_transform
	local_transform.basis = local_transform.basis.orthonormalized().scaled(
		Vector3.ONE * belt_book_scale)
	return local_transform


func _unhook_mount_transform(
		belt_transform: Transform3D,
		hand_transform: Transform3D,
		progress: float) -> Transform3D:
	var eased_progress := smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0))
	var unhook_transform := belt_transform.interpolate_with(
		hand_transform, eased_progress)
	var arc_strength := sin(PI * eased_progress)
	unhook_transform.origin += Vector3(-0.01, 0.075, -0.04) * arc_strength
	unhook_transform.basis = unhook_transform.basis \
		* Basis.from_euler(Vector3(
			deg_to_rad(-6.0), deg_to_rad(-5.0), deg_to_rad(12.0)) * arc_strength)
	return unhook_transform


func _final_mount_transform() -> Transform3D:
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_fov_tangent := tan(deg_to_rad(_camera.fov) * 0.5)
	var horizontal_tangent := half_fov_tangent
	if _camera.keep_aspect == Camera3D.KEEP_HEIGHT:
		horizontal_tangent *= aspect
	var profile := _book.book_data.visual_profile if _book != null else null
	var spread_width := profile.spread_size.x if profile != null else 0.36
	var outer_width := (spread_width + BOOK_FRAME_WIDTH_MARGIN) \
		* final_book_scale * belt_book_scale
	var distance := outer_width / (
		2.0 * horizontal_tangent * final_screen_coverage)
	var camera_transform := Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * belt_book_scale),
		Vector3(0.0, 0.0, -distance))
	return _player.global_transform.affine_inverse() \
		* _camera.global_transform * camera_transform


func _journal_visual_profile() -> BookVisualProfile:
	var profile := DEFAULT_BOOK_VISUAL_PROFILE.duplicate(true) as BookVisualProfile
	var page_facing_basis := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0)).scaled(
		Vector3.ONE * final_book_scale)
	var final_pose := Transform3D(page_facing_basis, Vector3.ZERO)
	profile.reading_pose = final_pose
	profile.close_focus_pose = final_pose
	profile.breathing_lift = 0.0
	profile.breathing_speed = 0.0
	profile.sway_degrees = 0.0
	profile.unshaded = true
	profile.albedo_tint = Color("#a49d92")
	return profile


## The journal's spreads, built in code: the menu spread, then one spread per
## rune pair with glyph stroke playback.
func _build_journal_data() -> BookData:
	var data := BookData.new()
	data.id = "wizard_journal"
	data.title = "The Wizard's Journal"
	data.visual_profile = _journal_visual_profile()

	var menu_left := BookPageData.new()
	menu_left.title = "The Wizard's Journal"
	menu_left.body = "\n".join([
		"[1]  Resume",
		"[2]  Settings",
		"[3]  Quit",
		"",
		"[Esc] closes the journal.",
		"[Tab] flips to the next bookmark.",
		"[A] and [D] turn pages.",
	])
	var menu_right := BookPageData.new()
	menu_right.title = "Bookmarks"
	menu_right.body = "\n".join([
		"Menu - this page.",
		"Runes - the five verbs and their glyphs.",
		"",
		"More pages will ink themselves in",
		"as the journal learns.",
	])
	var menu_spread := BookSpreadData.new()
	menu_spread.left_page = menu_left
	menu_spread.right_page = menu_right
	data.spreads.append(menu_spread)

	_sections = [
		{"name": "Menu", "spread": 0},
		{"name": "Runes", "spread": 1},
	]

	for i in range(0, RuneGlyphs.VERBS.size(), 2):
		var spread := BookSpreadData.new()
		spread.left_page = _rune_page(RuneGlyphs.VERBS[i])
		if i + 1 < RuneGlyphs.VERBS.size():
			spread.right_page = _rune_page(RuneGlyphs.VERBS[i + 1])
		data.spreads.append(spread)
	return data


func _rune_page(id: StringName) -> BookPageData:
	var page := BookPageData.new()
	page.title = "%s - %s" % [RuneGlyphs.display_name(id), RuneGlyphs.glyph_name(id)]
	page.body = "%s\n\n%s" % [RuneGlyphs.meaning(id), RuneGlyphs.drawing_hint(id)]
	page.rune_template = RuneGlyphs.template(id)
	page.show_rune_playback = true
	return page
