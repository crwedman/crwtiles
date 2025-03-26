import bpy, idprop
import os
import json
from pathlib import Path
from copy import deepcopy
from enum import IntEnum

from ..utils import logger

class ExportTiles(bpy.types.Operator):
    """Export 3D tiles"""
    bl_idname = "crwtiles.export_tiles"
    bl_label = "Export Tiles"

    export_file: bpy.props.StringProperty(name="Export File", default="tile_library.glb")

    def execute(self, context):
        json_text: bpy.types.Text = context.scene.crwtiles.json_text
        output_collection: bpy.types.Collection = context.scene.crwtiles.output_collection

        export_dir = Path(bpy.path.abspath("//exports"))
        export_dir.mkdir(parents=True, exist_ok=True)

        # glTF 2.0 Export
        export_dir = export_dir / "crwtiles"
        export_dir.mkdir(exist_ok=True)

        # Export GLB for each object
        gltf_export_path = export_dir / self.export_file
        json_export_path = export_dir / (os.path.splitext(self.export_file)[0] + ".json")

        if bpy.context.active_object:
            bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.select_all(action='DESELECT')

        #for obj in context.scene.crwtiles.tile_collection.objects:
        #global tileset
        for obj in output_collection.all_objects:
            obj.select_set(True)

        bpy.ops.export_scene.gltf(
            filepath=str(gltf_export_path),
            export_format='GLB',  # Use 'GLTF_SEPARATE' for .gltf
            #use_active_collection=True,
            use_selection=True,
            #export_apply=True,
            export_extras=True,
        )

        json_file = open(json_export_path, "w")
        json_file.write(json_text.as_string())
        json_file.close()

        self.report({'INFO'}, f"Exported to {export_dir}")
        return {'FINISHED'}

