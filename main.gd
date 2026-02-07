extends Node2D

##### Resource Constants #####
const droplet_frames := preload("res://frames_droplet.tres")
const dirt_frames := preload("res://frames_dirt.tres")
const flash_shader := preload("res://flash.gdshader")
const car0_scene := preload("res://car_0.tscn")
const car1_scene := preload("res://car_1.tscn")
const car2_scene := preload("res://car_2.tscn")
const vfx_plus_tex := preload("res://image/vfx_plus.png")
const vfx_minus_tex := preload("res://image/vfx_minus.png")

var enemy_data: ConfigFile = ConfigFile.new()
@onready var car0 := car0_scene.instantiate()
@onready var car1 := car1_scene.instantiate()
@onready var car2 := car2_scene.instantiate()

##### Enums #####
enum BattlePhase {
    None,
    TransitionIn,
    EnemyEnter,
    EnemyTurn,
    PlayerEnter,
    PlayerTurn,
    TransitionOut,
}

enum Scene {
    Title,
    Wash,
    Battle,
    GameEnd,
}

enum CommandType {
    None,
    Debug_Submit,
    Move_Left,
    Move_Right,
    Move_Up,
    Move_Down,
    Droplet_New,
    Droplet_Finish,
    Grime_Dead,
    Battle_Start,
    Battle_End,
}

##### Classes #####
class Command:
    var type: CommandType
    var args: Array[Variant]

    func _init(ctype: CommandType, _args: Array[Variant] = []) -> void:
        type = ctype
        args = _args

class Settings extends Node:
    var level_music := 5
    var level_sfx := 5
    var window_mode := DisplayServer.WindowMode.WINDOW_MODE_WINDOWED
    var where := "pause"
    var hovering := "none"
    var settings_node: CanvasLayer
    var just_entered := false
    var hoverable_nodes := ["label_resume", "label_audio", "label_fullscreen", "label_exit", "label_back"]
    
    func _init() -> void:
        if OS.has_feature("release"):
            window_mode = DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN
        process_mode = Node.PROCESS_MODE_WHEN_PAUSED

    func _ready() -> void:
        for nodename: String in hoverable_nodes:
            var label: Control = settings_node.find_child(nodename)
            label.mouse_entered.connect(
                func() -> void:
                    hovering = nodename
                    pass)
        for volume_part: int in range(10):
            var music_part: Control = settings_node.find_child("m%s" % str(volume_part + 1))
            var sfx_part: Control = settings_node.find_child("s%s" % str(volume_part + 1))
            music_part.gui_input.connect(
                func(event: InputEvent) -> void:
                    if event.is_action_pressed("input_action"):
                        var old_level := level_music
                        level_music = volume_part + 1
                        if volume_part == 0 and old_level == 1:
                            level_music = 0
                    pass)
            sfx_part.gui_input.connect(
                func(event: InputEvent) -> void:
                    if event.is_action_pressed("input_action"):
                        var old_level := level_sfx
                        level_sfx = volume_part + 1
                        if volume_part == 0 and old_level == 1:
                            level_sfx = 0
                    pass)

    func _process(delta: float) -> void:
        #print(hovering)
        settings_node.visible = true
        if not just_entered and Input.is_action_just_pressed("input_interrupt"):
            settings_node.visible = false
            get_tree().paused = false
        if Input.is_action_just_pressed("input_action"):
            match hovering:
                "label_resume":
                    get_tree().paused = false
                    settings_node.visible = false
                "label_audio":
                    where = "audio"
                "label_fullscreen":
                    if window_mode == DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN:
                        window_mode = DisplayServer.WindowMode.WINDOW_MODE_WINDOWED
                    elif window_mode == DisplayServer.WindowMode.WINDOW_MODE_WINDOWED:
                        window_mode = DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN
                    DisplayServer.window_set_mode(window_mode)
                "label_exit":
                    get_tree().quit()
                "label_back":
                    where = "pause"
        just_entered = false
        settings_node.find_child("PauseBg").visible = false
        settings_node.find_child("AudioBg").visible = false
        match where:
            "pause":
                settings_node.find_child("PauseBg").visible = true
            "audio":
                settings_node.find_child("AudioBg").visible = true
        
        for nodepath: String in hoverable_nodes:
            settings_node.find_child("%s_bubble0" % nodepath).visible = hovering == nodepath
            settings_node.find_child("%s_bubble1" % nodepath).visible = hovering == nodepath

        var music_bus := AudioServer.get_bus_index("Music")
        var sfx_bus := AudioServer.get_bus_index("Sound Effect")
        var music_normalized: float = level_music / 10.0
        var sfx_normalized: float = level_sfx / 10.0
        AudioServer.set_bus_volume_db(music_bus, lerpf(-40.0, 0.0, music_normalized * music_normalized))
        AudioServer.set_bus_volume_db(sfx_bus, lerpf(-40.0, 0.0, sfx_normalized * sfx_normalized))
        AudioServer.set_bus_mute(music_bus, level_music == 0)
        AudioServer.set_bus_mute(sfx_bus, level_sfx == 0)
        for i: int in range(10):
            settings_node.find_child("m%s" % str(i + 1)).modulate.a = 1.0 if i < level_music else 0.3
            settings_node.find_child("s%s" % str(i + 1)).modulate.a = 1.0 if i < level_sfx else 0.3

class Droplet:
    var stream_progress := 0.0 # value from 0 to 1
    var stream_source: WaterStream
    var droplet_sprite: AnimatedSprite2D
    var damage_deals := 1.0

    func _init(droplets_parent: Node2D, stream: WaterStream, frames: SpriteFrames, god_active := false) -> void:
        droplet_sprite = AnimatedSprite2D.new()
        stream_source = stream
        droplet_sprite.sprite_frames = frames
        droplets_parent.add_child(droplet_sprite)
        if god_active:
            damage_deals = 1000.0

class EnemyConfigData:
    var transition_color := Color.BLUE_VIOLET
    var background_layers: Array[String] = []
    var attack_patterns: Array[String] = []

func get_sprite_rect(sprite: Variant) -> Rect2:
    var result: Rect2 = Rect2(Vector2.INF, Vector2.ZERO)
    if sprite is Sprite2D:
        result = sprite.get_rect()
    elif sprite is AnimatedSprite2D:
        var tex: Texture2D = sprite.sprite_frames.get_frame_texture(
            sprite.animation,
            sprite.frame
        )
        var size: Vector2 = tex.get_size()
        result = Rect2(-size * 0.5, size)

    return result

class BattleSession:
    var phase: BattlePhase = BattlePhase.TransitionIn
    var turn_timer: float = 0.0
    var clock_delta: float = 0.0
    var path_progress: float = 0.0
    var invuln_timer: float = 0.0
    var enemy_move_tween: Tween
    var timer_tween: Tween
    var clock_delta_tween: Tween

    func kill_tweens() -> void:
        for tw: Tween in [enemy_move_tween, timer_tween, clock_delta_tween]:
            if tw and tw.is_running():
                tw.kill()

##### Instance Variables #####
var commands: Array[Command] = []
var settings := Settings.new()
var scene_current: Scene = Scene.Wash
var scene_die := Scene.Wash
@export_range(1, 3, 1) var day_current := 1
var car_current: Entity
var battle: BattleSession
var enemy_config_data: Dictionary[String, EnemyConfigData] = {}

var locations: Array[String] = ["front", "side_left", "back", "side_right",]
var location_index: int = 0
@export var max_player_height: float = 50.0
@export var mouse_speed_decay: float = 5.0

var thing_battling: Entity
var _death_pending: bool = false
@export var timer_hide_distance: float = 30.0
@export var timer_hide_duration: float = 0.3
@export var game_clock_start: float = 300.0
var game_clock: float = 0.0
var game_clock_starting_time := [300.0, 300.0, 300.0]
var game_clock_histories := {
    "Durt": 0.0,
    "Gryme": 0.0,
    "Battlebottle": 0.0,
    "Ooze": 0.0,
    "Penny": 0.0,
    "Heads": 0.0,
    "Tailz": 0.0,
    "Receiptpete": 0.0,
}
var username := ""
var pink_offset: Vector2 = Vector2.ZERO
var yellow_offset: Vector2 = Vector2.ZERO
var mouse_speed: float = 0.0
var _prev_mouse_pos: Vector2 = Vector2.ZERO

var drops: Array[Droplet] = []
var grime: Array[Node2D] = []

# Hit effect tracking
var hit_effect_timers: Dictionary[Entity, float] = {}  # Entity -> time remaining
var hit_sounds: Dictionary[Entity, Audio.PlayingSound] = {}

var game_clock_timeout_handled := false
var _day_transitioning := false
var god_mode := false

func spawn_cars() -> void:
    hit_effect_timers.clear()
    hit_sounds.clear()
    if car0:
        %cars.remove_child(car0)
        car0.queue_free()
    if car1:
        %cars.remove_child(car1)
        car1.queue_free()
    if car2:
        %cars.remove_child(car2)
        car2.queue_free()
    car0 = car0_scene.instantiate()
    car1 = car1_scene.instantiate()
    car2 = car2_scene.instantiate()
    car0.add_to_group("car")
    car1.add_to_group("car")
    car2.add_to_group("car")
    %cars.add_child(car0)
    %cars.add_child(car1)
    %cars.add_child(car2)
    car_current = car0
    _spawn_dirt(car0, 10.0, Vector2(21, 27), Vector2(1, 7), Vector2(9, 20), Vector2(1, 7))
    _spawn_dirt(car1, 10.0, Vector2(59, 78), Vector2(28, 58), Vector2(79, 107), Vector2(28, 58))
    _spawn_dirt(car2, 10.0, Vector2(1, 7), Vector2(21, 27), Vector2(28, 58), Vector2(79, 107))

func _spawn_dirt(car: Entity, min_distance: float,
        front_frame_range: Vector2, right_frame_range: Vector2,
        back_frame_range: Vector2, left_frame_range: Vector2) -> void:
    var face_frame_ranges: Dictionary[String, Vector2] = {
        "car_front": front_frame_range,
        "car_right": right_frame_range,
        "car_back": back_frame_range,
        "car_left": left_frame_range,
    }
    var enemy_frame_map: Dictionary[Entity.EnemyType, int] = {}
    var enemy_frame_count: int = dirt_frames.get_frame_count("Enemy") - 1
    var enemy_type_count: int = Entity.EnemyType.size() - 1 # exclude None
    for polygon: Polygon2D in car.polygons:
        var face_name: String = polygon.name.replace("_polygon", "")
        var face_sprite: Node = car.find_child(face_name)
        if not face_sprite:
            push_warning("No face sprite found for polygon %s" % polygon.name)
            continue
        # Remove pre-existing Entity children from this face
        var existing_entities: Array[Node] = []
        for child: Node in face_sprite.get_children():
            if child is Entity:
                existing_entities.append(child)
        for child: Node in existing_entities:
            face_sprite.remove_child(child)
            child.queue_free()
        var frame_range: Vector2 = face_frame_ranges.get(face_name, Vector2(0, 0))
        var frame_min: int = int(frame_range.x)
        var frame_max: int = int(frame_range.y)
        var spawn_list: Array[Dictionary] = []
        for j: int in range(4):
            spawn_list.append({"grime_type": Entity.GrimeType.None, "enemy_type": Entity.EnemyType.None, "animation": "None", "frame": randi_range(frame_min, frame_max)})
        for j: int in range(4):
            var etype: Entity.EnemyType = (randi_range(1, enemy_type_count) as Entity.EnemyType)
            if not enemy_frame_map.has(etype):
                enemy_frame_map[etype] = randi_range(0, enemy_frame_count)
            spawn_list.append({"grime_type": Entity.GrimeType.Enemy, "enemy_type": etype, "animation": "Enemy", "frame": enemy_frame_map[etype]})
        var placed_rects: Array[Rect2] = []
        for spawn: Dictionary in spawn_list:
            var entity := Entity.new()
            entity.grime_type = spawn["grime_type"] as Entity.GrimeType
            entity.enemy_type = spawn["enemy_type"] as Entity.EnemyType
            var sprite := AnimatedSprite2D.new()
            var mat := ShaderMaterial.new()
            mat.shader = flash_shader
            mat.set_shader_parameter("hit_effect", 0.0)
            mat.set_shader_parameter("shake_intensity", 10.0)
            mat.set_shader_parameter("flash_speed", 30.0)
            mat.set_shader_parameter("flash_color", Color.WHITE)
            sprite.sprite_frames = dirt_frames
            sprite.animation = spawn["animation"] as String
            sprite.frame = spawn["frame"] as int
            sprite.material = mat
            entity.sprite_path = NodePath("sprite")
            sprite.name = "sprite"
            entity.add_child(sprite)
            face_sprite.add_child(entity)
            var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
            var sprite_size: Vector2 = tex.get_size()
            var half_size: Vector2 = sprite_size * 0.5
            # Try random placement first
            var pos: Vector2 = Util.get_random_global_point_in_polygon2d_reduced_by_sprite_rect(polygon, sprite)
            var found := false
            for attempt: int in range(50):
                var candidate_rect := Rect2(pos - half_size, sprite_size).grow(min_distance)
                var overlaps := false
                for existing: Rect2 in placed_rects:
                    if candidate_rect.intersects(existing):
                        overlaps = true
                        break
                if not overlaps:
                    found = true
                    break
                pos = Util.get_random_global_point_in_polygon2d_reduced_by_sprite_rect(polygon, sprite)
            # Grid search fallback if random failed
            if not found:
                var shrunk_polys: Array[PackedVector2Array] = Util.get_shrunk_polygon(polygon, sprite)
                if not shrunk_polys.is_empty():
                    var best_pos: Vector2 = pos
                    var best_clearance: float = -INF
                    var grid_step: float = 4.0
                    var bounds := Rect2(shrunk_polys[0][0], Vector2.ZERO)
                    for poly: PackedVector2Array in shrunk_polys:
                        for pt: Vector2 in poly:
                            bounds = bounds.expand(pt)
                    var gy: float = bounds.position.y
                    while gy <= bounds.end.y:
                        var gx: float = bounds.position.x
                        while gx <= bounds.end.x:
                            var candidate := Vector2(gx, gy)
                            var inside := false
                            for poly: PackedVector2Array in shrunk_polys:
                                if Geometry2D.is_point_in_polygon(candidate, poly):
                                    inside = true
                                    break
                            if inside:
                                var worst_clearance: float = INF
                                for existing: Rect2 in placed_rects:
                                    var padded := existing.grow(min_distance)
                                    var candidate_rect := Rect2(candidate - half_size, sprite_size)
                                    if candidate_rect.intersects(padded):
                                        var overlap_x: float = minf(candidate_rect.end.x, padded.end.x) - maxf(candidate_rect.position.x, padded.position.x)
                                        var overlap_y: float = minf(candidate_rect.end.y, padded.end.y) - maxf(candidate_rect.position.y, padded.position.y)
                                        worst_clearance = minf(worst_clearance, -minf(overlap_x, overlap_y))
                                    else:
                                        var dx: float = maxf(padded.position.x - candidate_rect.end.x, candidate_rect.position.x - padded.end.x)
                                        var dy: float = maxf(padded.position.y - candidate_rect.end.y, candidate_rect.position.y - padded.end.y)
                                        worst_clearance = minf(worst_clearance, maxf(dx, dy))
                                if worst_clearance > best_clearance:
                                    best_clearance = worst_clearance
                                    best_pos = candidate
                            gx += grid_step
                        gy += grid_step
                    if best_clearance >= 0.0:
                        pos = best_pos
                        found = true
            if not found:
                # No non-overlapping position exists — don't spawn this entity
                face_sprite.remove_child(entity)
                entity.queue_free()
                continue
            entity.global_position = pos
            placed_rects.append(Rect2(pos - half_size, sprite_size))

func _update_timer_display() -> void:
    var clamped: int = maxi(int(ceil(game_clock)), 0)
    var minutes: int = clamped / 60
    var seconds: int = clamped % 60
    %timer/numbers1.frame = minutes / 10
    %timer/numbers2.frame = minutes % 10
    %timer/numbers3.frame = seconds / 10
    %timer/numbers4.frame = seconds % 10

func _is_car_clean(car: Entity) -> bool:
    for face: Node in car.get_children():
        if face is not Sprite2D:
            continue
        for child: Node in face.get_children():
            if child is Entity and child.visible and child.hp > 0.0:
                return false
    return true

func _advance_day() -> void:
    if _day_transitioning:
        return
    _day_transitioning = true
    %transition_battle.visible = true
    %transition_battle.animation = "horizontal"
    %transition_battle.frame = 17
    var tween := get_tree().create_tween()
    tween.tween_method(
        func(value: Color) -> void:
            %transition_battle.material.set_shader_parameter("transition_color", value)
    , Color.TRANSPARENT, Color.BLACK, 1.0)
    tween.tween_callback(
        func() -> void:
            if day_current >= 3:
                scene_current = Scene.GameEnd
                _day_transitioning = false
                return
            day_current += 1
            location_index = 0)
    tween.tween_method(
        func(value: Color) -> void:
            %transition_battle.material.set_shader_parameter("transition_color", value)
    , Color.BLACK, Color.TRANSPARENT, 1.0)
    tween.tween_callback(
        func() -> void:
            %transition_battle.visible = false
            _day_transitioning = false)

func _animate_clock_delta(delta_value: float) -> void:
    if delta_value == 0.0:
        return
    var delta_color: Color = Color.RED if delta_value < 0.0 else Color.GREEN
    for child: Node in %timer.get_children():
        child.modulate = delta_color
    var start_clock: float = game_clock
    var target_clock: float = maxf(game_clock + delta_value, 0.0)
    var duration: float = 0.5
    var tween: Tween = get_tree().create_tween()
    tween.tween_method(
        func(value: float) -> void:
            game_clock = value
            _update_timer_display()
    , start_clock, target_clock, duration)
    tween.tween_callback(
        func() -> void:
            for child: Node in %timer.get_children():
                child.modulate = Color.WHITE
    )

func _ready() -> void:
    if OS.has_environment("USERNAME"):
        username = OS.get_environment("USERNAME")
    elif OS.has_environment("USER"):
        username = OS.get_environment("USER")
    else:
        username = "Employee #63510"
    if OS.has_feature("web"):
        username = "Employee #63510"
    print(username)
    var data_result: Error = enemy_data.load("res://enemy_data.cfg")
    assert(data_result == OK)
    for enemy_name: String in Entity.EnemyType.keys():
        if enemy_name == "None":
            continue
        var enemy_config_datum: EnemyConfigData = EnemyConfigData.new()
        enemy_config_datum.transition_color = enemy_data.get_value(enemy_name, "transition_color")
        var which_background: String = enemy_data.get_value(enemy_name, "background")
        var background_layers: Array = enemy_data.get_value(which_background, "layers")
        enemy_config_datum.background_layers.assign(background_layers)
        var attack_patterns: Array = enemy_data.get_value(enemy_name, "attack_patterns")
        enemy_config_datum.attack_patterns.assign(attack_patterns)
        enemy_config_data[enemy_name] = enemy_config_datum
    
    %timer.position = Vector2(201, -20)
    game_clock = game_clock_start
    _update_timer_display()
    settings.settings_node = %settings
    add_child(settings)
    DisplayServer.window_set_mode(settings.window_mode)
    
    Audio.kill_debug()
    Audio.create_music(Audio.MusicType.Wash)
    for area: Area2D in %ui_left.area_clickable:
        area.area_entered.connect(
            func(other_area: Area2D) -> void:
                if other_area.name == "recticle_area" and scene_current == Scene.Wash:
                    %ui_left.mouse_hover = true
                    %ui_left.mouse_just_hover = true
                pass)
        area.area_exited.connect(
            func(other_area: Area2D) -> void:
                if other_area.name == "recticle_area":
                    %ui_left.mouse_hover = false
                pass)
        area.connect("mouse_entered",
        func() -> void:
            %ui_left.mouse_hover = true
            %ui_left.mouse_just_hover = true
            pass)
        area.connect("mouse_exited",
        func() -> void:
            %ui_left.mouse_hover = false
            pass)
        area.connect("input_event",
        func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
            if event.is_action_pressed("input_action"):
                %ui_left.just_pressed = true)
    for area: Area2D in %ui_right.area_clickable:
        area.area_entered.connect(
            func(other_area: Area2D) -> void:
                if other_area.name == "recticle_area" and scene_current == Scene.Wash:
                    %ui_right.mouse_hover = true
                    %ui_right.mouse_just_hover = true
                pass)
        area.area_exited.connect(
            func(other_area: Area2D) -> void:
                if other_area.name == "recticle_area":
                    %ui_left.mouse_hover = false
                pass)
        area.connect("mouse_entered",
        func() -> void:
            %ui_right.mouse_hover = true
            %ui_right.mouse_just_hover = true
            pass)
        area.connect("mouse_exited",
        func() -> void:
            %ui_right.mouse_hover = false
            pass)
        area.connect("input_event",
        func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
            if event.is_action_pressed("input_action"):
                %ui_right.just_pressed = true)
    %debug_edit.connect("text_submitted", func(text: String) -> void:
        var command: Command = Command.new(CommandType.Debug_Submit)
        command.args = [text]
        commands.append(command)
        pass)
    
    spawn_cars()
    if OS.has_feature("release"):
        scene_current = Scene.Title
    # Initialize grime for starting location
    #grime.clear()
    #for child in car_current.get_child(location_index).get_children():
        #if child is Entity:
            #grime.append(child)

##### UI Animation Functions #####
func ui_anim_enemy_enter() -> void:
    battle.enemy_move_tween = get_tree().create_tween()
    battle.enemy_move_tween\
        .tween_property(%battle_enemy, "global_position", %enemy_place_while_battle.global_position, 0.5)\
        .set_trans(Tween.TRANS_QUAD)

func ui_anim_enemy_exit() -> void:
    battle.enemy_move_tween = get_tree().create_tween()
    @warning_ignore("integer_division")
    battle.enemy_move_tween.tween_property(%battle_enemy, "global_position", Vector2(320/2, 180/2), 0.5).set_trans(Tween.TRANS_QUAD)

##### Battle Phase Transitions #####
func _battle_transition_in_anim_finished() -> void:
    if not battle or battle.phase != BattlePhase.TransitionIn:
        return
    var tween: Tween = get_tree().create_tween()
    tween.tween_method(
        func(value: Color) -> void:
            %transition_battle.material.set_shader_parameter("transition_color", value)
    , Color(%transition_battle.material.get_shader_parameter("transition_color")), Color.BLACK, 0.5)
    tween.tween_callback(
        func() -> void:
            var callback_command: Command = Command.new(CommandType.Debug_Submit)
            callback_command.args = ["go battle"]
            commands.append(callback_command)
            # Populate grime array with battle enemy
            grime.clear()
            grime.append(%battle_enemy))
    tween.tween_method(
        func(value: float) -> void:
            %transition_battle.material.set_shader_parameter("transition_color", Color(0.0,0.0,0.0,value))
    , 1.0, 0.0, 0.5)
    tween.tween_callback(
        func() -> void:
            if not battle or battle.phase != BattlePhase.TransitionIn:
                return
            %transition_battle.visible = false
            _death_pending = false
            _battle_start_enemy_enter())

func _battle_start_enemy_enter() -> void:
    if %battle_enemy.hp <= 0.0:
        return
    battle.phase = BattlePhase.EnemyEnter
    %ui_anim.play("battle_enemy") # calls ui_anim_enemy_enter()
    if not %ui_anim.animation_finished.is_connected(_battle_enemy_enter_finished):
        %ui_anim.animation_finished.connect(_battle_enemy_enter_finished, CONNECT_ONE_SHOT)

func _battle_enemy_enter_finished(_anim_name: StringName) -> void:
    if not battle or battle.phase != BattlePhase.EnemyEnter:
        return
    battle.phase = BattlePhase.EnemyTurn
    battle.turn_timer = 5.0
    %battle_patterns.expected_time_for_minigame = battle.turn_timer
    var battle_rect: Rect2 = %battle_patterns.get_global_rect()
    Input.warp_mouse(Util.game_to_window(self, Vector2(battle_rect.position + battle_rect.size * 0.5)))
    %battle_cursor.visible = true
    %battle_runner.play(enemy_config_data[Entity.EnemyType.keys()[thing_battling.enemy_type]].attack_patterns.pick_random())

func _reset_battle_state() -> void:
    if battle:
        battle.kill_tweens()
    battle = null
    _death_pending = false
    hit_effect_timers.clear()
    hit_sounds.clear()
    %battle_cursor.visible = false
    %battle_runner.stop()
    %ui_anim.stop()
    %battle_patterns.position = Vector2(158, 200)
    %battle_enemy.global_position = Vector2(320.0 / 2.0, 180.0 / 2.0)
    %battle_enemy.sprite.material.set_shader_parameter("hit_effect", 0.0)

func _spawn_hit_vfx(pos: Vector2, is_good: bool) -> void:
    var sprite := Sprite2D.new()
    sprite.texture = vfx_plus_tex if is_good else vfx_minus_tex
    sprite.modulate = Color(0.2, 1.0, 0.2) if is_good else Color(1.0, 0.2, 0.2)
    sprite.global_position = pos
    add_child(sprite)
    var tw: Tween = get_tree().create_tween()
    tw.set_parallel(true)
    tw.tween_property(sprite, "global_position:y", pos.y - 15.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(sprite, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    tw.chain().tween_callback(sprite.queue_free)

func _battle_start_player_enter() -> void:
    battle.phase = BattlePhase.PlayerEnter
    %battle_runner.stop()
    %ui_anim.play("battle_player") # calls ui_anim_enemy_exit()
    %ui_anim.animation_finished.connect(_battle_player_enter_finished, CONNECT_ONE_SHOT)

func _battle_player_enter_finished(_anim_name: StringName) -> void:
    if not battle or battle.phase != BattlePhase.PlayerEnter:
        return
    if battle.enemy_move_tween and battle.enemy_move_tween.is_running():
        battle.enemy_move_tween.kill()
    battle.phase = BattlePhase.PlayerTurn
    battle.turn_timer = 3.0
    battle.path_progress = 0.0
    var curve: Curve2D = %enemy_path.curve
    %battle_enemy.global_position = curve.sample_baked(0.0)

var check_hose: bool = true

func _process(delta: float) -> void:
    if Input.is_action_just_pressed("input_interrupt"):
        settings.just_entered = true
        get_tree().paused = true
    if (not %ui_left.mouse_hover and not %ui_right.mouse_hover) or Input.is_action_just_released("input_action"):
        check_hose = true
    if scene_current != Scene.Wash and scene_current != Scene.Battle:
        check_hose = false
    if %ui_left.mouse_hover and Input.is_action_just_pressed("input_action"):
        commands.append(Command.new(CommandType.Move_Left))
        check_hose = false
    if %ui_right.mouse_hover and Input.is_action_just_pressed("input_action"):
        commands.append(Command.new(CommandType.Move_Right))
        check_hose = false
    if scene_current == Scene.Battle and (not battle or battle.phase != BattlePhase.PlayerTurn):
        check_hose = false
    if check_hose and Input.is_action_pressed("input_action"):
        commands.append(Command.new(CommandType.Droplet_New))
    if check_hose and Input.is_action_just_pressed("input_action"):
        Audio.stop_sound(Audio.SoundEffectType.Water_Hose, 0.5)
        Audio.create_2d_sfx_at_location(%player_hose.global_position, Audio.SoundEffectType.Water_Hose)
    
    if scene_current == Scene.Title:
        if Input.is_action_just_pressed("input_action"):
            %title_screen_anim.play("begin")
            %title_screen_anim.animation_finished.connect(
                func(anim_name: String) -> void:
                    if anim_name != "RESET":
                        _reset_battle_state()
                        day_current = 1
                        game_clock = game_clock_starting_time[day_current - 1]
                        game_clock_timeout_handled = false
                        spawn_cars()
                        scene_current = Scene.Wash
                    pass)
    if scene_current == Scene.GameEnd:
        if Input.is_action_just_pressed("input_action"):
            %title_screen_anim.play("RESET")
            scene_current = Scene.Title
            Audio.stop_all_music()
            Audio.create_music(Audio.MusicType.Wash)
    
    var current_mouse_pos: Vector2 = get_global_mouse_position()
    var instant_speed: float = current_mouse_pos.distance_to(_prev_mouse_pos) / delta
    mouse_speed = lerpf(mouse_speed, instant_speed, mouse_speed_decay * delta)
    _prev_mouse_pos = current_mouse_pos

    %ui_left.mouse_just_hover = false
    %ui_right.mouse_just_hover = false
    %ui_left.just_pressed = false
    %ui_right.just_pressed = false

    pink_offset += Vector2(-3 * -0.00005, 20 * -0.00005)
    yellow_offset += Vector2(17 * -0.00005, 74 * -0.00005)

    # Update hit effect timers and clean up finished sounds
    var to_clear: Array[Entity] = []
    for entity: Entity in hit_effect_timers:
        hit_effect_timers[entity] -= delta
        if hit_effect_timers[entity] <= 0.0:
            if entity.hp > 0.0:  # Only clear effect if still alive
                entity.sprite.material.set_shader_parameter("hit_effect", 0.0)
            to_clear.append(entity)
            # Stop the sound with a fade when effect ends
            var existing_sound: Audio.PlayingSound = hit_sounds.get(entity, null)
            if existing_sound:
                Audio.stop_specific_sound(existing_sound, 0.5)

    for entity: Entity in to_clear:
        hit_effect_timers.erase(entity)

    # Clean up hit_sounds dict - remove entries where sound nodes are gone
    var sounds_to_remove: Array[Entity] = []
    for entity: Entity in hit_sounds.keys():
        var sound: Audio.PlayingSound = hit_sounds[entity]
        # Check if both nodes are gone/invalid
        if sound:
            var node_valid: bool = sound.node and not sound.node.is_queued_for_deletion()
            var node2d_valid: bool = sound.node2d and not sound.node2d.is_queued_for_deletion()
            if not node_valid and not node2d_valid:
                sounds_to_remove.append(entity)

    for entity: Entity in sounds_to_remove:
        hit_sounds.erase(entity)

    queue_redraw()

func _physics_process(delta: float) -> void:
    ##### Command Processing #####
    var command: Command = commands.pop_back()
    while command:
        match command.type:
            ##### Movement Commands #####
            CommandType.Move_Left:
                if location_index == 0:
                    location_index = len(locations) - 1
                else:
                    location_index -= 1
            CommandType.Move_Right:
                if len(locations) - location_index - 1 > 0:
                    location_index += 1
                else:
                    location_index = 0
            ##### Droplet Commands #####
            CommandType.Droplet_New:
                var stream: WaterStream = %water_stream.duplicate()
                var droplet: Droplet = Droplet.new(%droplets, stream, droplet_frames, god_mode)
                droplet.droplet_sprite.global_position = %player_hose/hose_emit.global_position
                droplet.droplet_sprite.animation = "drop"
                droplet.droplet_sprite.reset_physics_interpolation()

                get_tree().get_root().add_child(stream)
                drops.append(droplet)
            CommandType.Droplet_Finish:
                var droplet: Droplet = command.args[0]
                droplet.droplet_sprite.queue_free()
                droplet.stream_source.queue_free()

                # Unified collision check - works for both wash and battle
                for the_grime: Entity in grime:
                    if _death_pending:
                        break
                    if the_grime.hp > 0.0 and get_sprite_rect(the_grime.sprite).has_point(
                        the_grime.sprite.to_local(droplet.droplet_sprite.global_position)):
                        var death_command: Command
                        if scene_current == Scene.Wash:
                            death_command = Command.new(CommandType.Grime_Dead, [the_grime])
                        elif scene_current == Scene.Battle:
                            death_command = Command.new(CommandType.Battle_End, [the_grime])

                        the_grime.hp -= droplet.damage_deals
                        print(the_grime.hp)
                        the_grime.sprite.material.set_shader_parameter("hit_effect", 0.5)

                        # Only create/restart sound if entity wasn't already being hit
                        var was_already_being_hit: bool = hit_effect_timers.has(the_grime)

                        hit_effect_timers[the_grime] = 0.2

                        if not was_already_being_hit:
                            # Entity wasn't flashing - create new sound
                            if the_grime.grime_type == Entity.GrimeType.Enemy:
                                hit_sounds[the_grime] = Audio.create_2d_sfx_at_location(droplet.droplet_sprite.global_position, Audio.SoundEffectType.Wash_Monster)
                            elif the_grime.grime_type == Entity.GrimeType.None:
                                hit_sounds[the_grime] = Audio.create_2d_sfx_at_location(droplet.droplet_sprite.global_position, Audio.SoundEffectType.Wash_Dirt)
                        # else: entity was already flashing, keep existing sound playing

                        if the_grime.hp <= 0.0:
                            _death_pending = true
                            commands.append(death_command)

            ##### Grime and Battle Commands #####
            CommandType.Grime_Dead:
                var the_grime: Entity = command.args[0]
                if the_grime.grime_type == Entity.GrimeType.Enemy:
                    the_grime.sprite.material.set_shader_parameter("hit_effect", 0.5)
                    commands.append(Command.new(CommandType.Battle_Start, [the_grime]))
                    thing_battling = the_grime
                elif the_grime.grime_type == Entity.GrimeType.None:
                    _death_pending = false
                    Audio.create_2d_sfx_at_location(the_grime.global_position, Audio.SoundEffectType.Cleaned_Dirt) # all good
                    the_grime.visible = false
                    var particler: CPUParticles2D = %CPUParticles2D.duplicate()
                    particler.global_position = the_grime.global_position
                    particler.finished.connect(func() -> void: particler.queue_free())
                    add_child(particler)
                    particler.emitting = true
            CommandType.Battle_Start:
                battle = BattleSession.new()
                battle.timer_tween = get_tree().create_tween()
                battle.timer_tween.tween_property(%timer, "position:y", -20.0 - timer_hide_distance, timer_hide_duration)
                var what_fighting: Entity = command.args[0]
                %battle_enemy.hp = 3.5 * what_fighting.base_hp

                var enemy_key: String = Entity.EnemyType.keys()[what_fighting.enemy_type]
                %battle_enemy/sprite.animation = enemy_key
                var transition_color: Color = enemy_config_data[enemy_key].transition_color
                for child: CanvasItem in %battlebackground.get_children():
                    if child is Control:
                        if child.name in enemy_config_data[enemy_key].background_layers:
                            child.visible = true
                        else:
                            child.visible = false

                transition_color.a = 0.5
                %transition_battle.visible = true
                %transition_battle.material.set_shader_parameter("transition_color", transition_color)
                %transition_battle.play(["circle", "horizontal", "split"].pick_random())
                %transition_battle.animation_finished.connect(_battle_transition_in_anim_finished, CONNECT_ONE_SHOT)
            CommandType.Battle_End:
                battle.phase = BattlePhase.TransitionOut
                #%battle_cursor.visible = false
                #%ui_anim.stop()
                #%battle_patterns.position = Vector2(158, 200)
                #if _enemy_move_tween and _enemy_move_tween.is_running():
                    #_enemy_move_tween.kill()
                %transition_battle.visible = true
                var tween: Tween = get_tree().create_tween()
                tween.tween_method(
                    func(value: Color) -> void:
                        %transition_battle.material.set_shader_parameter("transition_color", value)
                , Color(%transition_battle.material.get_shader_parameter("transition_color")), Color.BLACK, 0.5)
                tween.tween_callback(
                    func() -> void:
                        %battle_enemy.global_position = Vector2(320.0/2.0, 180.0/2.0)
                        %battle_enemy.sprite.material.set_shader_parameter("hit_effect", 0.0)
                        %transition_battle.frame = 0
                        var callback_command: Command = Command.new(CommandType.Debug_Submit)
                        callback_command.args = ["go wash"]
                        commands.append(callback_command)
                        # Restore grime array to current car location
                        #grime.clear()
                        #for child: Node in car_current.get_child(location_index).get_children():
                            #if child is Entity:
                                #grime.append(child)
                                )
                tween.tween_method(
                    func(value: float) -> void:
                        %transition_battle.material.set_shader_parameter("transition_color", Color(0.0,0.0,0.0,value))
                , 1.0, 0.0, 0.5)
                var captured_clock_delta: float = battle.clock_delta
                tween.tween_callback(
                    func() -> void:
                        thing_battling.grime_type = Entity.GrimeType.None
                        commands.append(Command.new(CommandType.Grime_Dead, [thing_battling]))
                        _reset_battle_state()
                        var timer_tween: Tween = get_tree().create_tween()
                        timer_tween.tween_property(%timer, "position:y", -20.0, timer_hide_duration)
                        timer_tween.tween_callback(_animate_clock_delta.bind(captured_clock_delta))
                        pass)
            ##### Debug Commands #####
            CommandType.Debug_Submit:
                var debug_command: String = command.args[0]
                var cut: Util.Cut = Util.cut(debug_command, " ")
                match [cut.head, cut.tail]:
                    ["title", ..]:
                        %title_screen_anim.play("begin")
                        await %title_screen_anim.animation_finished
                        breakpoint
                    ["bus", ..]:
                        Audio.reload_audio_buses()
                    ["die", ..]:
                        game_clock = 0.0
                    ["god", ..]:
                        god_mode = !god_mode
                    ["c", ..]:
                        spawn_cars()
                    ["kill", ..]:
                        for face: Node in car_current.get_children():
                            if face is not Sprite2D:
                                continue
                            for child: Node in face.get_children():
                                if child is Entity and child.visible and child.hp > 0.0:
                                    child.hp = 0.0
                                    child.visible = false
                    ["killbutone", ..]:
                        var found_one := false
                        for face: Node in car_current.get_children():
                            if face is not Sprite2D:
                                continue
                            for child: Node in face.get_children():
                                if child is Entity and child.visible and child.hp > 0.0:
                                    if not found_one:
                                        found_one = true
                                        continue
                                    child.hp = 0.0
                                    child.visible = false
                    ["go", "title"]:
                        scene_current = Scene.Title
                    ["go", "wash"]:
                        Audio.stop_all_music()
                        Audio.create_music(Audio.MusicType.Wash)
                        #_reset_battle_state()
                        scene_current = Scene.Wash
                    ["go", "battle"]:
                        Audio.stop_all_music()
                        Audio.create_music(Audio.MusicType.Battle)
                        scene_current = Scene.Battle
                    ["do", "player"]:
                        if scene_current == Scene.Battle:
                            _battle_start_player_enter()
                    ["go", "transition"]:
                        commands.append(Command.new(CommandType.Battle_Start))
                    _:
                        push_warning("%s not found" % debug_command)
                %debug_edit.text = ""
        command = commands.pop_back()

    match day_current:
        1:
            car_current.visible = false
            car_current = car0
            car_current.visible = true
        2:
            car_current.visible = false
            car_current = car1
            car_current.visible = true
        3:
            car_current.visible = false
            car_current = car2
            car_current.visible = true
        _:
            assert(false)

##### Scene and Rendering Updates #####
    %scene_battle.visible = false
    %scene_carwash.visible = false
    %scene_title.visible = false
    %scene_gameend.visible = false
    %recticle.visible = false
    if game_clock > 0.0:
        game_clock -= delta
        _update_timer_display()
    match scene_current:
        Scene.Title:
            %scene_title.visible = true
        Scene.Wash:
            %player_hose.visible = true
            %recticle.visible = true
            %droplets.visible = true

            %scene_carwash.visible = true
            grime.clear()
            for child in car_current.get_child(location_index).get_children():
                if child is Entity:
                    grime.append(child)
            if not _day_transitioning and not battle and _is_car_clean(car_current):
                _advance_day()
        Scene.Battle:
            $scene_battle.visible  = true
            if battle:
                match battle.phase:
                    BattlePhase.PlayerTurn:
                        %player_hose.visible = true
                        %recticle.visible = true
                        %droplets.visible = true
                        battle.turn_timer -= delta
                        battle.path_progress += 0.007
                        if battle.path_progress >= 1.0:
                            battle.path_progress = 0.0
                        var curve: Curve2D = %enemy_path.curve
                        %battle_enemy.global_position = curve.sample_baked(battle.path_progress * curve.get_baked_length())
                        if battle.turn_timer <= 0.0:
                            _battle_start_enemy_enter()
                    BattlePhase.EnemyTurn:
                        Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
                        %player_hose.visible = false
                        %droplets.visible = false
                        %battle_cursor.global_position = get_global_mouse_position()
                        %battle_cursor.global_position.x -= 2
                        var cursor_rect: Rect2 = %battle_cursor.get_global_rect()
                        var battle_box_rect: Rect2 = %battle_patterns.get_global_rect()
                        var result: Rect2 = Util.clamp_rect(cursor_rect, battle_box_rect)
                        %battle_cursor.global_position = result.position

                        if battle.invuln_timer > 0.0:
                            battle.invuln_timer -= delta
                            %battle_cursor.modulate.a = 0.3 if fmod(battle.invuln_timer, 0.15) < 0.075 else 0.7
                        else:
                            %battle_cursor.modulate.a = 1.0
                            match %battle_patterns.point_collide_projectile(get_global_mouse_position()):
                                EnemyPatterns.HitType.Bad:
                                    battle.clock_delta -= 5.0
                                    battle.invuln_timer = 0.5
                                    if game_clock_histories[Util.name_from_enemy_enum(thing_battling.enemy_type)] > battle.clock_delta:
                                        game_clock_histories[Util.name_from_enemy_enum(thing_battling.enemy_type)] = battle.clock_delta
                                    _spawn_hit_vfx(%battle_patterns.last_bad_hit_position, false)
                                EnemyPatterns.HitType.Good:
                                    battle.clock_delta += 5.0
                                    var particler: CPUParticles2D = %particles_good.duplicate()
                                    particler.global_position = %battle_patterns.last_good_hit_position
                                    particler.finished.connect(func() -> void: particler.queue_free())
                                    add_child(particler)
                                    particler.emitting = true
                                    _spawn_hit_vfx(%battle_patterns.last_good_hit_position, true)

                        battle.turn_timer -= delta
                        if battle.turn_timer <= 0.0:
                            _battle_start_player_enter()
                            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                    _:
                        # During transitions/enter phases, don't update battle-specific visuals
                        %player_hose.visible = false
                        %droplets.visible = false
        Scene.GameEnd:
            %scene_gameend.visible = true
            %ending_playername.text = username
            var death_cause := "None"
            var min_key := "None"
            var min_value := 0.0
            for key: String in game_clock_histories.keys():
                if game_clock_histories[key] < min_value:
                    min_value = game_clock_histories[key]
                    min_key = key
            death_cause = min_key
            if scene_die == Scene.Battle:
                death_cause = Entity.EnemyType.keys()[thing_battling.enemy_type]
            for child: Control in find_children("EndingBad*"):
                child.visible = false
            find_child("EndingBad%s" % death_cause).visible = true
            %EndingWinBlank.visible = not game_clock <= 0.0
    ##### Car and Background Updates #####
    var car_sprite_index: int = 0
    for car_sprite: Node2D in car_current.get_children():
        if car_sprite is Sprite2D:
            if car_sprite_index == location_index:
                car_sprite.visible = true
                %background_carwash.get_child(car_sprite_index).visible = true
            else:
                car_sprite.visible = false
                %background_carwash.get_child(car_sprite_index).visible = false
        car_sprite_index += 1

    %background_pink.material.set_shader_parameter("tex_offset", pink_offset)
    %background_yellow.material.set_shader_parameter("tex_offset", yellow_offset)

    var mouse_pos: Vector2 = get_global_mouse_position()
    mouse_pos.y = maxf(mouse_pos.y, max_player_height)
    $player_hose.global_position = mouse_pos
    %water_stream.global_position = %player_hose/hose_emit.global_position

    ##### Droplet Animation #####
    for droplet: Droplet in drops:
        var progress_left: float = 1.0 - droplet.stream_progress
        if progress_left >= 0.05:
            droplet.stream_progress += 0.05
        else:
            droplet.stream_progress = 1.0
        var result := droplet.stream_source.get_droplet_per_normalized_progress(droplet.stream_progress)
        droplet.droplet_sprite.global_position = droplet.stream_source.global_position + result.position
        match result.segment:
            0:
                droplet.droplet_sprite.frame = [3, 4, 8].pick_random()
            1:
                droplet.droplet_sprite.frame = [7, 5, 0].pick_random()
                droplet.droplet_sprite.scale = Vector2(0.7, 0.7)
            2:
                droplet.droplet_sprite.frame = [1, 2, 6].pick_random()
                droplet.droplet_sprite.scale = Vector2(0.4, 0.4)
        if droplet.stream_progress >= 1.0:
            var droplet_finish: Command = Command.new(CommandType.Droplet_Finish)
            droplet_finish.args = [droplet]
            commands.append(droplet_finish)
    drops = drops.filter(func(d: Droplet) -> bool: return d.stream_progress < 1.0)
    if drops.is_empty():
        Audio.stop_sound(Audio.SoundEffectType.Water_Hose, 0.5)

    ##### Reticle Positioning #####
    %recticle.global_position = %water_stream.global_position + %water_stream.get_end_position()
    
    if scene_current == Scene.Wash or scene_current == Scene.Battle:
        if game_clock <= 0.0 and not game_clock_timeout_handled:
            %transition_battle.visible = true
            %transition_battle.animation = "horizontal"
            %transition_battle.frame = 17
            Audio.stop_all_music()
            var tween := get_tree().create_tween()
            tween.tween_method(
                func(value: Color) -> void:
                    %transition_battle.material.set_shader_parameter("transition_color", value)
            , Color.TRANSPARENT, Color.BLACK, 2)
            tween.tween_callback(
                func() -> void:
                    scene_die = scene_current
                    _reset_battle_state()
                    scene_current = Scene.GameEnd
                    pass)
            tween.tween_method(
                func(value: Color) -> void:
                    %transition_battle.material.set_shader_parameter("transition_color", value)
                    Audio.stop_all_music()
            , Color.BLACK, Color.TRANSPARENT, 0.5)
            game_clock_timeout_handled = true
    #print(mouse_speed)

func _draw() -> void:
    draw_rect(get_sprite_rect(%battle_enemy.sprite), Color.RED)
    draw_line(Vector2(0, max_player_height), Vector2(320, max_player_height), Color.YELLOW)
