class_name SightFade
extends Node
## Mundane-matter fade for Wizard Sight. While Sight is up, every mundane mesh in
## the current scene wears a shared "other world" pass as its material_overlay
## (driven by the global wizard_sight shader value), so the solid, bright magic
## reads against the faded world. Magic visuals (element sources, link strands,
## anchors) and the player's own body are left untouched. Tag anything else that
## should stay solid with the "sight_no_fade" group.
##
## An OVERLAY, not an override: the real material keeps rendering and writing
## depth underneath, so the crossing is a true crossfade (the shader's alpha rides
## wizard_sight - no snap into shadow, and the veil recedes on release), magic
## stays properly occluded by world geometry, and nothing has to be restored
## beyond the overlay slot itself.
##
## The LOOK is whichever shader FADE_SHADER points at: shadow_puppet.gdshader
## (flat backlit cutouts) or ghost_glass.gdshader (translucent glass). Swap the
## one line to change treatments.

const FADE_SHADER := preload("res://game/player/sight/shadow_puppet.gdshader")
const EXCLUDE_GROUPS: Array[StringName] = [
	&"element_source", &"magical_link", &"link_anchor", &"wizard_hud", &"sight_no_fade"]

## The current sight fade (0..1), readable by any script without the cost of a
## RenderingServer global-parameter fetch (signifier components read this).
static var sight_amount := 0.0

static var _instance: SightFade

## The player's root; its whole subtree (arms, camera rig) is left solid.
var player_node: Node

var _fade_mat: ShaderMaterial
var _applied := false
var _prior_overlays: Dictionary = {}


func _ready() -> void:
	_instance = self
	_fade_mat = ShaderMaterial.new()
	_fade_mat.shader = FADE_SHADER
	# The overlay is a transparent pass, and Godot sorts transparents by centre
	# distance - a huge wall's overlay would sort "closer" than a small flame and
	# paint black over it. Drawing the shadow world FIRST among transparents lets
	# every magical VFX (flames, streams, orbs, strands) render on top, with the
	# depth buffer still hiding whatever is genuinely behind geometry.
	_fade_mat.render_priority = -100


## Fed the sight fade (0..1) each frame by SightController: drives the effect
## globally and hangs the overlay on the way up, removes it once fully down.
func set_amount(amount: float) -> void:
	SightFade.sight_amount = amount
	RenderingServer.global_shader_parameter_set(&"wizard_sight", amount)
	if amount > 0.001 and not _applied:
		_apply()
	elif amount <= 0.001 and _applied:
		_restore()


func _apply() -> void:
	_applied = true
	_prior_overlays.clear()
	var meshes: Array[MeshInstance3D] = []
	_gather(get_tree().current_scene, meshes)
	for mesh in meshes:
		_prior_overlays[mesh] = mesh.material_overlay
		mesh.material_overlay = _fade_mat


func _restore() -> void:
	_applied = false
	for mesh: MeshInstance3D in _prior_overlays:
		if is_instance_valid(mesh):
			mesh.material_overlay = _prior_overlays[mesh]
	_prior_overlays.clear()


## Re-evaluates the fade on one subtree while Sight is up, for state-driven
## exemptions (a vessel joins sight_no_fade when fed and leaves it when drained):
## meshes newly excluded shed the shadow overlay mid-squint, newly mundane ones
## take it on. A no-op while Sight is down - the next _apply re-walks anyway.
static func refresh(root: Node) -> void:
	if _instance == null or not _instance._applied or root == null:
		return
	var faded: Array[MeshInstance3D] = []
	_instance._gather(root, faded)
	var everything: Array[MeshInstance3D] = []
	_collect_all(root, everything)
	for mesh in everything:
		if mesh in faded:
			if mesh.material_overlay != _instance._fade_mat:
				_instance._prior_overlays[mesh] = mesh.material_overlay
				mesh.material_overlay = _instance._fade_mat
		elif mesh.material_overlay == _instance._fade_mat:
			mesh.material_overlay = _instance._prior_overlays.get(mesh)
			_instance._prior_overlays.erase(mesh)


static func _collect_all(node: Node, out: Array[MeshInstance3D]) -> void:
	var mesh := node as MeshInstance3D
	if mesh != null:
		out.append(mesh)
	for child in node.get_children():
		_collect_all(child, out)


## Depth-first walk that skips the player and any magic-tagged subtree, collecting
## the plain MeshInstance3D nodes that make up the mundane world.
func _gather(node: Node, out: Array[MeshInstance3D]) -> void:
	if node == null or node == player_node:
		return
	for group in EXCLUDE_GROUPS:
		if node.is_in_group(group):
			return
	var mesh := node as MeshInstance3D
	if mesh != null:
		out.append(mesh)
	for child in node.get_children():
		_gather(child, out)
