class_name EnemyArrow
extends EnemyProjectile

func setup(player_target: PlayerHero, origin: Vector2, direction: Vector2, projectile_damage: float) -> void:
	super.setup(player_target, origin, direction, projectile_damage)
	velocity = direction.normalized() * 330.0
	lifetime = 5.0
