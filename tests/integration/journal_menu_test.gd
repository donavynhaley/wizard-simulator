extends SceneTree

## The journal pause menu (game-bible.md: the journal is the infinite book and
## the main menu). Escape opens the journal book into the reading pose and
## freezes the player; Tab flips bookmarks between sections; Escape inside the
## book closes it and restores control. The rune section carries all five verb
## glyphs with playback templates.

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(50.0, 1.0, 50.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.global_position = Vector3(0.0, -0.5, 0.0)

	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as WizardPlayer
	root.add_child(player)
	await process_frame
	await process_frame

	var journal := player.get_node_or_null("Components/JournalMenu") as JournalMenu
	_check(journal != null, "player carries a JournalMenu")
	if journal == null:
		_finish(player)
		return
	await process_frame  # deferred book build
	_check(journal._book != null, "the player carries a physical journal book")
	if journal._book == null:
		_finish(player)
		return
	_check(_action_has_key(&"move_left", KEY_A),
		"A is mapped to the journal's previous-page action")
	_check(_action_has_key(&"move_right", KEY_D),
		"D is mapped to the journal's next-page action")
	var belt_anchor := player.get_node("JournalBeltAnchor") as Node3D
	var belt_hook := belt_anchor.get_node("JournalBeltHook") as MeshInstance3D
	var closed_visual := journal._book.get_node(
		"Visual/VisualRoot/MotionRoot/ClosedVisual") as Node3D
	_check(journal._summon_mount.get_parent() == player,
		"journal mount lives on the player instead of appearing from the camera")
	_check(journal._book.visible and not journal._book.is_reading(),
		"journal remains physically visible while secured to the belt")
	_check(journal._summon_mount.global_position.distance_to(
		belt_anchor.global_position) < 0.01 and closed_visual.visible,
		"closed journal starts at the authored left-hip belt anchor")
	_check(belt_hook.visible and belt_hook.mesh is TorusMesh,
		"journal rests in a visible metal belt hook that stays on the wizard")
	_check(belt_hook.global_position.distance_to(closed_visual.global_position) < 0.06,
		"belt hook wraps the closed journal instead of floating away from it")
	var hook_player_position := player.to_local(belt_hook.global_position)
	_check(Vector2(
			hook_player_position.x,
			hook_player_position.z).length() < 0.43,
		"belt hook stays against the character instead of floating off the body")
	var belt_transform := journal._belt_mount_transform()
	var unhook_transform := journal._unhook_mount_transform(
		belt_transform,
		Transform3D(belt_transform.basis, belt_transform.origin + Vector3(0.0, 0.2, -0.3)),
		0.5)
	_check(unhook_transform.origin.y > belt_transform.origin.y + 0.15
		and unhook_transform.origin.z < belt_transform.origin.z - 0.15,
		"unhook beat follows an upward arc between the belt and live hand")

	var data: BookData = journal._book.book_data
	_check(data.get_spread_count() == 4, "journal has a menu spread and three rune spreads")
	var rune_pages := 0
	for i in range(1, data.get_spread_count()):
		var spread := data.get_spread(i)
		for page in [spread.left_page, spread.right_page]:
			if page != null and page.rune_template != null and page.show_rune_playback:
				rune_pages += 1
	_check(rune_pages == 5, "all five verb glyphs have playback pages")

	# Escape opens the journal and freezes the player.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	_check(journal.is_open(), "escape opens the journal")
	_check(journal._book.is_reading(), "the journal book enters the reading pose")
	_check(journal._book.visible, "the journal book is visible while open")
	_check(not player.control_enabled(), "the player freezes while reading the journal")
	_check(journal._book.current_page == 0, "the journal opens on the menu spread")
	_check(journal._summon_animation != null
		and journal._summon_animation.current_animation == &"summon",
		"escape plays the editable journal summon animation")
	_check(journal._left_hand_anchor != null,
		"journal summon resolves the animated left-hand attachment")
	_check(journal.summon_arm_animation
			== &"journal/journal_unhook_open_left",
		"journal uses its dedicated unhook-and-open arm animation")
	_check(journal._element_hand._left_arm_anim.current_animation
		== journal.summon_arm_animation,
		"journal plays its Inspector-selected left-arm summon clip")
	var journal_arm_animation: Animation = journal._element_hand._left_arm_anim.get_animation(
		journal.summon_arm_animation)
	_check(journal_arm_animation != null
			and journal_arm_animation.has_meta(&"purpose")
			and journal_arm_animation.get_meta(&"purpose")
				== "journal_belt_unhook_lift_and_open",
		"journal arm clip is authored specifically for the belt and book sequence")
	_check(journal_arm_animation.has_marker(&"reach_belt")
			and journal_arm_animation.has_marker(&"grip_book")
			and journal_arm_animation.has_marker(&"begin_open")
			and journal_arm_animation.has_marker(&"reading_support"),
		"dedicated arm clip authors reach, grip, opening, and support beats")
	_check(journal._summon_mount != null
		and journal._summon_mount.global_position.distance_to(
			belt_anchor.global_position) < 0.02,
		"journal begins secured at the belt while the left hand reaches")
	# Reproduce the reported split-clock failure: even if the journal's own
	# AnimationPlayer stalls, the visible arm clip must carry the book with it.
	journal._summon_animation.pause()
	for frame in 90:
		if journal.summon_progress >= journal.hand_attach_progress:
			break
		await process_frame
	_check(journal.summon_progress >= journal.hand_attach_progress,
		"real Escape input advances the physical journal from the arm clock")
	_check(journal._summon_mount.global_position.distance_to(
		journal._left_hand_anchor.global_position) < 0.02,
		"journal transfers from the belt to the live left-hand socket")
	await _wait_for_journal_transition(journal)
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var reading_pose := journal._book.get_node("Visual/ReadingPose") as Marker3D
	var viewport_center := Vector2(camera.get_viewport().get_visible_rect().size) * 0.5
	var final_pose: Transform3D = camera.global_transform.affine_inverse() \
		* journal._summon_mount.global_transform * journal._book.transform \
		* reading_pose.transform
	var book_visual := journal._book.get_node("Visual") as BookVisual
	_check(final_pose.basis.y.normalized().dot(Vector3.BACK) > 0.99,
		"journal final page plane faces directly toward the camera")
	_check(is_equal_approx(book_visual._book_open_amount, 1.0),
		"journal covers finish their authored spine-hinge opening")
	_check(journal._summon_mount.transform.basis.get_scale().is_equal_approx(
		journal._belt_mount_transform().basis.get_scale()),
		"belt-to-face animation preserves the journal's physical size")
	var profile := journal._book.book_data.visual_profile as BookVisualProfile
	_check(is_zero_approx(profile.breathing_lift)
		and is_zero_approx(profile.sway_degrees),
		"journal settles without breathing or sway in the final reading pose")
	_check(not book_visual.is_processing(),
		"settled journal disables its idle animation processing")
	_check(profile.albedo_tint.get_luminance() < 0.65,
		"unshaded journal uses a subdued dark-fantasy material tint")
	var journal_page := book_visual.get_node(
		"VisualRoot/MotionRoot/OpenVisual/PageSurface/LeftPage") as MeshInstance3D
	var journal_page_material := journal_page.material_override as BaseMaterial3D
	_check(journal_page_material.albedo_color.is_equal_approx(profile.albedo_tint),
		"journal tint is applied directly to the light-independent page material")
	var flame := (load("res://shared/vfx/magical_flame.tscn") as PackedScene) \
		.instantiate()
	var flame_material := flame.get_node(
		"FlameCore/ShaderFlameBody").material_override as ShaderMaterial
	_check(flame_material.render_priority < journal_page_material.render_priority,
		"focused journal renders after additive world flames")
	flame.free()
	var all_materials_unshaded := true
	var all_materials_draw_over_world := true
	var detailed_surface_count := 0
	var journal_surface_shader := load(
		"res://game/books/presentation/journal_surface.gdshader") as Shader
	for node in book_visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(surface)
			if material == null:
				material = mesh_instance.mesh.surface_get_material(surface)
			if material is ShaderMaterial:
				var shader_material := material as ShaderMaterial
				if shader_material.shader == journal_surface_shader:
					detailed_surface_count += 1
				else:
					all_materials_unshaded = false
					all_materials_draw_over_world = false
			elif material is BaseMaterial3D:
				var base_material := material as BaseMaterial3D
				if base_material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
					all_materials_unshaded = false
				if not base_material.no_depth_test:
					all_materials_draw_over_world = false
	_check(all_materials_unshaded,
		"journal pages, covers, and imported models ignore environment lighting")
	_check(all_materials_draw_over_world,
		"recessed journal gutter stays visible over nearby environment geometry")
	_check(detailed_surface_count >= 16,
		"journal model uses fixed-light leather, parchment, thread, and brass surfaces")
	var closed_cover_dark_enough := false
	for node in closed_visual.find_children("*", "MeshInstance3D", true, false):
		var closed_mesh := node as MeshInstance3D
		if closed_mesh.mesh == null:
			continue
		for surface in closed_mesh.mesh.get_surface_count():
			var closed_material := closed_mesh.get_surface_override_material(surface) \
				as ShaderMaterial
			if closed_material == null \
					or int(closed_material.get_shader_parameter("surface_kind")) != 0:
				continue
			var cover_color := closed_material.get_shader_parameter("base_color") as Color
			closed_cover_dark_enough = cover_color.get_luminance() < 0.2
			break
	_check(closed_cover_dark_enough,
		"belt-mounted closed journal uses dark worn leather instead of bright red")
	var rendered_left_page := journal._book.get_node(
		"PageRenderer/SpreadRoot/Pages/LeftPage") as PanelContainer
	_check(rendered_left_page.has_node("Patina"),
		"journal parchment includes fibers, foxing, and worn-edge patina")
	var outer_width := profile.spread_size.x + 0.05
	var left_edge := camera.unproject_position(camera.to_global(
		final_pose * Vector3(-outer_width * 0.5, 0.0, 0.0)))
	var right_edge := camera.unproject_position(camera.to_global(
		final_pose * Vector3(outer_width * 0.5, 0.0, 0.0)))
	var coverage := absf(right_edge.x - left_edge.x) / (viewport_center.x * 2.0)
	_check(is_equal_approx(coverage, 0.9),
		"journal final pose fills 90 percent of the viewport width")
	_check(absf((left_edge.x + right_edge.x) * 0.5 - viewport_center.x)
		< viewport_center.x * 0.01,
		"journal final pose is centered in the player's view")
	_check(data.get_spread(0).left_page.title == "The Wizard's Journal",
		"journal menu content remains on the physical left page")
	_check(data.get_spread(0).left_page.body.contains("[A] and [D] turn pages."),
		"journal menu teaches the physical A/D page controls")
	var bookmarks := journal._book.get_node("PageRenderer").get(
		"_bookmark_column") as VBoxContainer
	_check(bookmarks != null and is_equal_approx(bookmarks.anchor_left, 1.0),
		"journal bookmarks sit on the outer edge of the physical right page")

	# Tab flips to the Runes bookmark.
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	journal._unhandled_input(tab)
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 1, "tab flips to the runes bookmark")
	journal._unhandled_input(tab)
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 0, "tab wraps back to the menu bookmark")
	var next_page := InputEventAction.new()
	next_page.action = &"move_right"
	next_page.pressed = true
	journal._book._input(next_page)
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 1,
		"D turns the held journal forward")
	var previous_page := InputEventAction.new()
	previous_page.action = &"move_left"
	previous_page.pressed = true
	journal._book._input(previous_page)
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 0,
		"A turns the held journal backward")

	# The physical spread itself is the mouse target. Clicking either half turns
	# one spread, while the ribbon tabs jump directly between sections.
	var right_page_uv := Vector2(0.72, 0.55)
	var right_page_click := journal._book.page_uv_to_screen(camera, right_page_uv)
	var mapped_page_uv := journal._book.page_uv_from_screen(camera, right_page_click)
	_check(mapped_page_uv.distance_to(right_page_uv) < 0.01,
		"journal maps the visible 3D page accurately into mouse coordinates")
	journal._input(_left_click(right_page_click))
	await process_frame
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 1,
		"left clicking the right page turns forward")
	var left_page_click := journal._book.page_uv_to_screen(camera, Vector2(0.28, 0.55))
	journal._input(_left_click(left_page_click))
	await process_frame
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 0,
		"left clicking the left page turns backward")

	var page_renderer := journal._book.get_node("PageRenderer") as BookPageRenderer
	var runes_tab := bookmarks.get_child(1) as Control
	var runes_uv := runes_tab.get_global_rect().get_center() / Vector2(page_renderer.size)
	journal._input(_left_click(journal._book.page_uv_to_screen(camera, runes_uv)))
	await process_frame
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 1,
		"clicking the Runes bookmark opens the rune section")
	var menu_tab := bookmarks.get_child(0) as Control
	var menu_uv := menu_tab.get_global_rect().get_center() / Vector2(page_renderer.size)
	journal._input(_left_click(journal._book.page_uv_to_screen(camera, menu_uv)))
	await process_frame
	await _wait_for_page_turn(journal._book)
	_check(journal._book.current_page == 0,
		"clicking the Menu bookmark returns to the menu spread")

	# Escape reverses the handoff and restores the closed journal to the belt.
	journal._book._input(escape)
	await _wait_for_journal_transition(journal)
	_check(not journal.is_open(), "escape closes the journal")
	_check(journal._book.visible and closed_visual.visible,
		"the closed journal remains visible on the wizard")
	_check(journal._summon_mount.global_position.distance_to(
		belt_anchor.global_position) < 0.01,
		"the left hand returns the journal to its belt anchor")
	_check(player.control_enabled(),
		"closing the journal restores the player after the stow animation")

	# Resume via the menu action ([1]) after reopening.
	journal._unhandled_input(escape)
	await process_frame
	_check(journal.is_open(), "the journal reopens")
	var one := InputEventKey.new()
	one.keycode = KEY_1
	one.pressed = true
	journal._unhandled_input(one)
	await _wait_for_journal_transition(journal)
	_check(not journal.is_open(), "the resume entry closes the journal")
	_check(player.control_enabled(), "resume restores the player")

	_finish(player)


func _finish(player: Node) -> void:
	if player != null:
		player.queue_free()
	await process_frame
	await process_frame
	if _fail == 0:
		print("JOURNAL MENU TEST OK")
	quit(_fail)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		push_error("[FAIL] %s" % message)
		_fail = 1


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true
	return false


func _wait_for_page_turn(book: Book) -> void:
	for frame in 120:
		if not book.is_page_turning():
			return
		await process_frame


func _wait_for_journal_transition(journal: JournalMenu) -> void:
	for frame in 180:
		if not journal.is_transitioning():
			return
		await process_frame


func _left_click(position: Vector2) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = position
	click.pressed = true
	return click
