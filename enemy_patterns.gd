class_name EnemyPatterns
extends NinePatchRect

const SIDE_LENGTH := 140.0

@export_group("Coin Drop")
@export var coin_drop_in: float = 10.0 ## how far the coin peeks down before pausing
@export var coin_drop_in_time: float = 0.5 ## duration of the peek-in
@export var coin_pause_time: float = 0.5 ## pause before falling
@export var coin_drop_distance: float = 200.0 ## how far it falls after the pause
@export var coin_drop_time: float = 0.5 ## duration of the fall

@export_group("Gryme Wall")
@export var gryme_gaps: int = 5 ## contiguous gap size in the wall
@export var gryme_good_chance: float = 0.0 ## chance a contiguous set becomes good
@export var gryme_good_max_size: int = 1 ## max size of the good contiguous set
@export var gryme_nudge: float = 10.0 ## how far inward the wall peeks before pausing
@export var gryme_nudge_time: float = 0.5 ## duration of the peek-in
@export var gryme_pause_time: float = 0.5 ## pause before sweeping across
@export var gryme_sweep_time: float = 0.5 ## duration of the sweep across the box

@export_group("Dust Bunny")
@export var bunny_good_chance: float = 0.0 ## chance the bunny itself is good
@export var bunny_speed_min: float = 40.0 ## min horizontal launch speed
@export var bunny_speed_max: float = 120.0 ## max horizontal launch speed
@export var bunny_launch_min: float = -120.0 ## min upward launch speed (more negative = higher)
@export var bunny_launch_max: float = -60.0 ## max upward launch speed
@export var bunny_gravity: float = 300.0 ## gravity pull
@export var bunny_shard_count: int = 8 ## number of dust shards in the landing burst
@export var bunny_shard_spread: float = 6.0 ## initial arc radius from landing point
@export var bunny_shard_travel: float = 80.0 ## how far each shard travels outward

@export_group("Ooze")
@export var ooze_good_chance: float = 0.0 ## chance it launches as good
@export var ooze_good_duration: float = 0.5 ## proportion of lifetime it stays good (0.0–1.0)
@export var ooze_initial_speed: float = 300.0 ## launch speed at spawn
@export var ooze_decay: float = 3.0 ## exponential decay rate (higher = slows faster)
@export var ooze_steer: float = 0.7 ## steering toward mouse (0 = none, 1 = strong)
@export var ooze_lifetime: float = 2.5 ## seconds before despawning

@export_group("Penny Bounce")
@export var penny_good_chance: float = 0.0 ## chance it becomes good after bouncing
@export var penny_speed_min: float = 60.0 ## min horizontal launch speed
@export var penny_speed_max: float = 100.0 ## max horizontal launch speed
@export var penny_launch_min: float = -140.0 ## min upward launch speed
@export var penny_launch_max: float = -50.0 ## max upward launch speed
@export var penny_gravity: float = 200.0 ## gravity for both arcs
@export var penny_bounce_time_min: float = 0.4 ## min seconds before mid-air bounce
@export var penny_bounce_time_max: float = 0.8 ## max seconds before mid-air bounce
@export var penny_bounce_strength: float = 60.0 ## higher = faster, more aggressive targeting

@export_group("Droplet Circle")
@export var droplet_good_chance: float = 0.0 ## chance one random droplet is good
@export var droplet_min_distance: float = 30.0 ## minimum distance from pointer when choosing center
@export var droplet_count: int = 12 ## number of droplets in the circle
@export var droplet_radius: float = 12.0 ## distance from center each droplet spawns at
@export var droplet_fill_gap: float = 0.1 ## seconds between each droplet appearing
@export var droplet_delay: float = 0.4 ## seconds after all placed before they launch
@export var droplet_travel: float = 80.0 ## how far each droplet travels outward
@export var droplet_travel_time: float = 0.6 ## duration of the outward travel

@export_group("Jetstream")
@export var jet_good_chance: float = 0.0 ## chance the jetstream is good
@export var jet_offset_out: float = 10.0 ## how far beyond the edge to spawn
@export var jet_arc_height: float = 40.0 ## peak height of the arc above midpoint
@export var jet_duration: float = 0.8 ## time to travel the full arc
@export var jet_overshoot: float = 40.0 ## extra distance past finish to clear edge

@export_group("Wave Minigame")
@export var wave_row_spacing: float = 10.0 ## vertical distance between stream lanes
@export var wave_stream_speed: float = 60.0 ## travel speed across the box
@export var wave_sine_amplitude: float = 8.0 ## sine-wave wobble amount
@export var wave_sine_frequency: float = 4.0 ## sine-wave oscillations per second
@export var wave_safe_radius: float = 20.0 ## radius of each safe-zone circle
@export var wave_wander_speed: float = 0.4 ## how fast circles wander
@export var wave_wander_factor: float = 0.35 ## fraction of box size circles can wander
@export var wave_spawn_interval: float = 0.15 ## time between each wave of streams
@export var wave_count: int = 25 ## how many waves of streams to spawn
@export var wave_overshoot: float = 20.0 ## extra distance past edge before despawn
var expected_time_for_minigame := 5.0

enum HitType {
    None,
    Bad,
    Good,
}

static func turns_to_vec(turns: float) -> Vector2:
    var rad: float = turns * TAU
    return Vector2(cos(rad), sin(rad))

static func turns_to_rad(turns: float) -> float:
    return turns * TAU

func get_random_point_in_side(side: Side, distance_from := 0.0, shrink := 0.0) -> Vector2:
    var rect := get_global_rect()
    match side:
        SIDE_LEFT:
            var x := rect.position.x + distance_from
            var y := randf_range(rect.position.y + shrink, rect.end.y - shrink)
            return Vector2(x, y)
        SIDE_RIGHT:
            var x := rect.end.x - distance_from
            var y := randf_range(rect.position.y + shrink, rect.end.y - shrink)
            return Vector2(x, y)
        SIDE_TOP:
            var x := randf_range(rect.position.x + shrink, rect.end.x - shrink)
            var y := rect.position.y + distance_from
            return Vector2(x, y)
        SIDE_BOTTOM:
            var x := randf_range(rect.position.x + shrink, rect.end.x - shrink)
            var y := rect.end.y - distance_from
            return Vector2(x, y)
        _:
            return rect.get_center()

func get_random_point_in_rect(color_rect: ColorRect) -> Vector2:
    var rect := color_rect.get_global_rect()
    return Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))

## 0 = no hit, 1 = bad hit, 2 = good hit
## When a good projectile is hit, it is hidden and its global_position is stored in last_good_hit_position.
var last_good_hit_position: Vector2 = Vector2.ZERO
var last_bad_hit_position: Vector2 = Vector2.ZERO

func point_collide_projectile(point: Vector2) -> HitType:
    var result: HitType = HitType.None
    for node: Control in get_tree().get_nodes_in_group("projectile_enemy"):
        if not node.visible:
            continue
        var local_point: Vector2 = node.get_global_transform().affine_inverse() * point
        if Rect2(Vector2.ZERO, node.size).has_point(local_point):
            if node.get_meta("good", false):
                last_good_hit_position = node.global_position + node.size * 0.5
                node.visible = false
                return HitType.Good
            else:
                last_bad_hit_position = node.global_position + node.size * 0.5
                return HitType.Bad
    return result

func spawn_coin_drop() -> void:
    var coin: Control = %ProjectileCoinHugeSide.duplicate()
    coin.add_to_group("projectile_enemy")
    add_child(coin)
    coin.global_position.x = get_random_point_in_rect(%coin_huge_start).x
    coin.global_position.y = %ProjectileCoinHugeSide.global_position.y
    var start_y: float = coin.global_position.y
    var tween := get_tree().create_tween()
    tween.tween_property(coin, "global_position:y", start_y + coin_drop_in, coin_drop_in_time)
    tween.tween_interval(coin_pause_time)
    tween.tween_property(coin, "global_position:y", start_y + coin_drop_distance, coin_drop_time)
    tween.tween_callback(coin.queue_free)

func spawn_gryme_wall() -> void:
    var template: TextureRect = %ProjectileGrymeShort
    var piece_height: float = template.size.y
    var piece_width: float = template.size.x
    var count: int = int(SIDE_LENGTH / piece_height)
    var is_left: bool = randi() % 2 == 0
    var spawn_rect: Rect2 = (%gryme_spawn_left if is_left else %gryme_spawn_right).get_global_rect()
    var gaps: int = mini(gryme_gaps, count)
    var gap_start: int = randi() % (count - gaps + 1)
    var skip_indices: Array[int] = []
    for i: int in range(gap_start, gap_start + gaps):
        skip_indices.append(i)
    var copies: Array[TextureRect] = []
    for i: int in range(count):
        if i in skip_indices:
            continue
        var copy: TextureRect = template.duplicate()
        copy.add_to_group("projectile_enemy")
        add_child(copy)
        copy.flip_h = not is_left
        copy.global_position.y = spawn_rect.position.y + i * piece_height
        if is_left:
            copy.global_position.x = spawn_rect.position.x - piece_width
        else:
            copy.global_position.x = spawn_rect.end.x
        copies.append(copy)
    if randf() < gryme_good_chance and copies.size() > 0:
        var good_size: int = randi_range(1, mini(gryme_good_max_size, copies.size()))
        var good_start: int = randi() % (copies.size() - good_size + 1)
        for gi: int in range(good_start, good_start + good_size):
            copies[gi].set_meta("good", true)
            copies[gi].modulate = Color.GREEN
    var travel: float = spawn_rect.size.x + piece_width + SIDE_LENGTH
    for copy: TextureRect in copies:
        var start_x: float = copy.global_position.x
        var inward_x: float = start_x + (gryme_nudge if is_left else -gryme_nudge)
        var across_x: float = start_x + (travel if is_left else -travel)
        var t := get_tree().create_tween()
        t.tween_property(copy, "global_position:x", inward_x, gryme_nudge_time)
        t.tween_interval(gryme_pause_time)
        t.tween_property(copy, "global_position:x", across_x, gryme_sweep_time)
        t.tween_callback(copy.queue_free)

func spawn_dust_bunny() -> void:
    var is_left: bool = randi() % 2 == 0
    var spawn_color: ColorRect = %bunny_spawn_left if is_left else %bunny_spawn_right
    var spawn_rect: Rect2 = spawn_color.get_global_rect()
    var bunny: TextureRect = %ProjectileDustbunny.duplicate()
    bunny.add_to_group("projectile_enemy")
    add_child(bunny)
    if randf() < bunny_good_chance:
        bunny.set_meta("good", true)
        bunny.modulate = Color.GREEN
    bunny.flip_h = not is_left
    var spawn_y: float = randf_range(spawn_rect.position.y, spawn_rect.end.y)
    if is_left:
        bunny.global_position = Vector2(spawn_rect.position.x - bunny.size.x, spawn_y)
    else:
        bunny.global_position = Vector2(spawn_rect.end.x, spawn_y)
    var box_rect: Rect2 = get_global_rect()
    var ground_y: float = box_rect.end.y
    var vel_x: float = randf_range(bunny_speed_min, bunny_speed_max) * (1.0 if is_left else -1.0)
    var vel_y: float = randf_range(bunny_launch_min, bunny_launch_max)
    var gravity: float = bunny_gravity
    var pos: Vector2 = bunny.global_position
    var dt: float = 1.0 / 60.0
    var steps: Array[Vector2] = []
    while pos.y < ground_y or vel_y < 0.0:
        vel_y += gravity * dt
        pos.x += vel_x * dt
        pos.y += vel_y * dt
        steps.append(pos)
    var landing: Vector2 = steps[-1] if steps.size() > 0 else pos
    var duration: float = steps.size() * dt
    var step_idx: int = 0
    var tween := get_tree().create_tween()
    tween.tween_method(
        func(t: float) -> void:
            var idx: int = int(t * (steps.size() - 1))
            idx = clampi(idx, 0, steps.size() - 1)
            bunny.global_position = steps[idx]
    , 0.0, 1.0, duration)
    tween.tween_callback(
        func() -> void:
            bunny.queue_free()
            _spawn_shatter(landing))

var _dust_templates: Array[TextureRect] = []

func _spawn_shatter(origin: Vector2) -> void:
    if _dust_templates.is_empty():
        _dust_templates = [%ProjectileDust0, %ProjectileDust1, %ProjectileDust2, %ProjectileDust3]
    for i: int in range(bunny_shard_count):
        var turn: float = 0.5 + (float(i) / float(bunny_shard_count)) * 0.5
        var dir: Vector2 = turns_to_vec(turn)
        var template: TextureRect = _dust_templates[randi() % _dust_templates.size()]
        var shard: TextureRect = template.duplicate()
        shard.add_to_group("projectile_enemy")
        add_child(shard)
        var offset: Vector2 = dir * bunny_shard_spread
        shard.global_position = origin + offset - shard.size / 2.0
        var target: Vector2 = shard.global_position + dir * bunny_shard_travel
        var t := get_tree().create_tween()
        t.tween_property(shard, "global_position", target, 0.8)
        t.tween_callback(shard.queue_free)

var _active_oozes: Array[TextureRect] = []

func spawn_ooze_target_center_player() -> void:
    var side: Side = [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM].pick_random()
    var spawn_pos: Vector2 = get_random_point_in_side(side, -15.0)
    var target: Vector2 = get_global_mouse_position()
    var ooze: TextureRect = %ProjectileOoze.duplicate()
    ooze.add_to_group("projectile_enemy")
    add_child(ooze)
    ooze.global_position = spawn_pos - ooze.size / 2.0
    var dir_to_target: Vector2 = (target - spawn_pos).normalized()
    ooze.rotation = dir_to_target.angle()
    ooze.set_meta("base_dir", dir_to_target)
    ooze.set_meta("initial_speed", ooze_initial_speed)
    ooze.set_meta("decay", ooze_decay)
    ooze.set_meta("steer", ooze_steer)
    ooze.set_meta("lifetime", ooze_lifetime)
    ooze.set_meta("age", 0.0)
    if randf() < ooze_good_chance:
        ooze.set_meta("good", true)
        ooze.set_meta("good_until", ooze_good_duration * ooze_lifetime)
        ooze.modulate = Color.GREEN
    var tween := get_tree().create_tween()
    tween.tween_interval(ooze_lifetime)
    tween.tween_callback(ooze.queue_free)
    _active_oozes.append(ooze)

func spawn_penny_bounce() -> void:
    var is_left: bool = randi() % 2 == 0
    var spawn_color: ColorRect = %penny_spawn_left if is_left else %penny_spawn_right
    var spawn_rect: Rect2 = spawn_color.get_global_rect()
    var template: TextureRect = [%ProjectileCoinSmall, %ProjectileCoinSmallest].pick_random()
    var penny: TextureRect = template.duplicate()
    penny.add_to_group("projectile_enemy")
    add_child(penny)
    var spawn_y: float = randf_range(spawn_rect.position.y, spawn_rect.end.y)
    if is_left:
        penny.global_position = Vector2(spawn_rect.position.x - penny.size.x, spawn_y)
    else:
        penny.global_position = Vector2(spawn_rect.end.x, spawn_y)
    var box_rect: Rect2 = get_global_rect()
    var ground_y: float = box_rect.end.y
    # Arc 1: initial launch inward and upward
    var vel_x: float = randf_range(penny_speed_min, penny_speed_max) * (1.0 if is_left else -1.0)
    var vel_y: float = randf_range(penny_launch_min, penny_launch_max)
    var gravity: float = penny_gravity
    var bounce_time: float = randf_range(penny_bounce_time_min, penny_bounce_time_max)
    var dt: float = 1.0 / 60.0
    # Simulate arc 1
    var pos: Vector2 = penny.global_position
    var steps: Array[Vector2] = []
    var arc1_steps: int = int(bounce_time / dt)
    for s: int in range(arc1_steps):
        vel_y += gravity * dt
        pos.x += vel_x * dt
        pos.y += vel_y * dt
        steps.append(pos)
    # Arc 2: bounce toward the player's current position
    var bounce_pos: Vector2 = pos
    var mouse_pos: Vector2 = get_global_mouse_position()
    var dir_to_mouse: Vector2 = (mouse_pos - bounce_pos)
    var dist: float = dir_to_mouse.length()
    var flight_time: float = maxf(dist / penny_bounce_strength, 0.3) # time to reach player (lower = more aggressive)
    vel_x = dir_to_mouse.x / flight_time # horizontal speed to cover distance
    vel_y = (dir_to_mouse.y - 0.5 * gravity * flight_time * flight_time) / flight_time # solve for initial vy to arc toward target
    while pos.y < ground_y or vel_y < 0.0:
        vel_y += gravity * dt
        pos.x += vel_x * dt
        pos.y += vel_y * dt
        steps.append(pos)
    var is_good_after_bounce: bool = randf() < penny_good_chance
    var duration: float = steps.size() * dt
    var bounce_progress: float = float(arc1_steps) / float(steps.size()) if steps.size() > 0 else 1.0
    var tween := get_tree().create_tween()
    tween.tween_method(
        func(t: float) -> void:
            var idx: int = int(t * (steps.size() - 1))
            idx = clampi(idx, 0, steps.size() - 1)
            penny.global_position = steps[idx]
            if is_good_after_bounce and t >= bounce_progress:
                penny.set_meta("good", true)
                penny.modulate = Color.GREEN
    , 0.0, 1.0, duration)
    tween.tween_callback(penny.queue_free)

func spawn_droplet_circle() -> void:
    var center: Vector2 = get_random_point_in_rect(%droplet_spawn)
    var mouse_pos: Vector2 = get_global_mouse_position()
    for attempt: int in range(20):
        if center.distance_to(mouse_pos) >= droplet_min_distance:
            break
        center = get_random_point_in_rect(%droplet_spawn)
    var total_fill: float = droplet_fill_gap * droplet_count
    var good_index: int = randi() % droplet_count if randf() < droplet_good_chance else -1
    for i: int in range(droplet_count):
        var turn: float = float(i) / float(droplet_count)
        var dir: Vector2 = turns_to_vec(turn)
        var spawn_delay: float = droplet_fill_gap * i
        var is_good: bool = i == good_index
        var t := get_tree().create_tween()
        t.tween_interval(spawn_delay)
        t.tween_callback(
            func() -> void:
                var droplet: TextureRect = %ProjectileDropletSmall.duplicate()
                droplet.add_to_group("projectile_enemy")
                add_child(droplet)
                if is_good:
                    droplet.set_meta("good", true)
                    droplet.modulate = Color.GREEN
                var offset: Vector2 = dir * droplet_radius
                droplet.global_position = center + offset - droplet.size / 2.0
                droplet.rotation = turns_to_rad(turn - 0.25)
                var target: Vector2 = droplet.global_position + dir * droplet_travel
                var launch_delay: float = total_fill - spawn_delay + droplet_delay
                var d := get_tree().create_tween()
                d.tween_interval(launch_delay)
                d.tween_property(droplet, "global_position", target, droplet_travel_time)
                d.tween_callback(droplet.queue_free))

func spawn_jetstream() -> void:
    var sides: Array[Side] = [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]
    var from_side: Side = sides.pick_random()
    sides.erase(from_side)
    var to_side: Side = sides.pick_random()
    var template: TextureRect = [%ProjectileJetstreamShort, %ProjectileJetstreamLong, %ProjectileJetstreamMedium].pick_random()
    var jet: TextureRect = template.duplicate()
    jet.add_to_group("projectile_enemy")
    add_child(jet)
    if randf() < jet_good_chance:
        jet.set_meta("good", true)
        jet.modulate = Color.GREEN
    var start: Vector2 = get_random_point_in_side(from_side, -jet_offset_out, 20.0)
    var finish: Vector2 = get_random_point_in_side(to_side, -jet_offset_out, 5.0)
    jet.global_position = start - jet.size / 2.0
    var mid: Vector2 = (start + finish) / 2.0
    var perp: Vector2 = (finish - start).normalized().orthogonal()
    var control: Vector2 = mid + perp * jet_arc_height
    var dt: float = 1.0 / 60.0
    var arc_steps: int = int(jet_duration / dt)
    var positions: Array[Vector2] = []
    for s: int in range(arc_steps + 1):
        var t_val: float = float(s) / float(arc_steps)
        var p: Vector2 = (1.0 - t_val) * (1.0 - t_val) * start + 2.0 * (1.0 - t_val) * t_val * control + t_val * t_val * finish
        positions.append(p)
    var exit_dir: Vector2 = (positions[-1] - positions[-2]).normalized()
    var overshoot_steps: int = int(0.2 / dt)
    for s: int in range(1, overshoot_steps + 1):
        positions.append(finish + exit_dir * (jet_overshoot * float(s) / float(overshoot_steps)))
    var total_duration: float = positions.size() * dt
    var tween := get_tree().create_tween()
    tween.tween_method(
        func(t: float) -> void:
            var idx: int = int(t * (positions.size() - 1))
            idx = clampi(idx, 0, positions.size() - 1)
            jet.global_position = positions[idx] - jet.size / 2.0
            if idx < positions.size() - 1:
                jet.rotation = (positions[idx + 1] - positions[idx]).angle() + turns_to_rad(0.25)
    , 0.0, 1.0, total_duration)
    tween.tween_callback(jet.queue_free)

func spawn_wave_minigame() -> void:
    var box_rect: Rect2 = get_global_rect()
    var box_center: Vector2 = box_rect.get_center()
    var wander_range: Vector2 = box_rect.size * wave_wander_factor
    var templates: Array[TextureRect] = [%ProjectileCoinBig, %ProjectileCoinTailzSmall]
    # Random phase offsets for each circle's noise so they move independently
    var seed_a := Vector2(randf() * 100.0, randf() * 100.0)
    var seed_b := Vector2(randf() * 100.0, randf() * 100.0)
    var row_count: int = int(box_rect.size.y / wave_row_spacing)
    for wave: int in range(wave_count):
        var wave_delay: float = wave_spawn_interval * wave
        var wave_time: float = wave_delay
        # Compute safe circle positions via layered sine noise
        var center_a: Vector2 = _wave_noise_pos(box_center, wander_range, wave_wander_speed, wave_time, seed_a)
        var center_b: Vector2 = _wave_noise_pos(box_center, wander_range, wave_wander_speed, wave_time, seed_b)
        var from_left: bool = wave % 2 == 0
        var t := get_tree().create_tween()
        t.tween_interval(wave_delay)
        t.tween_callback(
            func() -> void:
                for row: int in range(row_count):
                    var base_y: float = box_rect.position.y + row * wave_row_spacing + wave_row_spacing / 2.0
                    # Skip rows that fall inside either safe circle
                    var row_pos_a: Vector2 = Vector2(center_a.x, base_y)
                    var row_pos_b: Vector2 = Vector2(center_b.x, base_y)
                    if absf(base_y - center_a.y) < wave_safe_radius:
                        continue
                    if absf(base_y - center_b.y) < wave_safe_radius:
                        continue
                    var template: TextureRect = templates[(row + wave) % templates.size()]
                    var proj: TextureRect = template.duplicate()
                    proj.add_to_group("projectile_enemy")
                    add_child(proj)
                    var start_x: float
                    var end_x: float
                    if from_left:
                        start_x = box_rect.position.x - wave_overshoot
                        end_x = box_rect.end.x + wave_overshoot
                    else:
                        start_x = box_rect.end.x + wave_overshoot
                        end_x = box_rect.position.x - wave_overshoot
                    proj.global_position = Vector2(start_x - proj.size.x / 2.0, base_y - proj.size.y / 2.0)
                    var travel_dist: float = absf(end_x - start_x)
                    var travel_time: float = travel_dist / wave_stream_speed
                    var wave_offset: float = float(row) * 0.4
                    var d := get_tree().create_tween()
                    d.tween_method(
                        func(progress: float) -> void:
                            var current_x: float = lerpf(start_x, end_x, progress)
                            var sine_y: float = sin((progress * travel_time + wave_offset) * wave_sine_frequency * TAU) * wave_sine_amplitude
                            proj.global_position = Vector2(current_x - proj.size.x / 2.0, base_y + sine_y - proj.size.y / 2.0)
                    , 0.0, 1.0, travel_time)
                    d.tween_callback(proj.queue_free)
                # Vertical streams - skip columns inside safe circles
                var col_count: int = int(box_rect.size.x / wave_row_spacing)
                var from_top: bool = wave % 2 == 0
                for col: int in range(col_count):
                    var base_x: float = box_rect.position.x + col * wave_row_spacing + wave_row_spacing / 2.0
                    if absf(base_x - center_a.x) < wave_safe_radius:
                        continue
                    if absf(base_x - center_b.x) < wave_safe_radius:
                        continue
                    var vtemplate: TextureRect = templates[(col + wave + 1) % templates.size()]
                    var vproj: TextureRect = vtemplate.duplicate()
                    vproj.add_to_group("projectile_enemy")
                    add_child(vproj)
                    var start_y: float
                    var end_y: float
                    if from_top:
                        start_y = box_rect.position.y - wave_overshoot
                        end_y = box_rect.end.y + wave_overshoot
                    else:
                        start_y = box_rect.end.y + wave_overshoot
                        end_y = box_rect.position.y - wave_overshoot
                    vproj.global_position = Vector2(base_x - vproj.size.x / 2.0, start_y - vproj.size.y / 2.0)
                    var vtravel_dist: float = absf(end_y - start_y)
                    var vtravel_time: float = vtravel_dist / wave_stream_speed
                    var vwave_offset: float = float(col) * 0.4
                    var vd := get_tree().create_tween()
                    vd.tween_method(
                        func(progress: float) -> void:
                            var current_y: float = lerpf(start_y, end_y, progress)
                            var sine_x: float = sin((progress * vtravel_time + vwave_offset) * wave_sine_frequency * TAU) * wave_sine_amplitude
                            vproj.global_position = Vector2(base_x + sine_x - vproj.size.x / 2.0, current_y - vproj.size.y / 2.0)
                    , 0.0, 1.0, vtravel_time)
                    vd.tween_callback(vproj.queue_free))
    # Debug: track circles for _draw
    _wave_debug = true
    _wave_box_center = box_center
    _wave_wander_range = wander_range
    _wave_wander_speed = wave_wander_speed
    _wave_seed_a = seed_a
    _wave_seed_b = seed_b
    _wave_safe_radius = wave_safe_radius
    _wave_age = 0.0
    var total_time: float = wave_spawn_interval * wave_count + (box_rect.size.x + wave_overshoot * 2.0) / wave_stream_speed
    # if you want to change the time of the minigame, you have to solve the above calculation
    assert(is_equal_approx(total_time, expected_time_for_minigame))
    var end_tween := get_tree().create_tween()
    end_tween.tween_interval(total_time)
    end_tween.tween_callback(func() -> void: _wave_debug = false)

var _wave_debug: bool = false
var _wave_safe_radius: float = 0.0
var _wave_box_center: Vector2 = Vector2.ZERO
var _wave_wander_range: Vector2 = Vector2.ZERO
var _wave_wander_speed: float = 0.0
var _wave_seed_a: Vector2 = Vector2.ZERO
var _wave_seed_b: Vector2 = Vector2.ZERO
var _wave_age: float = 0.0

func _wave_noise_pos(center: Vector2, wander: Vector2, spd: float, t: float, seed: Vector2) -> Vector2:
    # Layered sine waves at incommensurate frequencies for smooth, non-repeating motion
    var x: float = center.x + wander.x * (
        sin(spd * t * 1.0 + seed.x) * 0.5
        + sin(spd * t * 1.7 + seed.y * 3.1) * 0.3
        + sin(spd * t * 0.6 + seed.x * 2.3) * 0.2)
    var y: float = center.y + wander.y * (
        sin(spd * t * 1.3 + seed.y) * 0.5
        + sin(spd * t * 0.9 + seed.x * 1.7) * 0.3
        + sin(spd * t * 2.1 + seed.y * 0.7) * 0.2)
    return Vector2(x, y)

#func _draw() -> void:
    #if not _wave_debug:
        #return
    #var center_a: Vector2 = _wave_noise_pos(_wave_box_center, _wave_wander_range, _wave_wander_speed, _wave_age, _wave_seed_a)
    #var center_b: Vector2 = _wave_noise_pos(_wave_box_center, _wave_wander_range, _wave_wander_speed, _wave_age, _wave_seed_b)
    ## Convert global to local for draw calls
    #var local_a: Vector2 = center_a - global_position
    #var local_b: Vector2 = center_b - global_position
    #draw_arc(local_a, _wave_safe_radius, 0.0, TAU, 32, Color(0, 1, 0, 0.5), 1.0)
    #draw_arc(local_b, _wave_safe_radius, 0.0, TAU, 32, Color(0, 1, 0, 0.5), 1.0)

func _ready() -> void:
    if get_tree().current_scene == self:
        Audio.kill_debug()
        var scroll: ScrollContainer = %VBoxContainer.get_parent()
        scroll.top_level = true
        for method: Dictionary in get_method_list():
            var method_name: String = method.name
            if method_name.begins_with("spawn"):
                var button := Button.new()
                button.text = method_name
                button.pressed.connect(
                    func() -> void:
                        #Callable(self, method_name)
                        var timer := get_tree().create_timer(0.5)
                        await timer.timeout
                        self.call(method_name)
                        pass)
                %VBoxContainer.add_child(button)
    else:
        $ScrollContainer.queue_free()

func _process(delta: float) -> void:
    var hit := point_collide_projectile(get_global_mouse_position())
    if hit == HitType.Good:
        print("Good")
    elif hit == HitType.Bad:
        print("Bad")
    
    if _wave_debug:
        _wave_age += delta
        queue_redraw()
    var i: int = _active_oozes.size() - 1
    while i >= 0:
        var ooze: TextureRect = _active_oozes[i]
        if not is_instance_valid(ooze):
            _active_oozes.remove_at(i)
            i -= 1
            continue
        var age: float = ooze.get_meta("age") + delta
        ooze.set_meta("age", age)
        if ooze.get_meta("good", false) and age >= ooze.get_meta("good_until", 0.0):
            ooze.set_meta("good", false)
            ooze.modulate = Color.WHITE
        var base_dir: Vector2 = ooze.get_meta("base_dir")
        var initial_speed: float = ooze.get_meta("initial_speed")
        var decay_rate: float = ooze.get_meta("decay")
        var steer_strength: float = ooze.get_meta("steer")
        var lifetime: float = ooze.get_meta("lifetime")
        var decay_factor: float = exp(-decay_rate * age)
        var spd: float = initial_speed * decay_factor
        var current_steer: float = steer_strength * (1.0 - age / lifetime)
        var ooze_center: Vector2 = ooze.global_position + ooze.size / 2.0
        var dir_to_mouse: Vector2 = (get_global_mouse_position() - ooze_center).normalized()
        var direction: Vector2 = (base_dir + dir_to_mouse * maxf(current_steer, 0.0)).normalized()
        ooze.global_position += direction * spd * delta
        ooze.rotation = direction.angle()
        i -= 1
