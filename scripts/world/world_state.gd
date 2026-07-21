class_name WorldState
extends Node

# Типизированные runtime-реестры заменяют полный поиск групп на каждом кадре боя.
var enemies: Array[EnemyBase] = []
var enemy_projectiles: Array[DeflectableProjectile] = []
var destructibles: Array[WorldProp] = []

func register_enemy(enemy: EnemyBase) -> void:
	if enemies.has(enemy):
		return
	enemies.append(enemy)
	enemy.tree_exiting.connect(unregister_enemy.bind(enemy), CONNECT_ONE_SHOT)

func unregister_enemy(enemy: EnemyBase) -> void:
	enemies.erase(enemy)

func register_enemy_projectile(projectile: DeflectableProjectile) -> void:
	if enemy_projectiles.has(projectile):
		return
	enemy_projectiles.append(projectile)
	projectile.tree_exiting.connect(
		unregister_enemy_projectile.bind(projectile),
		CONNECT_ONE_SHOT
	)

func unregister_enemy_projectile(projectile: DeflectableProjectile) -> void:
	enemy_projectiles.erase(projectile)

func register_destructible(prop: WorldProp) -> void:
	if not prop.destructible or destructibles.has(prop):
		return
	destructibles.append(prop)
	prop.tree_exiting.connect(unregister_destructible.bind(prop), CONNECT_ONE_SHOT)

func unregister_destructible(prop: WorldProp) -> void:
	destructibles.erase(prop)

func replace_destructibles(props: Array[WorldProp]) -> void:
	destructibles.clear()
	for prop in props:
		if is_instance_valid(prop):
			register_destructible(prop)

func clear_runtime() -> void:
	# Окружение живёт весь забег, поэтому здесь очищаются только временные боевые объекты.
	enemies.clear()
	enemy_projectiles.clear()

func enemy_count() -> int:
	return enemies.size()
