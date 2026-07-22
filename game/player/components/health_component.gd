class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal died

@export_range(1.0, 10000.0, 1.0) var maximum: float = 100.0

var current: float


func _ready() -> void:
	current = maximum


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	health_changed.emit(current, maximum)
	if current <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or current <= 0.0:
		return
	current = minf(current + amount, maximum)
	health_changed.emit(current, maximum)


func reset() -> void:
	current = maximum
	health_changed.emit(current, maximum)
