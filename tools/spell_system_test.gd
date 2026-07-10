extends SceneTree

var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_compiler_resolves_vertical_slice()
	await _test_font_mend_restores_drought_field()
	_finish()


func _test_compiler_resolves_vertical_slice() -> void:
	var scroll := _make_scroll(&"font", &"mend", &"gilded", 0.95)
	var compiler := SpellCompiler.new()
	var compiled = compiler.compile_scroll(scroll)
	_check(compiled != null, "compiler creates a compiled spell")
	_check(scroll.display_name == "Gilded Healing Spring Scroll", "compiler names the gilded healing spring scroll")
	_check(compiled.spell_id == &"healing_spring", "resolver applies the healing spring override")
	_check(compiled.tags.has(&"water"), "compiled spell has water tag")
	_check(compiled.tags.has(&"font"), "compiled spell has font tag")
	_check(compiled.tags.has(&"mend"), "compiled spell has mend tag")
	_check(compiled.tags.has(&"gilded"), "compiled spell has gilded tag")

	var ice_lance := _make_scroll(&"bolt", &"rend", &"standard", 0.8)
	compiled = compiler.compile_scroll(ice_lance)
	_check(compiled != null and compiled.spell_id == &"ice_lance", "resolver applies the ice lance override")


func _test_font_mend_restores_drought_field() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var drought_field := DroughtField.new()
	drought_field.name = "DroughtField"
	drought_field.required_restore_amount = 10.0
	world.add_child(drought_field)
	await process_frame
	await physics_frame

	var scroll := _make_scroll(&"font", &"mend", &"gilded", 1.0)
	var compiler := SpellCompiler.new()
	var compiled = compiler.compile_scroll(scroll)
	_check(compiled != null, "font mend scroll compiles before casting")

	var context := SpellCastContext.new()
	context.caster = world
	context.world = world
	context.origin = Vector3(0.0, 1.5, 2.5)
	context.aim_direction = Vector3(0.0, -0.25, -1.0).normalized()
	context.target_position = Vector3.ZERO
	context.quality = scroll.quality

	var cast_system := SpellCastSystem.new()
	var result := cast_system.cast_scroll(scroll, context)
	_check(bool(result.get("cast", false)), "cast system executes the healing spring")
	_check(scroll.charges == 0, "cast system consumes the scroll charge")

	await physics_frame
	var font := world.find_child("FontArea", true, false)
	_check(font != null, "font delivery spawns in the world")
	if font != null:
		font.call("_apply_tick")
	_check(drought_field.restored_amount > 0.0, "water mend font restores the drought field")
	_check(drought_field.completed, "drought field completes once enough restoration is applied")
	current_scene = null
	root.remove_child(world)
	world.free()
	await process_frame


func _make_scroll(form_id: StringName, effect_id: StringName, ink_id: StringName, quality: float) -> SpellScrollData:
	var scroll := SpellScrollData.new()
	scroll.element_id = &"water"
	scroll.form_rune_ids = [form_id]
	scroll.effect_rune_ids = [effect_id]
	scroll.ink_id = ink_id
	scroll.seal_id = &"cast_on_use"
	scroll.quality = quality
	scroll.charges = 1
	return scroll


func _finish() -> void:
	if _fail == 0:
		print("SPELL SYSTEM TEST OK")
	else:
		print("SPELL SYSTEM TEST FAILURES: ", _fail)
	quit(_fail)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("[PASS] ", msg)
	else:
		_fail += 1
		push_error("[FAIL] " + msg)
