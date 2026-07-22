class_name EnemyVisual
extends Node2D

func _draw() -> void:
	var enemy := get_parent() as EnemyBase
	if enemy == null or enemy.player == null:
		return
	match enemy.enemy_kind:
		GameIds.ENEMY_BRAWLER:
			_draw_brawler(enemy as BrawlerEnemy)
		GameIds.ENEMY_MELEE:
			_draw_melee(enemy as MeleeEnemy)
		GameIds.ENEMY_SHOOTER:
			_draw_shooter(enemy as ShooterEnemy)
		GameIds.ENEMY_LANCER:
			_draw_lancer(enemy as LancerEnemy)
		GameIds.ENEMY_LIGHTNING_MAGE, GameIds.ENEMY_FIRE_MAGE:
			_draw_mage(enemy as MageEnemyBase)
		GameIds.ENEMY_BOSS:
			_draw_boss(enemy as BossEnemy)
	if enemy.is_elite:
		_draw_elite_marker(enemy)

func _draw_elite_marker(enemy: EnemyBase) -> void:
	var gold := Color("d8b45c")
	draw_arc(Vector2.ZERO, enemy.visual_radius + 6.0, 0.0, TAU, 32, gold, 3.0)
	var marker_y := -enemy.visual_radius - 11.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, marker_y - 8.0),
		Vector2(7.0, marker_y),
		Vector2(0.0, marker_y + 8.0),
		Vector2(-7.0, marker_y),
	]), gold)

func _health_color(enemy: EnemyBase, base_color: Color) -> Color:
	return Color("d4c4a4") if enemy.hit_flash > 0.0 else base_color

func _draw_shadow(enemy: EnemyBase, offset_y: float = 9.0, x_scale: float = 1.25, y_scale: float = 0.45, alpha: float = 0.36) -> void:
	draw_set_transform(Vector2(0.0, offset_y), 0.0, Vector2(x_scale, y_scale))
	draw_circle(Vector2.ZERO, enemy.visual_radius, Color(0.01, 0.008, 0.008, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_health_bar(enemy: EnemyBase, width: float) -> void:
	if enemy.health >= enemy.max_health:
		return
	var ratio := clampf(enemy.health / enemy.max_health, 0.0, 1.0)
	draw_rect(Rect2(-width * 0.5, -enemy.visual_radius - 17.0, width, 4.0), Color(0.05, 0.03, 0.025, 0.8))
	draw_rect(Rect2(-width * 0.5, -enemy.visual_radius - 17.0, width * ratio, 4.0), Color("af3029"))

func _draw_brawler(enemy: BrawlerEnemy) -> void:
	_draw_shadow(enemy, 8.0, 1.24, 0.44)
	var body := _health_color(enemy, Color("666662"))
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), Color("a39d91"), false, 2.0)
	var direction := IsoMath.world_to_screen((enemy.player.world_position - enemy.world_position).normalized()).normalized()
	var side := direction.orthogonal()
	var punch_progress := 0.0
	if enemy.punch_time > 0.0:
		punch_progress = 1.0 - enemy.punch_time / BrawlerEnemy.PUNCH_DURATION
	var extension := sin(punch_progress * PI) * 22.0
	var left_hand := direction * 17.0 - side * 17.0
	var right_hand := direction * 17.0 + side * 17.0
	if enemy.punch_time > 0.0:
		if enemy.punch_side < 0.0:
			left_hand += direction * extension
		else:
			right_hand += direction * extension
	draw_line(-side * 11.0, left_hand, Color("4a4946"), 7.0)
	draw_line(side * 11.0, right_hand, Color("4a4946"), 7.0)
	draw_circle(left_hand, 8.0, Color("a39d91"))
	draw_circle(right_hand, 8.0, Color("a39d91"))
	_draw_health_bar(enemy, 50.0)

func _draw_melee(enemy: MeleeEnemy) -> void:
	_draw_shadow(enemy)
	var body := _health_color(enemy, Color("405d32"))
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), Color("574637"), false, 2.0)
	var aim_screen := IsoMath.world_to_screen((enemy.player.world_position - enemy.world_position).normalized()).normalized()
	var base_angle := aim_screen.angle()
	var sword_offset := sin(enemy.weapon_phase) * 0.18
	if enemy.swing_time > 0.0:
		sword_offset = enemy._swing_offset()
		_draw_melee_swing_trail(enemy, base_angle)
	var sword_direction := Vector2.from_angle(base_angle + sword_offset)
	draw_line(sword_direction * 16.0, sword_direction * 58.0, Color("d4c4a4"), 6.0)
	draw_line(sword_direction * 20.0 - sword_direction.orthogonal() * 10.0, sword_direction * 20.0 + sword_direction.orthogonal() * 10.0, Color("a8874d"), 5.0)
	_draw_health_bar(enemy, 55.0)

func _draw_melee_swing_trail(enemy: MeleeEnemy, base_angle: float) -> void:
	var trail := PackedVector2Array()
	for index in 20:
		var progress := float(index) / 19.0
		var angle := base_angle + lerpf(enemy._swing_start_offset(), enemy._swing_offset(), progress)
		trail.append(Vector2.from_angle(angle) * 58.0)
	draw_polyline(trail, Color(0.31, 0.49, 0.25, 0.68), 8.0)

func _draw_shooter(enemy: ShooterEnemy) -> void:
	_draw_shadow(enemy, 8.0)
	var body := _health_color(enemy, Color("8f211d"))
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), Color("d4c4a4"), false, 2.0)
	draw_circle(Vector2.ZERO, 7.0, Color("040303"))
	_draw_health_bar(enemy, 50.0)

func _draw_lancer(enemy: LancerEnemy) -> void:
	var body := _health_color(enemy, Color("806a45"))
	var diamond := PackedVector2Array([Vector2(0.0, -enemy.visual_radius), Vector2(enemy.visual_radius, 0.0), Vector2(0.0, enemy.visual_radius), Vector2(-enemy.visual_radius, 0.0)])
	draw_colored_polygon(diamond, body)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("574637"), 2.0)
	var direction := IsoMath.world_to_screen((enemy.player.world_position - enemy.world_position).normalized()).normalized()
	var extension := 95.0 if enemy.thrust_time > 0.0 else 65.0
	draw_line(direction * 8.0, direction * extension, Color("714725"), 7.0)
	draw_line(direction * (extension - 22.0), direction * extension, Color("d4c4a4"), 10.0)
	_draw_health_bar(enemy, 58.0)

func _draw_mage(enemy: MageEnemyBase) -> void:
	_draw_shadow(enemy, 9.0, 1.25, 0.45, 0.38)
	var body := _health_color(enemy, enemy.magic_color.darkened(0.35))
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), enemy.magic_color, false, 2.5)
	var direction := IsoMath.world_to_screen((enemy.player.world_position - enemy.world_position).normalized()).normalized()
	var side := direction.orthogonal()
	draw_line(-side * 19.0, direction * 24.0 - side * 19.0, Color("714725"), 6.0)
	var orb_position := direction * 29.0 - side * 19.0
	var orb_radius := 7.0 + (3.0 if enemy.cast_flash > 0.0 else 0.0)
	draw_circle(orb_position, orb_radius, enemy.magic_color)
	if enemy.spell_kind == GameIds.SPELL_LIGHTNING:
		draw_line(Vector2(-7.0, -5.0), Vector2(1.0, 1.0), enemy.magic_color, 3.0)
		draw_line(Vector2(1.0, 1.0), Vector2(-3.0, 8.0), enemy.magic_color, 3.0)
	else:
		draw_circle(Vector2.ZERO, 8.0, enemy.magic_color)
		draw_circle(Vector2(2.0, -2.0), 3.0, Color("ffb54c"))
	_draw_health_bar(enemy, 54.0)

func _draw_boss(enemy: BossEnemy) -> void:
	_draw_shadow(enemy, 17.0, 1.35, 0.46, 0.52)
	var body := _health_color(enemy, Color("8f4623"))
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), body)
	draw_rect(Rect2(Vector2.ONE * -enemy.visual_radius, Vector2.ONE * enemy.visual_radius * 2.0), Color("d0ad64"), false, 4.0)
	var direction := IsoMath.world_to_screen((enemy.player.world_position - enemy.world_position).normalized()).normalized()
	var axe_angle := -1.5 if enemy.windup > 0.28 else 0.45
	direction = direction.rotated(axe_angle)
	draw_line(direction * 24.0, direction * 110.0, Color("35271d"), 12.0)
	var head_center := direction * 105.0
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([head_center - side * 30.0, head_center + direction * 28.0, head_center + side * 30.0, head_center - direction * 8.0]), Color("574637"))
	_draw_health_bar(enemy, 125.0)
