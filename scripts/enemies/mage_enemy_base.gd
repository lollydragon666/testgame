class_name MageEnemyBase
extends EnemyBase

var spell_kind: StringName = GameIds.SPELL_LIGHTNING
var magic_color := Color("397fe8")
var cast_cooldown := 1.4
## Полная пауза между двумя заклинаниями конкретного вида мага.
var cast_interval := 2.6
var spell_damage := 14.0
## Маг отступает ближе минимума и приближается дальше максимума.
var preferred_min_distance := 330.0
var preferred_max_distance := 500.0
## Предельная дистанция, с которой разрешено выпустить заклинание.
var cast_range := 680.0
## Случайный знак заставляет разных магов обходить героя с разных сторон.
var strafe_sign := 1.0
var cast_flash := 0.0

func _init() -> void:
	visual_radius = 24.0
	collision_radius = 24.0
	max_health = 68.0
	move_speed = 58.0
	contact_damage = 9.0
	experience_value = 32
	strafe_sign = -1.0 if randf() < 0.5 else 1.0

func tick_behavior(delta: float) -> void:
	cast_cooldown = maxf(0.0, cast_cooldown - delta)
	cast_flash = maxf(0.0, cast_flash - delta)
	var offset: Vector2 = player.world_position - world_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.001 else Vector2.RIGHT
	if distance < preferred_min_distance:
		world_position -= direction * move_speed * delta
	elif distance > preferred_max_distance:
		world_position += direction * move_speed * delta
	world_position += direction.orthogonal() * strafe_sign * move_speed * 0.34 * delta
	if distance <= cast_range and cast_cooldown <= 0.0:
		cast_cooldown = cast_interval
		cast_flash = 0.3
		spell_requested.emit(spell_kind, world_position, direction, spell_damage)
