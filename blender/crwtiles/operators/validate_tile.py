import bpy
from ..utils.geometry_checks import validate_tile_boundaries


class TILE_OT_ValidateTile(bpy.types.Operator):
    """Validate selected tile geometry for boundary constraints."""
    bl_idname = "crwtiles.validate_tile"
    bl_label = "Validate Tile"
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        obj = context.object
        if not obj or obj.type != 'MESH':
            self.report({'ERROR'}, "Please select a valid mesh object")
            return {'CANCELLED'}

        if validate_tile_boundaries(obj):
            self.report({'INFO'}, "Tile geometry is valid!")
        else:
            self.report({'ERROR'}, "Tile failed validation.")

        return {'FINISHED'}
