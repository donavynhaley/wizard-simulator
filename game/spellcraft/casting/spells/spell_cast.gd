class_name SpellCast
extends Node3D

## Base for a rune's cast behaviour - the "form/verb" of a spell. The controller
## instantiates the rune's cast scene when a spell is committed (SPELL_HELD) and
## drives it generically, so a new spell type is just a new subclass + a binding:
##   begin()      - once, on commit (set up any targeting preview)
##   update_aim() - every held frame (move the reticle / track the look)
##   cast()       - on left click (lock the aim, hide the preview)
##   resolve()    - when the throw (spell_cast) clip finishes (spawn the result)
## Spawned results (projectiles, explosions) are parented to the world so they
## outlive this node, which is freed right after resolve().

var element: Element   ## the imbued element applied to spawned effects (null = neutral)

var _camera: Camera3D
var _muzzle: Node3D    ## where projectiles originate (the palm anchor)
var _world: Node       ## where spawned results are parented
var _caster: Node3D    ## the player (e.g. to exclude from targeting rays)


func begin(camera: Camera3D, muzzle: Node3D, world: Node, caster: Node3D = null) -> void:
	_camera = camera
	_muzzle = muzzle
	_world = world
	_caster = caster
	_on_begin()


func update_aim(delta: float) -> void:
	_on_aim(delta)


## Left click: lock in the aim and hide any preview. Result spawns on resolve().
func cast() -> void:
	_on_cast()


## Throw finished (launch moment): spawn the projectile / explosion.
func resolve() -> void:
	_on_resolve()


# --- Overridable hooks ---
func _on_begin() -> void: pass
func _on_aim(_delta: float) -> void: pass
func _on_cast() -> void: pass
func _on_resolve() -> void: pass


# --- Shared helpers ---
## Camera-forward direction (where the player is looking).
func _look_dir() -> Vector3:
	if _camera == null:
		return Vector3.FORWARD
	return -_camera.global_transform.basis.z


func _muzzle_position() -> Vector3:
	if _muzzle != null:
		return _muzzle.global_position
	if _camera != null:
		return _camera.global_position
	return global_position
