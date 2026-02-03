extends Node2D

var projectiles_coord_raw: Array[Vector2] = []
var battle_bubble_med_tex := preload("res://battle_bubble_med.tres")

var droplet_frames := preload("res://frames_droplet.tres")
var pink_offset := Vector2.ZERO
var yellow_offset := Vector2.ZERO

enum BattleState {
    Player,
    Enemy,
}

var battle_state_current := BattleState.Player

enum Scene {
    Wash,
    Battle,
}

var scene_current := Scene.Wash

enum CommandType {
    None,
    Debug_Submit,
    Move_Left,
    Move_Right,
    Move_Up,
    Move_Down,
    Droplet_New,
    Droplet_Finish,
    Battle_Start,
    Battle_End,
}

class Command:
    var type: CommandType
    var args: Array[Variant]
    
    func _init(ctype: CommandType) -> void:
        type = ctype

class Droplet:
    var stream_progress := 0.0 # value from 0 to 1
    var stream_source: WaterStream
    var droplet_sprite: AnimatedSprite2D
    
    func _init(droplets_parent: Node2D, stream: WaterStream, frames: SpriteFrames) -> void:
        droplet_sprite = AnimatedSprite2D.new()
        stream_source = stream
        droplet_sprite.sprite_frames = frames
        droplets_parent.add_child(droplet_sprite)

var commands: Array[Command] = []

var locations := ["front", "side_right", "back", "side_left",]
var location_index := 0
var path_progress := 0.0
var path_forward := false

var drops: Array[Droplet] = []
var grime: Array[Node2D] = []

func _ready() -> void:
    Audio.kill_debug()
    for area: Area2D in %ui_left.area_clickable:
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
        var command := Command.new(CommandType.Debug_Submit)
        command.args = [text]
        commands.append(command)
        pass)

func ui_anim_enemy_enter() -> void:
    var tween := get_tree().create_tween()
    tween\
        .tween_property(%enemy, "global_position", %enemy_place_while_battle.global_position, 0.5)\
        .set_trans(Tween.TRANS_QUAD)
    tween.tween_callback(
        func() -> void:
            commands.append(Command.new(CommandType.Battle_Start))
            pass)

func ui_anim_enemy_exit() -> void:
    var tween := get_tree().create_tween()
    @warning_ignore("integer_division")
    tween.tween_property(%enemy, "global_position", Vector2(320/2, 180/2), 0.5).set_trans(Tween.TRANS_QUAD)
    tween.tween_callback(
        func() -> void:
            commands.append(CommandType.Battle_End)
            pass)

func _process(_delta: float) -> void:
    var check_hose := true
    if %ui_left.just_pressed:
        commands.append(Command.new(CommandType.Move_Left))
        check_hose = false
    if %ui_right.just_pressed:
        commands.append(Command.new(CommandType.Move_Right))
        check_hose = false
    if check_hose and Input.is_action_pressed("input_action"):
        commands.append(Command.new(CommandType.Droplet_New))

    %ui_left.mouse_just_hover = false
    %ui_right.mouse_just_hover = false
    %ui_left.just_pressed = false
    %ui_right.just_pressed = false
    
    pink_offset += Vector2(-3 * -0.00005, 20 * -0.00005)
    yellow_offset += Vector2(17 * -0.00005, 74 * -0.00005)
    
func _physics_process(_delta: float) -> void:
    var command: Command = commands.pop_back()
    while command:
        match command.type:
            CommandType.Move_Left:
                if location_index == 0:
                    location_index = len(locations) - 1
                else:
                    location_index -= 1
                grime.clear()
                for child in %car.get_child(location_index).get_children():
                    if child is Sprite2D:
                        grime.append(child)
            CommandType.Move_Right:
                if len(locations) - location_index - 1 > 0:
                    location_index += 1
                else:
                    location_index = 0
                grime.clear()
                for child in %car.get_child(location_index).get_children():
                    if child is Sprite2D:
                        grime.append(child)
            CommandType.Droplet_New:
                var stream := %water_stream.duplicate()
                var droplet := Droplet.new(%droplets, stream, droplet_frames)
                droplet.droplet_sprite.global_position = %player_hose/hose_emit.global_position
                droplet.droplet_sprite.reset_physics_interpolation()
                droplet.droplet_sprite.animation = "drop"
                
                get_tree().get_root().add_child(stream)
                drops.append(droplet)
            CommandType.Droplet_Finish:
                var droplet: Droplet = command.args[0]
                droplet.droplet_sprite.queue_free()
                droplet.stream_source.queue_free()
                for the_grime: Sprite2D in grime:
                    if the_grime.get_rect().has_point(the_grime.to_local(droplet.droplet_sprite.global_position)):
                        the_grime.material.set_shader_parameter("hit_effect", 0.5)
                        var timer := get_tree().create_timer(0.5)
                        timer.connect("timeout", func() -> void: the_grime.material.set_shader_parameter("hit_effect", 0.0))
            CommandType.Battle_Start:
                battle_state_current = BattleState.Enemy
                var battle_rect: Rect2 = %ui_battle.get_global_rect()
                Input.warp_mouse(Util.game_to_window(self, Vector2(battle_rect.position + battle_rect.size * 0.5)))
                %battle_cursor.visible = true
                %emitter0.global_position = battle_rect.position
                %emitter1.global_position = battle_rect.position + Vector2(battle_rect.size.x, 0)
                %emitter2.global_position = battle_rect.position + battle_rect.size
                %emitter3.global_position = battle_rect.position + Vector2(0, battle_rect.size.y)
                %battle_emitter_timer.start()
                projectiles_coord_raw.append(%emitter0.global_position)
                projectiles_coord_raw.append(%emitter1.global_position)
                projectiles_coord_raw.append(%emitter2.global_position)
                projectiles_coord_raw.append(%emitter3.global_position)
                %battle_emitter_timer.timeout.connect(
                    func() -> void:
                        projectiles_coord_raw.append(%emitter0.global_position)
                        projectiles_coord_raw.append(%emitter1.global_position)
                        projectiles_coord_raw.append(%emitter2.global_position)
                        projectiles_coord_raw.append(%emitter3.global_position)
                        pass)
            CommandType.Battle_End:
                projectiles_coord_raw.clear()
            CommandType.Debug_Submit:
                var debug_command: String = %debug_edit.text
                var cut := Util.cut(debug_command, " ")
                match [cut.head, cut.tail]:
                    ["go", "wash"]:
                        $bgm_carwash.playing = true
                        $bgm_battle.playing = false
                        scene_current = Scene.Wash
                    ["go", "battle"]:
                        $bgm_carwash.playing = false
                        $bgm_battle.playing = true
                        scene_current = Scene.Battle
                    ["do", "battle"]:
                        if scene_current == Scene.Battle:
                            %ui_anim.play("battle_start")
                            #ui_anim_enemy_enter()
                    ["do", "player"]:
                        if scene_current == Scene.Battle:
                            battle_state_current = BattleState.Player
                            commands.append(Command.new(CommandType.Battle_End))
                            %ui_anim.play("battle_end")
                            #ui_anim_enemy_exit()
                    _:
                        push_warning("%s not found" % debug_command)
                %debug_edit.text = ""
        command = commands.pop_back()
    
    match scene_current:
        Scene.Wash:
            $scene_carwash.visible = true
            $scene_battle.visible = false
        Scene.Battle:
            $scene_battle.visible  = true
            $scene_carwash.visible = false
            
    for child in %projectiles.get_children():
        %projectiles.remove_child(child)
        child.queue_free()
    match battle_state_current:
        BattleState.Player:
            %player_hose.visible = true
            %droplets.visible = true
        BattleState.Enemy:
            %player_hose.visible = false
            %droplets.visible = false
            %battle_cursor.global_position = get_global_mouse_position()
            var cursor_rect: Rect2 = %battle_cursor.get_global_rect()
            var battle_box_rect: Rect2 = %ui_battle.get_global_rect()
            var result := Util.clamp_rect(cursor_rect, battle_box_rect)
            %battle_cursor.global_position = result.position

            for i in range(len(projectiles_coord_raw)):
                var sprite := Sprite2D.new()
                sprite.texture = battle_bubble_med_tex
                var coord := projectiles_coord_raw[i]
                var speed := 0.5
                if i % 4 == 0:
                    var ir := Vector2.DOWN.rotated(%emitter0/RayCast2D.rotation)
                    coord += ir * speed
                elif i % 4 == 1:
                    var ir := Vector2.DOWN.rotated(%emitter1/RayCast2D.rotation)
                    coord += ir * speed
                elif i % 4 == 2:
                    var ir := Vector2.DOWN.rotated(%emitter2/RayCast2D.rotation)
                    coord += ir * speed
                elif i % 4 == 3:
                    var ir := Vector2.DOWN.rotated(%emitter3/RayCast2D.rotation)
                    coord += ir * speed
                sprite.global_position = coord
                projectiles_coord_raw[i] = coord
                %projectiles.add_child(sprite)
    
    var car_sprite_index := 0
    for car_sprite: Sprite2D in %car.get_children():
        if car_sprite_index == location_index:
            car_sprite.visible = true
            %background_carwash.get_child(car_sprite_index).visible = true
        else:
            car_sprite.visible = false
            %background_carwash.get_child(car_sprite_index).visible = false
        car_sprite_index += 1
    
    %background_pink.material.set_shader_parameter("tex_offset", pink_offset)
    %background_yellow.material.set_shader_parameter("tex_offset", yellow_offset)
    
    if path_forward:
        if 1.0 - path_progress >= 0.01:
            path_progress += 0.01
            %PathFollow2D.progress_ratio = path_progress
            %fuzzy.global_position = %PathFollow2D.global_position
        else:
            path_forward = false
    else:
        if path_progress >= 0.01:
            path_progress -= 0.01
            %PathFollow2D.progress_ratio = path_progress
            %fuzzy.global_position = %PathFollow2D.global_position
        else:
            path_forward = true
    
    $player_hose.global_position = get_global_mouse_position()
    %water_stream.global_position = %player_hose/hose_emit.global_position
    
    for droplet: Droplet in drops:
        var progress_left := 1.0 - droplet.stream_progress
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
            var droplet_finish := Command.new(CommandType.Droplet_Finish)
            droplet_finish.args = [droplet]
            commands.append(droplet_finish)
    drops = drops.filter(func(d: Droplet) -> bool: return d.stream_progress < 1.0)
    
    %recticle.global_position = %water_stream.global_position + %water_stream.get_end_position()
