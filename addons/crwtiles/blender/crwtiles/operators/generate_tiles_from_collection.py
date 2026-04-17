import bpy
import bmesh
from mathutils import Vector, Matrix, Euler
from math import floor, ceil, radians
import json

from crwtiles.utils import logger
from crwtiles.utils.dicer import Dicer
from crwtiles.utils.socket_atlas import SocketAtlas


class GenerateTilesFromCollectionOperator(bpy.types.Operator):
    bl_idname = "crwtiles.generatetilesfromcollection"
    bl_label = "Generate Tiles"
    bl_options = {'REGISTER', 'UNDO'}

    cube_size: bpy.props.FloatVectorProperty(name="Cube Size", default=(2,2,2))

    def execute(self, context: bpy.types.Context):
        obj: bpy.types.Object
        dup: bpy.types.Object

        source_collection: bpy.types.Collection = context.scene.crwtiles.source_collection
        output_collection: bpy.types.Collection = context.scene.crwtiles.output_collection
        json_text: bpy.types.Text = context.scene.crwtiles.json_text

        if None == output_collection:
            output_collection = bpy.data.collections.new("CRWTiles")
            context.scene.collection.children.link(output_collection)
            context.scene.crwtiles.output_collection = output_collection
        else:
            for obj in output_collection.objects:
                bpy.data.objects.remove(obj)

        if None == context.scene.crwtiles.json_text:
            json_text =  bpy.data.texts.new("CRWTiles")
            context.scene.crwtiles.json_text = json_text

        atlas = SocketAtlas()
        dicer = Dicer(source_collection)
        dicer.execute(context)
        for tile in dicer.tiles.values():
            atlas.add_tile(tile)
        for tile in dicer.tiles.values():
            atlas.add_custom_properties(tile)

        for tile in dicer.tiles.values():
            output_collection.objects.link(tile)

        json_text.clear()
        json.dump(atlas.export(), json_text, indent=4)


        return {"FINISHED"}

