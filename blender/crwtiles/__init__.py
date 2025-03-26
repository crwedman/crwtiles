import addon_utils

bl_info = {
    "name": "3D Tiles",
    "author": "Christopher R. Wedman",
    "description": "",
    "blender": (2, 93, 13),
    "version": (0, 0, 1),
    "location": "View3D > Edit Panel > 3D Tiles",
    "warning": "",
    "category": "Generic",
}

from . import auto_load
auto_load.init()

from .utils import registerLogger, unregisterLogger
#import bpy

def register():
    registerLogger()
    auto_load.register()

def unregister():
    auto_load.unregister()
    unregisterLogger()

