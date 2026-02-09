@tool
extends Node2D

enum SoundEffectType {
    Water_Hose,
    Car_Done,
    Cleaned_Dirt,
    Wash_Monster,
    Wash_Dirt,
    UI_Pause_Open,
    UI_Pause_Close,
    UI_Pause_Volume_Change,
    UI_Title_Screen,
    Battle_Transition,
    Battle_Hit_0,
    Battle_Hit_1,
    Battle_Take_Damage_0,
    Battle_Take_Damage_1,
    Battle_Power_Up,
    Cry_Durt,
    Cry_Gryme,
    Cry_Battlebottle,
    Cry_Ooze,
    Cry_Penny,
    Cry_Heads,
    Cry_Tailz,
    Cry_Receiptpete,
    Stinger_Victory,
    Stinger_Day_End,
    Stinger_Game_Over,
}

enum MusicType {
    Wash,
    Wash0,
    Battle,
    Battle1,
}

class PlayingSound:
    var node: AudioStreamPlayer
    var node2d: AudioStreamPlayer2D
    var sfx: SoundEffect
    var fade_out_timer: SceneTreeTimer
    var fade_out_duration := 0.0  # Total duration of fade
    var fade_out_start_volume := 0.0  # Volume when fade started
    
var _sound_effect_values: Dictionary[String, Resource] = {}
var _music_values: Dictionary[String, Resource] = {}

# @MightBeAProblem (Feb 3) this keys a Sound/Music Type to a node. 
# The obvious problem occurs when there's multiple of the same sound
# like a sound effect
# well, this is supposed to make stop() work anyway
# any you're probably stopping a single instance of music or looping sound anyway
var playing_sounds: Dictionary[String, PlayingSound] = {}

func _ready() -> void:
    if get_tree().current_scene == self:
        # This scene is being run directly (not as autoload)
        return
    if not Engine.is_editor_hint():
        $Control.visible = true
        %stop_all.pressed.connect(
            func() -> void:
                for child: Node in get_children():
                    if child is AudioStreamPlayer:
                        child.queue_free()
                add_music_buttons()
                pass)
        add_music_buttons()

func stop_all_music() -> void:
    var keys_erased: Array[String] = []
    for key: String in playing_sounds.keys():
        if key in MusicType.keys():
            playing_sounds[key].node.queue_free()
            keys_erased.append(key)
    for key: String in keys_erased:
        playing_sounds.erase(key)

func stop_sound(sound: SoundEffectType, fade_out_time := 0.0) -> void:
    var key: String = SoundEffectType.keys()[sound]
    if playing_sounds.has(key):
        var playing_sound: PlayingSound = playing_sounds[key]
        _stop_playing_sound(playing_sound, fade_out_time)

func stop_specific_sound(playing_sound: PlayingSound, fade_out_time := 0.0) -> void:
    if playing_sound and playing_sound in playing_sounds.values():
        _stop_playing_sound(playing_sound, fade_out_time)

func _stop_playing_sound(playing_sound: PlayingSound, fade_out_time: float) -> void:
    var regular_node_exists: bool = not playing_sound.fade_out_timer and playing_sound.node and not playing_sound.node.is_queued_for_deletion()
    var node_2d_exists: bool = not playing_sound.fade_out_timer and playing_sound.node2d and not playing_sound.node2d.is_queued_for_deletion()
    
    if not regular_node_exists and not node_2d_exists:
        return  # Already being cleaned up or doesn't exist
    
    playing_sound.fade_out_duration = fade_out_time
    
    if regular_node_exists:
        playing_sound.sfx.change_audio_count(-1)
        if fade_out_time > 0.0:
            # Store the current volume as the starting point for fade
            playing_sound.fade_out_start_volume = playing_sound.node.volume_db
            var timer: SceneTreeTimer = get_tree().create_timer(fade_out_time)
            playing_sound.fade_out_timer = timer
            timer.timeout.connect(
                func() -> void:
                    if playing_sound.node and not playing_sound.node.is_queued_for_deletion():
                        remove_child(playing_sound.node)
                        playing_sound.node.queue_free())
        else:
            remove_child(playing_sound.node)
            playing_sound.node.queue_free()
    
    if node_2d_exists:
        playing_sound.sfx.change_audio_count(-1)
        if fade_out_time > 0.0:
            # Store the current volume as the starting point for fade
            playing_sound.fade_out_start_volume = playing_sound.node2d.volume_db
            var timer: SceneTreeTimer = get_tree().create_timer(fade_out_time)
            playing_sound.fade_out_timer = timer
            timer.timeout.connect(
                func() -> void:
                    if playing_sound.node2d and not playing_sound.node2d.is_queued_for_deletion():
                        remove_child(playing_sound.node2d)
                        playing_sound.node2d.queue_free())
        else:
            remove_child(playing_sound.node2d)
            playing_sound.node2d.queue_free()

func stop_music(sound: MusicType) -> void:
    var key: String = MusicType.keys()[sound]
    var playing_music: PlayingSound = playing_sounds[key]
    playing_music.sfx.change_audio_count(-1)
    remove_child(playing_music.node)
    playing_music.node.queue_free()

func create_music(type: MusicType) -> void:
    var key: String = MusicType.keys()[type]
    if _music_values.has(key):
        var music: SoundEffect = _music_values[key]
        var new_music: AudioStreamPlayer = create_audio_node(music)
        playing_sounds[key] = PlayingSound.new()
        playing_sounds[key].node = new_music
        playing_sounds[key].sfx = music
        add_child(new_music)
        new_music.play()
    else:
        push_error("Audio failed to find music for type ", key)

## Creates a sound effect at a specific location if the limit has not been reached. Pass [param location] for the global position of the audio effect, and [param type] for the SoundEffect to be queued.
func create_2d_sfx_at_location(location: Vector2, type: SoundEffectType) -> PlayingSound:
    var key: String = SoundEffectType.keys()[type]
    if _sound_effect_values.has(key):
        var sound_effect: SoundEffect = _sound_effect_values[key]
        if sound_effect.has_open_limit():
            sound_effect.change_audio_count(1)
            var new_2D_audio: AudioStreamPlayer2D = create_audio_node(sound_effect, location)
            # Don't overwrite existing playing sound - create a new PlayingSound instance
            var new_playing_sound: PlayingSound = PlayingSound.new()
            new_playing_sound.node2d = new_2D_audio
            new_playing_sound.sfx = sound_effect
            add_child(new_2D_audio)
            new_2D_audio.play()
            # Only update the dictionary entry for tracking purposes if needed
            # but return the actual unique PlayingSound instance
            playing_sounds[key] = new_playing_sound
            return new_playing_sound
    else:
        push_error("Audio failed to find setting for type ", type)
    return null

## Creates a sound effect if the limit has not been reached. Pass [param type] for the SoundEffect to be queued.
func create_sfx(type: SoundEffectType) -> void:
    var key: String = SoundEffectType.keys()[type]
    if _sound_effect_values.has(key):
        var sound_effect: SoundEffect = _sound_effect_values[key]
        if sound_effect.has_open_limit():
            sound_effect.change_audio_count(1)
            var new_audio: AudioStreamPlayer = create_audio_node(sound_effect)
            playing_sounds[key] = PlayingSound.new()
            playing_sounds[key].node = new_audio
            playing_sounds[key].sfx = sound_effect
            add_child(new_audio)
            new_audio.play()
    else:
        push_error("Audio failed to find setting for type ", type)

func kill_debug() -> void:
    var node: Control = $Control
    remove_child($Control)
    node.queue_free()

func add_music_buttons() -> void:
    reload_resources_from_disk()
    reload_audio_buses()
    for child: Node in %container_sfx.get_children():
        %container_sfx.remove_child(child)
        child.queue_free()
    for child: Node in %container_music.get_children():
        %container_music.remove_child(child)
        child.queue_free()
    for key: String in _sound_effect_values:
        var button: Button = Button.new()
        button.text = key
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(
            func() -> void:
                var sfx: SoundEffect = _sound_effect_values[key]
                if sfx and sfx.sound_effect:
                    var audio: AudioStreamPlayer = create_audio_node(sfx)
                    add_child(audio)
                    audio.play()
                else:
                    push_warning("sfx or stream not found for %s" % key))
        %container_sfx.add_child(button)
    for key: String in _music_values:
        var button: Button = Button.new()
        button.text = key
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(
            func() -> void:
                var music: SoundEffect = _music_values[key]
                if music and music.sound_effect:
                    var audio: AudioStreamPlayer = create_audio_node(music)
                    add_child(audio)
                    audio.play()
                else:
                    push_warning("music or stream not found for %s" % key))
        %container_music.add_child(button)

func create_audio_node(sound: SoundEffect, where: Vector2 = Vector2.INF) -> Variant:
    var node: Variant = AudioStreamPlayer.new()
    if where != Vector2.INF:
        node = AudioStreamPlayer2D.new()
        node.global_position = where
    node.stream = sound.sound_effect
    node.volume_db = sound.volume
    node.bus = sound.bus
    node.pitch_scale = sound.pitch_scale
    node.pitch_scale += randf_range(-sound.pitch_randomness, sound.pitch_randomness)
    node.finished.connect(sound.on_audio_finished)
    node.finished.connect(node.queue_free) # might be a problem with music?
    return node

func reload_resources_from_disk() -> void:
    # Get the scene file path
    var scene_path: String = scene_file_path
    if scene_path.is_empty():
        push_warning("No scene file path found")
        return
    
    # Load fresh scene from disk
    var fresh_scene: PackedScene = load(scene_path)
    if not fresh_scene:
        push_warning("Failed to load scene from disk")
        return
    
    # Instantiate to get the fresh data
    var fresh_instance: Node = fresh_scene.instantiate()
    
    # Copy the dictionary values
    if fresh_instance.has_method("_get"):
        for key: String in SoundEffectType.keys():
            var value: Variant = fresh_instance.get("sound_effect_" + key)
            if value:
                _sound_effect_values[key] = value
        
        for key: String in MusicType.keys():
            var value: Variant = fresh_instance.get("music_" + key)
            if value:
                _music_values[key] = value
    
    fresh_instance.queue_free()

func reload_audio_buses() -> void:
    # Get the default audio bus layout path from project settings
    var bus_layout_path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres")
    
    # Reload the bus layout from disk
    var bus_layout: AudioBusLayout = load(bus_layout_path)
    if bus_layout:
        AudioServer.set_bus_layout(bus_layout)
        print("Audio buses reloaded from disk")
    else:
        push_warning("Failed to reload audio bus layout from: " + bus_layout_path)

func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []
    
    # Sound Effects group
    properties.append({
        "name": "Sound Effects",
        "type": TYPE_NIL,
        "usage": PROPERTY_USAGE_GROUP,
        "hint_string": "sound_effect_"
    })
    
    for key: String in SoundEffectType.keys():
        properties.append({
            "name": "sound_effect_" + key,
            "type": TYPE_OBJECT,
            "hint": PROPERTY_HINT_RESOURCE_TYPE,
            "hint_string": "SoundEffect",
            "usage": PROPERTY_USAGE_DEFAULT
        })
    
    # Music group
    properties.append({
        "name": "Music",
        "type": TYPE_NIL,
        "usage": PROPERTY_USAGE_GROUP,
        "hint_string": "music_"
    })
    
    for key: String in MusicType.keys():
        properties.append({
            "name": "music_" + key,
            "type": TYPE_OBJECT,
            "hint": PROPERTY_HINT_RESOURCE_TYPE,
            "hint_string": "SoundEffect",
            "usage": PROPERTY_USAGE_DEFAULT
        })
    
    return properties

func _process(_delta: float) -> void:
    # Process fade-outs for all playing sounds
    for sound: PlayingSound in playing_sounds.values():
        if sound.fade_out_timer and sound.fade_out_duration > 0.0:
            # Calculate how far through the fade we are (0 = start, 1 = end)
            var time_elapsed: float = sound.fade_out_duration - sound.fade_out_timer.time_left
            var fade_progress: float = clamp(time_elapsed / sound.fade_out_duration, 0.0, 1.0)
            
            # Fade from start volume to -80db (effectively silent)
            var target_volume: float = -80.0
            var current_volume: float = lerp(sound.fade_out_start_volume, target_volume, fade_progress)
            
            if sound.node and not sound.node.is_queued_for_deletion():
                sound.node.volume_db = current_volume
            if sound.node2d and not sound.node2d.is_queued_for_deletion():
                sound.node2d.volume_db = current_volume
        
func _get(property: StringName) -> Variant:
    var prop_str: String = property
    
    if prop_str.begins_with("sound_effect_"):
        var key: String = prop_str.replace("sound_effect_", "")
        return _sound_effect_values.get(key, null)
    
    if prop_str.begins_with("music_"):
        var key: String = prop_str.replace("music_", "")
        return _music_values.get(key, null)
    
    return null

func _set(property: StringName, value: Variant) -> bool:
    var prop_str: String = property
    
    if prop_str.begins_with("sound_effect_"):
        var key: String = prop_str.replace("sound_effect_", "")
        if SoundEffectType.keys().has(key):
            _sound_effect_values[key] = value as Resource
            return true
    
    if prop_str.begins_with("music_"):
        var key: String = prop_str.replace("music_", "")
        if MusicType.keys().has(key):
            _music_values[key] = value as Resource
            return true
    
    return false
