class_name SpellHitContext
extends RefCounted

var caster: Node
var spell: CompiledSpellData
var target: Node
var hit_position := Vector3.ZERO

var power: float = 1.0
var element_id: StringName = &""
var tags: Array[StringName] = []
