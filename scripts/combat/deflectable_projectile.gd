class_name DeflectableProjectile
extends Node2D

## Положение в логических координатах мира, не в экранной изометрии.
var world_position := Vector2.ZERO
## Размер рисунка снаряда; боевые системы его не читают.
var visual_radius := 12.0
## World-space радиус столкновения и отбивания мечом.
var collision_radius := 12.0
var world_state: WorldState

func set_world_state(state: WorldState) -> void:
	world_state = state

func update_spatial_index() -> void:
	if world_state != null:
		world_state.update_enemy_projectile(self)

## Общий контракт отбивания: наследникам достаточно переопределить метод при особом эффекте.
func destroy_by_sword() -> void:
	queue_free()
