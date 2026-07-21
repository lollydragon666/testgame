class_name LancerEnemy
extends EnemyBase

const THRUST_DURATION := 0.32
## Максимальная дистанция наконечника копья в момент попадания.
const ATTACK_RANGE := 158.0
## Момент урона внутри выпада; до него игрок ещё может увернуться.
const HIT_FRAME_REMAINING_RATIO := 0.45

var attack_cooldown := 1.0
var thrust_time := 0.0
## Один выпад может применить урон только один раз.
var hit_pending := false

func _init() -> void:
	enemy_kind = GameIds.ENEMY_LANCER
	hit_radius = 27.0
	max_health = 96.0
	move_speed = 70.0
	contact_damage = 18.0
	experience_value = 30

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if thrust_time > 0.0:
		thrust_time = maxf(0.0, thrust_time - delta)
		if hit_pending and thrust_time <= THRUST_DURATION * HIT_FRAME_REMAINING_RATIO:
			hit_pending = false
			if world_position.distance_to(player.world_position) <= ATTACK_RANGE:
				damage_player()
		if thrust_time <= 0.0:
			hit_pending = false
		return
	var distance := world_position.distance_to(player.world_position)
	if distance > 138.0:
		move_toward_player(delta)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 2.05
		thrust_time = THRUST_DURATION
		hit_pending = true

func _draw() -> void:
	var body := health_color(Color("806a45"))
	var diamond := PackedVector2Array([Vector2(0.0, -hit_radius), Vector2(hit_radius, 0.0), Vector2(0.0, hit_radius), Vector2(-hit_radius, 0.0)])
	draw_colored_polygon(diamond, body)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("574637"), 2.0)
	var direction := IsoMath.world_to_screen((player.world_position - world_position).normalized()).normalized()
	var extension := 95.0 if thrust_time > 0.0 else 65.0
	draw_line(direction * 8.0, direction * extension, Color("714725"), 7.0)
	draw_line(direction * (extension - 22.0), direction * extension, Color("d4c4a4"), 10.0)
	draw_health_bar(58.0)
