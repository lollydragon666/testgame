extends SceneTree

const CONTENT: GameContent = preload("res://resources/game_content.tres")
const SAMPLE_COUNT := 10000
const REPORT_SEED := 20260723
const REPORT_PATH := "res://docs/random-item-generation-report.md"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = REPORT_SEED
	var factory := ItemFactory.new()
	factory.configure(CONTENT)
	var rarity_roller := ItemRarityRoller.new()
	var equipment: Array[ItemDefinition] = []
	for definition in CONTENT.all_items():
		if definition != null and definition.item_type != ItemEnums.ItemType.CONSUMABLE and definition.id != InventoryService.STARTER_WEAPON_ID:
			equipment.append(definition)

	var rarity_counts := [0, 0, 0, 0, 0]
	var affix_statistics: Dictionary[StringName, Dictionary] = {}
	var invalid_combinations := 0
	var incomplete_affix_sets := 0
	var maximum_damage := 0.0
	var maximum_attack_speed := 0.0
	var maximum_defense := 0.0
	var maximum_critical_chance := 0.0
	for index in SAMPLE_COUNT:
		var wave := index % 20 + 1
		var candidates: Array[ItemDefinition] = []
		for definition in equipment:
			if definition.minimum_wave <= wave:
				candidates.append(definition)
		var definition := candidates[rng.randi_range(0, candidates.size() - 1)]
		var rarity := rarity_roller.roll(wave, rng)
		var item := factory.create_random_item(definition.id, wave, rarity, rng)
		if item == null:
			invalid_combinations += 1
			continue
		rarity_counts[int(item.rarity)] += 1
		if item.affixes.size() < factory.affix_generator.affix_count_for_rarity(item.rarity):
			incomplete_affix_sets += 1
		if not factory.validate_item_instance(item):
			invalid_combinations += 1
		for roll in item.affixes:
			var statistic: Dictionary = affix_statistics.get(roll.affix_id, {
				"count": 0,
				"minimum": INF,
				"maximum": -INF,
				"sum": 0.0,
			})
			statistic["count"] = int(statistic["count"]) + 1
			statistic["minimum"] = minf(float(statistic["minimum"]), roll.value)
			statistic["maximum"] = maxf(float(statistic["maximum"]), roll.value)
			statistic["sum"] = float(statistic["sum"]) + roll.value
			affix_statistics[roll.affix_id] = statistic
		var stats := ItemInstanceStatCalculator.calculate(item, definition, CONTENT)
		maximum_damage = maxf(maximum_damage, stats.damage)
		maximum_attack_speed = maxf(maximum_attack_speed, stats.attack_speed)
		maximum_defense = maxf(maximum_defense, stats.defense)
		maximum_critical_chance = maxf(maximum_critical_chance, stats.critical_chance)

	var lines := PackedStringArray([
		"# Отчёт о генерации случайных предметов",
		"",
		"Отчёт создан воспроизводимым headless-скриптом `scripts/debug/random_item_generation_report.gd`.",
		"",
		"- Количество предметов: **%d**" % SAMPLE_COUNT,
		"- Seed: **%d**" % REPORT_SEED,
		"- Волны: **1–20**, равномерно по 500 предметов",
		"- Броски редкости: обычный противник, с действующим ограничением редкости по волне",
		"- Невалидные комбинации: **%d**" % invalid_combinations,
		"- Предметы с неполным набором аффиксов: **%d**" % incomplete_affix_sets,
		"",
		"## Распределение редкости",
		"",
		"| Редкость | Количество | Доля | Аффиксов |",
		"|---|---:|---:|---:|",
	])
	for rarity_value in range(ItemEnums.ItemRarity.COMMON, ItemEnums.ItemRarity.LEGENDARY + 1):
		lines.append("| %s | %d | %.2f%% | %d |" % [
			ItemRarityPresentation.rarity_name(rarity_value as ItemEnums.ItemRarity),
			rarity_counts[rarity_value],
			float(rarity_counts[rarity_value]) / float(SAMPLE_COUNT) * 100.0,
			rarity_value,
		])
	lines.append_array(PackedStringArray([
		"",
		"Высокие броски на ранних волнах сворачиваются в текущий wave-cap, поэтому итоговое распределение ожидаемо отличается от базовых 60/25/10/4/1%. Шансы в ходе проверки не изменялись.",
		"",
		"## Частота и значения аффиксов",
		"",
		"| ID | Название | Количество | Доля среди предметов | Минимум | Максимум | Среднее |",
		"|---|---|---:|---:|---:|---:|---:|",
	]))
	var affix_ids: Array[StringName] = []
	for affix_id in affix_statistics:
		affix_ids.append(affix_id)
	affix_ids.sort_custom(func(first: StringName, second: StringName) -> bool: return String(first) < String(second))
	for affix_id in affix_ids:
		var statistic: Dictionary = affix_statistics[affix_id]
		var count := int(statistic["count"])
		var definition := CONTENT.item_affix(affix_id)
		lines.append("| `%s` | %s | %d | %.2f%% | %.3f | %.3f | %.3f |" % [
			affix_id,
			definition.display_name if definition != null else affix_id,
			count,
			float(count) / float(SAMPLE_COUNT) * 100.0,
			float(statistic["minimum"]),
			float(statistic["maximum"]),
			float(statistic["sum"]) / float(count),
		])
	lines.append_array(PackedStringArray([
		"",
		"## Определения аффиксов",
		"",
		"| ID | Название | Характеристика | Предметы | Базовый диапазон | Мин. уровень | Вес |",
		"|---|---|---|---|---:|---:|---:|",
	]))
	for definition in CONTENT.item_affixes.definitions:
		lines.append("| `%s` | %s | %s | %s | %.3f–%.3f | %d | %.2f |" % [
			definition.id,
			definition.display_name,
			_stat_name(definition.stat_type),
			_item_type_names(definition.allowed_item_types),
			definition.base_min,
			definition.base_max,
			definition.minimum_item_level,
			definition.weight,
		])
	lines.append_array(PackedStringArray([
		"",
		"Частоты зависят не только от веса: сначала применяются совместимость типа/слота, минимальный уровень, уникальность ID и `exclusive_group`.",
		"",
		"## Полученные максимумы одного предмета",
		"",
		"| Показатель | Максимум |",
		"|---|---:|",
		"| Итоговый урон оружия | %.2f |" % maximum_damage,
		"| Бонус скорости атаки | %.2f%% |" % (maximum_attack_speed * 100.0),
		"| Итоговая защита | %.2f |" % maximum_defense,
		"| Бонус критического шанса | %.2f%% |" % (maximum_critical_chance * 100.0),
		"",
		"Эти значения относятся к одному сгенерированному экземпляру без постоянных бонусов профиля, улучшений забега и зелий.",
		"",
		"## Архитектура",
		"",
		"- `ItemInstance` хранит UUID, базовое определение, уровень, редкость, seed и готовые значения аффиксов.",
		"- `ItemRarityRoller` содержит единственные таблицу вероятностей и ограничения по волнам.",
		"- `ItemAffixDefinition` и `ItemAffixCatalog` задают совместимость, диапазоны, веса и взаимоисключающие группы.",
		"- `ItemAffixGenerator` выбирает уникальные совместимые свойства без бесконечных циклов.",
		"- `ItemFactory` создаёт и валидирует случайные и фиксированные экземпляры.",
		"- `LootService` определяет предмет полностью в момент смерти врага.",
		"- `PlayerStatCalculator` пересчитывает экипировку из сохранённых значений, ничего не перебрасывая.",
		"",
		"```text",
		"Enemy death → Loot roll → Definition → Item level → Rarity → Affixes",
		"→ World drop → Inventory → Equipment → PlayerStats",
		"```",
		"",
		"## Проверка и отладка",
		"",
		"Debug-команда доступна только в debug-сборке:",
		"",
		"```text",
		"spawn_random_item iron_sabre 10 rare 12345",
		"spawn_random_item knight_armor 15 epic 555",
		"```",
		"",
		"Одинаковые определение, уровень, редкость и seed дают одинаковые аффиксы; UUID каждого экземпляра остаётся уникальным.",
		"",
		"Сохранение содержит только стабильные ID и числа. Старые фиксированные предметы мигрируют на уровень 1 без случайных свойств; повреждённый аффикс пропускается отдельно, а дублирующийся UUID заменяется без удаления предмета.",
	]))
	var report := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report == null:
		push_error("Could not write random item generation report")
		quit(1)
		return
	report.store_string("\n".join(lines) + "\n")
	report.close()
	print("RANDOM ITEM REPORT PASS: %s" % REPORT_PATH)
	quit()

func _stat_name(stat_type: ItemEnums.ItemStatType) -> String:
	return [
		"Плоский урон",
		"Процентный урон",
		"Защита",
		"Максимальное здоровье",
		"Скорость атаки",
		"Скорость движения",
		"Дальность атаки",
		"Ширина атаки",
		"Критический шанс",
		"Критический урон",
		"Шанс добычи",
	][clampi(int(stat_type), ItemEnums.ItemStatType.DAMAGE_FLAT, ItemEnums.ItemStatType.LOOT_CHANCE)]

func _item_type_names(item_types: Array[ItemEnums.ItemType]) -> String:
	var names := PackedStringArray()
	for item_type in item_types:
		names.append(ItemEnums.item_type_name(item_type))
	return ", ".join(names)
