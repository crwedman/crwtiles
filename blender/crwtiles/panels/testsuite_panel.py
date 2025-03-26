import bpy

from crwtiles.operators.test_harness import TEST_OT_run_test_suite

class CRWTILES_PT_TestSuitePanel(bpy.types.Panel):
    """Test Suite"""
    bl_label = "Test Suite"
    bl_idname = "TILE_PT_testsuite_panel"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = '3D Tile'

    def draw(self, context):
        layout = self.layout
        layout.operator(TEST_OT_run_test_suite.bl_idname)
