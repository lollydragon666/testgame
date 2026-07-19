# Circle Raider — Godot port

Модульная версия изометрического рогалика для Godot 4.x. Визуальные элементы строятся кодом, поэтому проект не требует внешних изображений или платных ассетов.

## Запуск

1. Установите Godot 4.x.
2. В менеджере проектов выберите **Import**.
3. Укажите файл `project.godot`.
4. Откройте проект и нажмите `F6` или кнопку запуска.

## Управление

- `WASD` — движение.
- Мышь — направление взгляда и оружия.
- Левая кнопка мыши — удар мечом.

## Где менять механики

| Часть игры | Файл |
|---|---|
| Главная сборка и создание объектов | `scripts/main.gd` |
| Изометрическая проекция | `scripts/core/iso_math.gd` |
| Герой, здоровье и опыт | `scripts/player/player.gd` |
| Скорость, ускорение и плавность движения | `scripts/player/player_movement.gd` |
| Урон, длина меча и геометрия размаха | `scripts/player/player_attack.gd` |
| Общие параметры противников | `scripts/enemies/enemy_base.gd` |
| Зелёный мечник | `scripts/enemies/melee_enemy.gd` |
| Красный стрелок | `scripts/enemies/shooter_enemy.gd` |
| Ромб-копейщик | `scripts/enemies/lancer_enemy.gd` |
| Босс с топором | `scripts/enemies/boss_enemy.gd` |
| Снаряд стрелка | `scripts/combat/enemy_projectile.gd` |
| Размер карты и генерация объектов | `scripts/world/location.gd` |
| Кусты, бочки и деревья | `scripts/world/world_prop.gd` |
| Опыт и лечебные бутылки | `scripts/items/pickup.gd` |
| Волны и состав противников | `scripts/systems/wave_manager.gd` |
| Меню, HUD и экран улучшений | `scripts/ui/game_ui.gd` |

Основная сцена проекта находится в `scenes/main.tscn`. Браузерная версия сохранена в отдельной ветке `circle-raider`.

Герой, локация и каждый тип противника также имеют собственные `.tscn`-сцены в папке `scenes/`. Их можно открывать отдельно в редакторе Godot и менять параметры через Inspector.
