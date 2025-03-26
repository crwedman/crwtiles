class_name CRWTILES_TileAtlasResource
extends Resource
const TileAtlasResource = CRWTILES_TileAtlasResource

const Tile = CRWTILES_Tile.Tile

@export_file("*.glb") var scene_file = "res://blender/exports/crwtiles/tile_library.glb"
#@export_file("*.json") var json_file = "res://blender/exports/crwtiles/tile_library.json"

@export var socket_index = {}
@export var tiles = []
@export var empty_tile: Tile
@export var solid_tile: Tile
@export var tile_grid = {}
@export var mesh_index = {}
