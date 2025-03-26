@tool
extends Node3D

const WFC = CRWTILES_WFC.WFC

@export var tile_atlas: CRWTILES_TileAtlasResource

var solid_material = preload("res://addons/crwtiles/resources/solid_material.tres")
var empty_material = preload("res://addons/crwtiles/resources/empty_material.tres")
var uncollapsed_material = preload("res://addons/crwtiles/resources/uncollapsed_material.tres")

@onready var wfc_root = %WFCRoot

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
