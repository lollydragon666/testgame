class_name DeflectableProjectile
extends Node2D

## Положение в логических координатах мира, не в экранной изометрии.
var world_position := Vector2.ZERO
## Радиус, который PlayerAttack учитывает при пересечении мечом.
var hit_radius := 12.0

## Общий контракт отбивания: наследникам достаточно переопределить метод при особом эффекте.
func destroy_by_sword() -> void:
	queue_free()
