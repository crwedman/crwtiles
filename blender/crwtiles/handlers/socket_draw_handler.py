import bpy
import bgl
import gpu
from gpu_extras.batch import batch_for_shader

# Storage for the handler
draw_handler = None

def draw_colored_outline():
    # Iterate through all objects in the scene
    for obj in bpy.context.scene.objects:
        # Only apply to objects with a specific property
        obj: bpy.types.Object = bpy.types.Object(obj)
        if not obj.get("crwtiles_sockets"):
            continue
        #if not obj.name.startswith("socket_"):
        #    continue

        if obj.type == 'MESH':
            mesh = obj.data

            # Get vertices in world space
            vertices = [obj.matrix_world @ v.co for v in mesh.vertices]

            # Get edges
            edges = [(e.vertices[0], e.vertices[1]) for e in mesh.edges]

            # Create a shader for drawing the outline
            shader = gpu.shader.from_builtin('3D_UNIFORM_COLOR')

            # Create a batch for the edges
            batch = batch_for_shader(shader, 'LINES', {"pos": vertices}, indices=edges)

            # Set the outline color (RGBA)
            outline_color = (0.8, 0.0, 0.0, 0.8)

            # Enable blending for transparency
            bgl.glEnable(bgl.GL_BLEND)
            shader.bind()
            shader.uniform_float("color", outline_color)
            batch.draw(shader)
            bgl.glDisable(bgl.GL_BLEND)


def register_draw_handler():
    global draw_handler
    if draw_handler is None:
        draw_handler = bpy.types.SpaceView3D.draw_handler_add(
            draw_colored_outline,
            (),
            'WINDOW',
            'POST_VIEW'
        )


def unregister_draw_handler():
    global draw_handler
    if draw_handler is not None:
        bpy.types.SpaceView3D.draw_handler_remove(draw_handler, 'WINDOW')
        draw_handler = None


