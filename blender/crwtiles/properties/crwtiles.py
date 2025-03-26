import bpy

class SceneProperties(bpy.types.PropertyGroup):
    source_collection: bpy.props.PointerProperty(type=bpy.types.Collection, name="Input Collection")
    output_collection: bpy.props.PointerProperty(type=bpy.types.Collection, name="Output Collection")
    json_text: bpy.props.PointerProperty(type=bpy.types.Text, name="JSON Output")

def register():
    bpy.types.Scene.crwtiles = bpy.props.PointerProperty(type=SceneProperties)

def unregister():
    del bpy.types.Scene.crwtiles

