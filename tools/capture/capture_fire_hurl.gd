extends SceneTree

## Captures the compact Fire Hurl projectile and its full impact bloom from the
## player's first-person view for visual regression inspection.
## Run with a graphical display:
##   godot --path . -s tools/capture/capture_fire_hurl.gd

const BOLT_OUT := "/tmp/fire_hurl_bolt.png"
const EXPLOSION_OUT := "/tmp/fire_hurl_explosion.png"
const CAPTURE_SIZE := Vector2i(1280, 720)


func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var lab_scene := load("res://game/spellcraft/spellcraft_lab.tscn") as PackedScene
	var world := lab_scene.instantiate() as Node3D
	viewport.add_child(world)
	var player := world.get_node_or_null(^"Player") as WizardPlayer
	var fire := load("res://game/spellcraft/elements/fire.tres") as Element
	if player == null or fire == null:
		quit(1)
		return
	await process_frame
	await physics_frame

	var camera := player.get_node(^"Head/Camera3D") as Camera3D
	var bolt := (load(
		"res://game/spellcraft/casting/spells/fire_bolt.tscn") as PackedScene).instantiate() as HurlProjectile
	bolt.element = fire
	bolt.caster = player
	world.add_child(bolt)
	bolt.global_position = camera.global_position + camera.global_basis * Vector3(0.0, 0.0, -3.2)
	bolt.look_at(bolt.global_position + camera.global_basis * Vector3.FORWARD, Vector3.UP)
	for frame in 10:
		await process_frame
	var bolt_error := viewport.get_texture().get_image().save_png(BOLT_OUT)
	bolt.queue_free()
	await process_frame

	var explosion := (load(
		"res://game/spellcraft/casting/effects/fire_explosion.tscn") as PackedScene).instantiate() as FireExplosion
	explosion.configure(fire, player)
	world.add_child(explosion)
	explosion.global_position = camera.global_position + camera.global_basis * Vector3(0.0, -0.2, -6.0)
	for frame in 7:
		await process_frame
	var explosion_error := viewport.get_texture().get_image().save_png(EXPLOSION_OUT)
	print("saved=", BOLT_OUT, " err=", bolt_error, " size=", CAPTURE_SIZE)
	print("saved=", EXPLOSION_OUT, " err=", explosion_error, " size=", CAPTURE_SIZE)
	quit(bolt_error if bolt_error != OK else explosion_error)
