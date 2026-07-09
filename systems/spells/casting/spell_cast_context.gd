class_name SpellCastContext
extends RefCounted

var caster: Node
var world: Node

var origin := Vector3.ZERO
var aim_direction := Vector3.FORWARD
var target_position := Vector3.ZERO

var quality: float = 1.0
var witnessed: bool = false
var witness_count: int = 0

var source_scroll: SpellScrollData
