class_name Entity
extends CharacterBody2D

enum GrimeType {
    None,
    Enemy,
}

@export var area_clickable: Array[Area2D]
@export var sprite: Sprite2D
@export_group("Enemy")
@export_range(0.0, 30.0, 1.0) var base_hp := 20.0
@export var grime_type := GrimeType.None

var pressed := false
var just_pressed := false
var mouse_hover := false
var mouse_just_hover := false
var scene_tree_timer: SceneTreeTimer = null
@onready var hp := base_hp
