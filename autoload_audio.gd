@tool
extends Node2D

enum SoundEffectType {
    Water_Hose,
    Car_Done,
}

enum MusicType {
    Wash,
    Battle,   
}

var _sound_effect_values: Dictionary[String, Resource] = {}
var _music_values: Dictionary[String, Resource] = {}

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

func add_music_buttons() -> void:
    reload_resources_from_disk()
    for child: Node in %container_sfx.get_children():
        %container_sfx.remove_child(child)
        child.queue_free()
    for child: Node in %container_music.get_children():
        %container_music.remove_child(child)
        child.queue_free()
    for key: String in _sound_effect_values:
        var button := Button.new()
        button.text = key
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(
            func() -> void:
                var sfx: SoundEffect = _sound_effect_values[key]
                if sfx and sfx.sound_effect:
                    var audio := create_audio_node(sfx)
                    add_child(audio)
                    audio.play()
                else:
                    push_warning("sfx or stream not found for %s" % key))
        %container_sfx.add_child(button)
    for key: String in _music_values:
        var button := Button.new()
        button.text = key
        button.add_theme_font_size_override("font_size", 9)
        button.pressed.connect(
            func() -> void:
                var music: SoundEffect = _music_values[key]
                if music and music.sound_effect:
                    var audio := create_audio_node(music)
                    add_child(audio)
                    audio.play()
                else:
                    push_warning("music or stream not found for %s" % key))
        %container_music.add_child(button)

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

func kill_debug() -> void:
    var node := $Control
    remove_child($Control)
    node.queue_free()

func create_audio_node(sound: SoundEffect) -> AudioStreamPlayer:
    var node := AudioStreamPlayer.new()
    node.stream = sound.sound_effect
    node.volume_db = sound.volume
    node.pitch_scale = sound.pitch_scale
    node.pitch_scale += randf_range(-sound.pitch_randomness, sound.pitch_randomness)
    node.finished.connect(sound.on_audio_finished)
    node.finished.connect(node.queue_free) # might be a problem with music?
    return node

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
