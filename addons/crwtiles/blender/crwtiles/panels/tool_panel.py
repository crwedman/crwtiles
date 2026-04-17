import bpy
import json

from crwtiles.operators.generate_tiles_from_collection import GenerateTilesFromCollectionOperator
from crwtiles.operators.export_tiles import ExportTiles
from crwtiles.utils.orientation import Orientation

class OBJECT_PT_3DTilePanel(bpy.types.Panel):
    bl_label = "Tile Calculator"
    bl_idname = "OBJECT_PT_3DTilePanel"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "3D Tile"

    def draw(self, context):
        layout = self.layout


        props = layout.operator(GenerateTilesFromCollectionOperator.bl_idname)
        layout.prop(context.scene.crwtiles, "source_collection")
        layout.prop(context.scene.crwtiles, "output_collection")
        layout.prop(props, "cube_size")

        props = layout.operator(ExportTiles.bl_idname)
        layout.prop(props, "export_file")

        obj: bpy.types.Object = context.object

        if obj and obj.get("tile_id"):
            layout.separator()
            layout.label(text=obj.name)
            layout.label(text=f"{obj['tile_id']}")
            layout.label(text=f"{obj['hash']}")
            #layout.prop(obj.crwtiles.tile, "weight")
            row = layout.row(align=True)
            row.alignment = 'LEFT'
            row.label(text="Sockets")
            sockets = json.loads(obj["sockets"])
            for i, socket in enumerate(sockets):
                row = layout.row(align=True)
                #row.label(text=str(i))
                row.label(text=["-y","-x","+y","+x","+z","-z"][i])
                row.label(text=Orientation(socket["orientation"]).name)
                row.label(text=socket["edge_id"])
                row.label(text=socket["flipped_id"])

        else:
            layout.label(text="No tile selected")


def register():
    pass

def unregister():
    pass