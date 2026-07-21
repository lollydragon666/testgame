class_name BrawlerEnemy
extends EnemyBase

const PUNCH_DURATION := 0.42

var attack_cooldown := 0.65
var punch_time := 0.0
## Знак выбирает левую или правую руку для следующей анимации.
var punch_side := 1.0
## Урон откладывается до середины движения кулака.
var punch_pending := false

func _init() -> void:
	enemy_kind = GameIds.ENEMY_BRAWLER
	hit_radius = 23.0
	max_health = 64.0
	move_speed = 76.0
	contact_damage = 11.0
	experience_value = 17

func tick_behavior(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if punch_time > 0.0:
		punch_time = maxf(0.0, punch_time - delta)
		if punch_pending and punch_time <= PUNCH_DURATION * 0.48:
			punch_pending = false
			if world_position.distance_to(player.world_position) <= 72.0:
				damage_player()
		return
	var distance := world_position.distance_to(player.world_position)
	if distance > 58.0:
		move_toward_player(delta)
	elif attack_cooldown <= 0.0:
		attack_cooldown = 1.45
		punch_time = PUNCH_DURATION
		punch_pending = true
		punch_side *= -1.0

func _draw() -> void:
	draw_set_transform(Vector2(0.0, 8.0), 0.0, Vector2(1.24, 0.44))
	draw_circle(Vector2.ZERO, hit_radius, Color(0.01, 0.008, 0.008, 0.36))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := health_color(Color("666662"))
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -hit_radius, Vector2.ONE * hit_radius * 2.0), Color("a39d91"), false, 2.0)
	var direction := IsoMath.world_to_screen((player.world_position - world_position).normalized()).normalized()
	var side := direction.orthogonal()
	var punch_progress := 0.0
	if punch_time > 0.0:
		punch_progress = 1.0 - punch_time / PUNCH_DURATION
	var extension := sin(punch_progress * PI) * 22.0
	var left_hand := direction * 17.0 - side * 17.0
	var right_hand := direction * 17.0 + side * 17.0
	if punch_time > 0.0:
		if punch_side < 0.0:
			left_hand += direction * extension
		else:
			right_hand += direction * extension
	draw_line(-side * 11.0, left_hand, Color("4a4946"), 7.0)
	draw_line(side * 11.0, right_hand, Color("4a4946"), 7.0)
	draw_circle(left_hand, 8.0, Color("a39d91"))
	draw_circle(right_hand, 8.0, Color("a39d91"))
	draw_health_bar(50.0)
