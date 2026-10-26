"""Exporta la piscina del proyecto Blender Cinemascope como escenario del juego.

Uso:
    blender -b <ruta>/piscina_entorno.blend -P tools/blender/exportar_piscina.py

La piscina original está pensada para Cycles: sus materiales son grafos de
nodos (juntas de baldosa en coordenadas de mundo, ruido, vidrio con
refracción) que no viajan a Godot. Aquí cada material se sustituye por su
color plano, sacado a mano de los renders del proyecto. El sombreado de verdad
lo pone Godot con el shader de tinta: el escenario solo aporta forma y color.

Se quitan cámaras y luces (la luz la pone el juego) y los textos se convierten
a malla para que el logo "sf" llegue.
"""
import bpy
import os

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SALIDA = os.path.join(RAIZ, 'stages', 'piscina')
os.makedirs(SALIDA, exist_ok=True)

# Material: (color sRGB, alfa). Alfa < 1 = transparente en el juego.
COLORES = {
    'Panel azul': ('2b4fc9', 1), 'Azul logo': ('2b4fc9', 1),
    'Panel blanco': ('e6eaee', 1), 'Blanco': ('f2f2f2', 1),
    'Pilar gresite blanco': ('dde3e6', 1), 'Hormigon pilares': ('596069', 1),
    'Playa — baldosa gris': ('6b7079', 1), 'Borde — baldosa blanca': ('e4e9ec', 1),
    'Rejilla rebosadero': ('454a54', 1), 'Vaso — gresite turquesa': ('3aaec0', 1),
    'Vaso anexo — gresite claro': ('9ad6dc', 1), 'Agua piscina': ('4fbccb', .55),
    'Marcas de calle': ('1e2a63', 1), 'Corchera azul': ('2442b8', 1), 'Corchera roja': ('c8323a', 1),
    'Techo — panel acustico': ('737d8c', 1), 'Madera laminada': ('b07a45', 1),
    'Perforaciones vigas': ('3a2a20', 1), 'Acero inoxidable': ('c7ccd3', 1),
    'Aluminio carpinteria': ('9aa1a8', 1), 'Vidrio transparente': ('bfe3ea', .22),
    'Vidrio translucido iluminado': ('f1f4ee', 1), 'Vidrio oscuro puertas': ('1d2a33', 1),
    'Digitos reloj': ('ff4a3d', 1), 'Negro reloj': ('141414', 1), 'Salvavidas naranja': ('f07a2a', 1),
    'Gris taquillas': ('8a9099', 1), 'Cesped': ('4f8a3a', 1), 'Seto y copas': ('2f6b33', 1),
    'Tronco': ('6b4a2f', 1), 'Suelo gimnasio': ('8a6a4a', 1), 'Terraza exterior': ('b9b9b0', 1),
}


def lineal(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c]


for m in bpy.data.materials:
    hex_color, alfa = COLORES.get(m.name, ('ff00ff', 1))
    if m.name not in COLORES:
        print('SIN COLOR', m.name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    salida = nt.nodes.new('ShaderNodeOutputMaterial')
    p = nt.nodes.new('ShaderNodeBsdfPrincipled')
    p.inputs['Base Color'].default_value = (*lineal(hex_color), 1)
    p.inputs['Roughness'].default_value = .6
    p.inputs['Alpha'].default_value = alfa
    nt.links.new(p.outputs[0], salida.inputs['Surface'])
    m.diffuse_color = (*lineal(hex_color), alfa)
    if alfa < 1:
        m.surface_render_method = 'BLENDED'

for ob in list(bpy.data.objects):
    if ob.type in ('CAMERA', 'LIGHT'):
        bpy.data.objects.remove(ob)

bpy.ops.object.select_all(action='DESELECT')
textos = [ob for ob in bpy.data.objects if ob.type in ('FONT', 'CURVE')]
for ob in textos:
    ob.select_set(True)
if textos:
    bpy.context.view_layer.objects.active = textos[0]
    bpy.ops.object.convert(target='MESH')

glb = os.path.join(SALIDA, 'piscina.glb')
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_apply=True, export_yup=True,
                          export_lights=False, export_cameras=False)
print('EXPORTADO', glb)
