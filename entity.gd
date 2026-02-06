class_name Entity
extends CharacterBody2D

enum GrimeType {
    None,
    Enemy,
}

enum EnemyType {
    None,
    Battlebottle,
    Durt,
    Gryme,
    Heads,
    Ooze,
    Penny,
    Recieptpete,
    Tailz
}

# colorpicker access
# Color(0.729, 0.765, 0.604, 1.0)
@export var area_clickable: Array[Area2D]
@export_node_path("Sprite2D", "AnimatedSprite2D") var sprite_path: NodePath
@onready var sprite: Variant = get_node(sprite_path) if not sprite_path.is_empty() else null
@export_group("Enemy")
@export_range(0.0, 30.0, 1.0) var base_hp := 20.0
@export var grime_type := GrimeType.None
@export var enemy_type := EnemyType.None

var pressed := false
var just_pressed := false
var mouse_hover := false
var mouse_just_hover := false
var scene_tree_timer: SceneTreeTimer = null
@onready var hp := base_hp

func _ready() -> void:
    if grime_type == GrimeType.Enemy:
        assert(enemy_type != EnemyType.None)
