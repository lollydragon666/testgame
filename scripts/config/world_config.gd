class_name WorldConfig
extends Resource

@export_group("World Bounds")
## Половина размера квадратного мира: координаты ограничены диапазоном ±world_limit.
@export var world_limit := 3600.0
## Внутренний отступ, запрещающий появление врагов вплотную к границе карты.
@export var safe_spawn_margin := 150.0

@export_group("World Props")
## Отступ кустов, бочек и деревьев от края мира.
@export var prop_edge_margin := 170.0
## Свободная область вокруг стартовой позиции героя.
@export var prop_player_clear_radius := 310.0
## Минимальная дистанция между двумя объектами окружения.
@export var prop_minimum_spacing := 82.0

@export_group("Spatial Index")
## Размер ячейки grid-сетки. Боевые запросы читают только пересекаемые ячейки.
@export var spatial_cell_size := 180.0
## Дополнительный свободный зазор между новым врагом и занятыми областями.
@export var enemy_spawn_clearance := 18.0
## Радиус поиска соседей для взаимного расталкивания врагов.
@export var enemy_separation_radius := 76.0
## Максимальная скорость корректирующего separation-смещения.
@export var enemy_separation_speed := 105.0

@export_group("Experience Magnet")
## Добавка к длине меча, определяющая радиус притяжения опыта.
@export var pickup_magnet_extra_range := 42.0
## Базовая скорость движения сферы опыта к герою.
@export var pickup_magnet_base_speed := 220.0
## Внутри этой дистанции магнит начинает дополнительно ускоряться.
@export var pickup_magnet_close_distance := 150.0
## Множитель дополнительного ускорения рядом с героем.
@export var pickup_magnet_close_acceleration := 2.0
## Скорость сглаживания изменения направления сферы опыта.
@export var pickup_magnet_smoothing := 9.0

@export_group("Waves")
## Продолжительность одной обычной волны в секундах.
@export var wave_duration := 18.0
## Жёсткий лимит одновременно живущих обычных врагов.
@export var max_active_enemies := 120
## Лимит отбиваемых вражеских стрел и заклинаний.
@export var max_enemy_projectiles := 180
## Лимит одновременно активных снарядов игрока.
@export var max_player_projectiles := 64
## Общий лимит сфер опыта и лечебных бутылок.
@export var max_pickups := 320
## Задержка до первого противника после начала забега.
@export var first_spawn_delay := 0.35
## Нижняя граница интервала появления врагов.
@export var minimum_spawn_delay := 0.42
## Базовый интервал, от которого вычитается ускорение каждой волны.
@export var base_spawn_delay := 1.35
## На сколько секунд сокращается интервал появления за номер волны.
@export var spawn_delay_reduction_per_wave := 0.11
## Прирост коэффициента здоровья и урона врагов за волну.
@export var difficulty_growth_per_wave := 0.13
