@tool
extends EditorPlugin

var tile_atlas_inspector
var crwtiles_control

func _enter_tree():
	tile_atlas_inspector = preload("res://addons/crwtiles/tile_atlas_inspector.gd").new()
	crwtiles_control = preload("res://addons/crwtiles/crwtiles_control.tscn").instantiate()

	add_inspector_plugin(tile_atlas_inspector)
	add_control_to_bottom_panel(crwtiles_control, "WFC")


func _exit_tree():
	remove_inspector_plugin(tile_atlas_inspector)
	remove_control_from_bottom_panel(crwtiles_control)
	crwtiles_control.free()
