"""Construye la Cristina Morales 3D del juego, con esqueleto y animaciones.

Uso (desde la raíz del proyecto):
    blender -b -P tools/blender/construir_cristina.py -- [ruta_previews]

Todo sale de este script: no hay un .blend a mano que se desincronice. El
modelo se ve en el juego a 640x360, con la cabeza de unos 16 píxeles, así que
lo que importa son los rasgos gordos y legibles (el lado rapado contra el pelo
negro, las cejas, los labios granates, el verde con rosas), no el detalle fino.

Ejes de Blender: X hacia delante (mira a la derecha en el juego), Y a su
izquierda, Z arriba. Su derecha (-Y) es el lado rapado y es el que ve la
cámara del juego cuando mira a la derecha.

Las poses se escriben como DIRECCIONES de cada hueso ("el antebrazo apunta
arriba y adelante"), no como ángulos de Euler: se leen y se corrigen a ojo.
Las animaciones van a 60 fps: un fotograma clave es un tick del combate.
"""
import bpy
import bmesh
import math
import os
import sys
import random
from mathutils import Vector, Matrix, Quaternion

RAIZ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SALIDA = os.path.join(RAIZ, 'characters', 'cristina_morales', 'modelo')
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
PREVIEWS = args[0] if args else None
os.makedirs(SALIDA, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
escena = bpy.context.scene
escena.render.fps = 60


# --- Materiales ----------------------------------------------------------------

def lineal(hex_srgb):
    c = [int(hex_srgb[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c) + (1.0,)


def material(nombre, hex_color, imagen=None, rugosidad=.7):
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = lineal(hex_color)
    p.inputs['Roughness'].default_value = rugosidad
    m.diffuse_color = lineal(hex_color)
    if imagen is not None:
        t = m.node_tree.nodes.new('ShaderNodeTexImage')
        t.image = imagen
        t.interpolation = 'Closest'
        m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
    return m


def textura_rosas():
    """Estampado del vestido: rosas rosas sobre verde, como en las fotos.
    Se pinta aquí con numpy y viaja dentro del .glb."""
    import numpy as np
    n = 128
    img = np.zeros((n, n, 4), dtype=np.float32)
    verde = np.array(lineal('2f6b55'))
    verde_osc = np.array(lineal('22503f'))
    hoja = np.array(lineal('1b3d2f'))
    rosa = np.array(lineal('e2708e'))
    rosa_osc = np.array(lineal('a8405f'))
    rosa_luz = np.array(lineal('f6a6bb'))
    img[:, :] = verde
    rnd = random.Random(1983)
    yy, xx = np.mgrid[0:n, 0:n]
    # Tramado suave del fondo para que el verde no sea plano.
    img[(xx + yy * 3) % 7 == 0] = verde_osc
    for _ in range(14):
        cx, cy, r = rnd.randrange(n), rnd.randrange(n), rnd.randint(6, 9)
        for dx in (-n, 0, n):
            for dy in (-n, 0, n):
                d = np.sqrt((xx - cx - dx) ** 2 + (yy - cy - dy) ** 2)
                # Hojas: dos óvalos oscuros pegados a la rosa.
                hx, hy = cx + dx + r, cy + dy + r // 2
                img[((xx - hx) ** 2 / 9 + (yy - hy) ** 2 / 3) < r] = hoja
                img[d < r] = rosa
                img[(d < r) & (d > r - 2)] = rosa_osc
                img[(d < r * .55) & (d > r * .3)] = rosa_osc
                img[(d < r * .3)] = rosa_luz
    imagen = bpy.data.images.new('rosas', n, n, alpha=False)
    imagen.pixels = img[::-1].ravel()
    imagen.filepath_raw = os.path.join(SALIDA, 'rosas.png')
    imagen.file_format = 'PNG'
    imagen.save()
    return imagen


PIEL = material('piel', 'e3b59c')
RAPADO = material('rapado', 'a88e86')
PELO = material('pelo', '1b1519', rugosidad=.4)
CEJAS = material('cejas', '140f12')
OJOS = material('ojos', '2b1b18')
LABIOS = material('labios', '7a2034', rugosidad=.35)
VESTIDO = material('vestido', '2f6b55', textura_rosas())
BOTAS = material('botas', '1d1a20', rugosidad=.25)
SUELA = material('suela', 'c8a04a')
PLATA = material('pendiente', 'd9dbe4', rugosidad=.2)


# --- Esqueleto -------------------------------------------------------------------

HUESOS = [
    # nombre, cabeza, cola, padre
    ('cadera', (0, 0, .88), (0, 0, 1.00), None),
    ('columna', (0, 0, 1.00), (0, 0, 1.18), 'cadera'),
    ('pecho', (0, 0, 1.18), (0, 0, 1.38), 'columna'),
    ('cuello', (0, 0, 1.38), (0, 0, 1.46), 'pecho'),
    ('cabeza', (0, 0, 1.46), (0, 0, 1.70), 'cuello'),
]
for lado, s in (('L', 1), ('R', -1)):
    HUESOS += [
        (f'hombro.{lado}', (0, s * .03, 1.34), (0, s * .17, 1.34), 'pecho'),
        (f'brazo.{lado}', (0, s * .17, 1.34), (0, s * .29, 1.11), f'hombro.{lado}'),
        (f'antebrazo.{lado}', (0, s * .29, 1.11), (0, s * .38, .90), f'brazo.{lado}'),
        (f'mano.{lado}', (0, s * .38, .90), (0, s * .41, .82), f'antebrazo.{lado}'),
        (f'muslo.{lado}', (0, s * .09, .88), (0, s * .10, .47), 'cadera'),
        (f'pierna.{lado}', (0, s * .10, .47), (0, s * .10, .09), f'muslo.{lado}'),
        (f'pie.{lado}', (0, s * .10, .09), (.13, s * .10, .03), f'pierna.{lado}'),
    ]
ORDEN = [h[0] for h in HUESOS]

arm_datos = bpy.data.armatures.new('esqueleto')
esqueleto = bpy.data.objects.new('cristina_esqueleto', arm_datos)
escena.collection.objects.link(esqueleto)
bpy.context.view_layer.objects.active = esqueleto
bpy.ops.object.mode_set(mode='EDIT')
for nombre, cab, cola, padre in HUESOS:
    eb = arm_datos.edit_bones.new(nombre)
    eb.head, eb.tail = Vector(cab), Vector(cola)
    eb.roll = 0
    if padre:
        eb.parent = arm_datos.edit_bones[padre]
        eb.use_connect = (Vector(cab) - arm_datos.edit_bones[padre].tail).length < 1e-4
bpy.ops.object.mode_set(mode='OBJECT')
SEGMENTOS = {n: (Vector(c), Vector(t)) for n, c, t, _ in HUESOS}


# --- Geometría ----------------------------------------------------------------------

piezas = []  # (objeto, hueso fijo o None para pesos por distancia)


def objeto(nombre, bm, mat, hueso=None, suave=True):
    me = bpy.data.meshes.new(nombre)
    bm.to_mesh(me)
    bm.free()
    if suave:
        me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    me.materials.append(mat)
    ob = bpy.data.objects.new(nombre, me)
    escena.collection.objects.link(ob)
    piezas.append((ob, hueso))
    return ob


def elipsoide(nombre, centro, radios, mat, hueso, segs=16, anillos=10, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=anillos, radius=1)
    m = Matrix.Diagonal((*radios, 1))
    if rot:
        m = rot.to_matrix().to_4x4() @ m
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro) @ m, verts=bm.verts)
    return objeto(nombre, bm, mat, hueso)


def caja(nombre, centro, medidas, mat, hueso, rot=None, biselar=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    if biselar:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=biselar, segments=2, affect='EDGES')
    m = Matrix.Diagonal((*medidas, 1))
    if rot:
        m = rot.to_matrix().to_4x4() @ m
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centro) @ m, verts=bm.verts)
    return objeto(nombre, bm, mat, hueso)


def tubo(nombre, perfil, mat, hueso=None, segs=16, uv_cilindro=False, cerrar_abajo=False):
    """Superficie de revolución por anillos (z, rx, ry, cx): vestido, mangas, cañas."""
    bm = bmesh.new()
    anillos = []
    for z, rx, ry, cx in perfil:
        anillos.append([bm.verts.new((cx + rx * math.cos(a), ry * math.sin(a), z))
                        for a in (2 * math.pi * i / segs for i in range(segs))])
    for a, b in zip(anillos, anillos[1:]):
        for i in range(segs):
            bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    if cerrar_abajo:
        bm.faces.new(list(reversed(anillos[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if uv_cilindro:
        capa = bm.loops.layers.uv.new()
        for f in bm.faces:
            us = [(math.atan2(l.vert.co.y, l.vert.co.x) / (2 * math.pi) + .5) * 3 for l in f.loops]
            # Arreglo de la costura: que una cara no salte de u=3 a u=0.
            if max(us) - min(us) > 1.5:
                us = [u + 3 if u < 1.5 else u for u in us]
            for l, u in zip(f.loops, us):
                l[capa].uv = (u, l.vert.co.z * 4)
    return objeto(nombre, bm, mat, hueso)


# Cuerpo: modificador Skin sobre un esqueleto de puntos, luego subdividido.
PUNTOS = [  # (posición, radio x, radio y)
    ((0, 0, .86), .115, .13),     # 0 pelvis
    ((0, 0, 1.02), .085, .10),    # 1 cintura
    ((0, 0, 1.22), .095, .125),   # 2 pecho
    ((0, 0, 1.38), .05, .05),     # 3 base del cuello
    ((0, 0, 1.47), .044, .044),   # 4 cuello
]
ARISTAS = [(0, 1), (1, 2), (2, 3), (3, 4)]
for s in (1, -1):
    i = len(PUNTOS)
    PUNTOS += [
        ((0, s * .17, 1.33), .058, .058),  # hombro
        ((0, s * .29, 1.11), .046, .046),  # codo
        ((0, s * .38, .90), .037, .037),   # muñeca
        ((0, s * .09, .82), .088, .088),   # cadera
        ((0, s * .10, .47), .058, .058),   # rodilla
        ((0, s * .10, .10), .044, .044),   # tobillo
    ]
    ARISTAS += [(2, i), (i, i + 1), (i + 1, i + 2), (0, i + 3), (i + 3, i + 4), (i + 4, i + 5)]

me = bpy.data.meshes.new('cuerpo')
me.from_pydata([p[0] for p in PUNTOS], ARISTAS, [])
cuerpo = bpy.data.objects.new('cuerpo', me)
escena.collection.objects.link(cuerpo)
piel_mod = cuerpo.modifiers.new('skin', 'SKIN')
piel_mod.branch_smoothing = .6
for i, (_, rx, ry) in enumerate(PUNTOS):
    me.skin_vertices[0].data[i].radius = (rx, ry)
me.skin_vertices[0].data[0].use_root = True
cuerpo.modifiers.new('sub', 'SUBSURF').levels = 2
bpy.context.view_layer.objects.active = cuerpo
cuerpo.select_set(True)
for m in list(cuerpo.modifiers):
    bpy.ops.object.modifier_apply(modifier=m.name)
cuerpo.data.polygons.foreach_set('use_smooth', [True] * len(cuerpo.data.polygons))
cuerpo.data.materials.append(PIEL)
piezas.append((cuerpo, None))

# Vestido: cuerpo ajustado y falda corta con vuelo, con el estampado de rosas.
tubo('vestido_cuerpo', [
    (.97, .104, .12, 0), (1.04, .1, .116, 0), (1.14, .11, .13, 0),
    (1.24, .12, .146, 0), (1.31, .11, .158, 0), (1.36, .08, .15, 0),
], VESTIDO, uv_cilindro=True)
tubo('vestido_falda', [
    (1.0, .1, .118, .005), (.92, .14, .16, .01), (.80, .185, .205, .02), (.66, .225, .245, .03),
], VESTIDO, hueso='cadera', uv_cilindro=True)
for s in (1, -1):
    # Manga corta: un tubo corto alrededor del arranque del brazo.
    tubo(f'manga.{s}', [(0, .056, .056, 0), (-.09, .05, .05, 0)], VESTIDO, hueso=None, uv_cilindro=True)
    manga = piezas[-1][0]
    a, b = Vector((0, s * .17, 1.33)), Vector((0, s * .29, 1.11))
    eje = (b - a).normalized()
    rot = Vector((0, 0, -1)).rotation_difference(eje)
    manga.data.transform(Matrix.Translation(a + eje * .01) @ rot.to_matrix().to_4x4())

# Puños (manos cerradas) y botas militares con suela de color.
for s, lado in ((1, 'L'), (-1, 'R')):
    elipsoide(f'puno.{lado}', (0, s * .392, .865), (.05, .044, .054), PIEL, f'mano.{lado}')
    tubo(f'cana.{lado}', [(.07, .05, .046, 0), (.27, .046, .044, 0)], BOTAS, hueso=f'pierna.{lado}')
    caja(f'bota.{lado}', (.045, s * .10, .055), (.19, .095, .11), BOTAS, f'pie.{lado}', biselar=.025)
    caja(f'suela.{lado}', (.045, s * .10, .006), (.20, .10, .022), SUELA, f'pie.{lado}', biselar=.006)

# Cabeza: un huevo un poco grande (caricatura de prensa) con mandíbula marcada.
CAB = Vector((0, 0, 1.585))
craneo = elipsoide('craneo', CAB, (.102, .094, .118), PIEL, 'cabeza', segs=24, anillos=16)
# El cuero cabelludo (todo lo que queda por encima de la frente y detrás de la
# oreja) va en gris de rapado; lo que tape la melena no se verá.
craneo.data.materials.append(RAPADO)
for pol in craneo.data.polygons:
    c = pol.center
    if c.z > CAB.z + .035 or (c.x < -.02 and c.z > CAB.z - .03):
        pol.material_index = 1
# Mandíbula marcada: se esculpe en el propio cráneo (adelantar y estrechar la
# parte de abajo) en vez de pegarle otra pieza, que quedaba como un hocico.
for v in craneo.data.vertices:
    bajo = max(0.0, (CAB.z - .02) - v.co.z) / .1
    v.co.x += .03 * bajo
    v.co.y *= 1 - .22 * bajo
elipsoide('nariz', CAB + Vector((.098, 0, -.016)), (.016, .011, .022), PIEL, 'cabeza', segs=8, anillos=6)
for s in (1, -1):
    ojo = CAB + Vector((.086, s * .04, .006))
    elipsoide(f'ojo.{s}', ojo, (.006, .012, .009), OJOS, 'cabeza', segs=8, anillos=6)
    # Cejas gruesas y bajando hacia el centro: el gesto serio de las fotos.
    caja(f'ceja.{s}', ojo + Vector((.006, 0, .022)), (.012, .036, .011), CEJAS, 'cabeza',
         rot=Quaternion((1, 0, 0), math.radians(-14 * s)))
    elipsoide(f'oreja.{s}', CAB + Vector((-.005, s * .095, -.005)), (.018, .012, .028), PIEL, 'cabeza', 8, 6)
    elipsoide(f'pendiente.{s}', CAB + Vector((-.002, s * .1, -.04)), (.006, .006, .008), PLATA, 'cabeza', 6, 4)
elipsoide('labios', CAB + Vector((.093, 0, -.072)), (.013, .03, .01), LABIOS, 'cabeza', 10, 6)

# Pelo: el lado derecho (-Y) va rapado y se ve el cráneo en gris; el resto es
# una melena negra peinada hacia atrás que cae por la espalda.
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=1)
bmesh.ops.transform(bm, matrix=Matrix.Translation(CAB + Vector((-.006, .004, .006))) @ Matrix.Diagonal((.108, .1, .124, 1)), verts=bm.verts)
fuera = [v for v in bm.verts if v.co.y < .005                          # lado rapado, entero
         or v.co.x > .055 and v.co.z < CAB.z + .085                         # frente y cara
         or v.co.z < CAB.z - .05 and v.co.x > -.07]                         # cuello y mandíbula
bmesh.ops.delete(bm, geom=fuera, context='VERTS')
bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=.008)
objeto('pelo_cabeza', bm, PELO, 'cabeza')

# Melena: tiras de sección plana que bajan desde la nuca, más larga por la izquierda.
bm = bmesh.new()
cortes = []
camino = [((-.07, .05, 1.66), .10), ((-.11, .05, 1.56), .15), ((-.13, .05, 1.44), .17),
          ((-.135, .055, 1.32), .16), ((-.125, .06, 1.20), .13), ((-.11, .065, 1.10), .07)]
for (x, y, z), ancho in camino:
    cortes.append([bm.verts.new((x + dx, y + dy, z)) for dx, dy in
                   ((-.03, -ancho / 2), (-.03, ancho / 2), (.025, ancho / 2), (.025, -ancho / 2))])
for a, b in zip(cortes, cortes[1:]):
    for i in range(4):
        bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
bm.faces.new(cortes[-1])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
melena = objeto('melena', bm, PELO, None)
melena.modifiers.new('sub', 'SUBSURF').levels = 1


# --- Unir y pesar ----------------------------------------------------------------------

def distancia_segmento(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


DEFORMAN = [n for n in ORDEN if not n.startswith('hombro')] + ['hombro.L', 'hombro.R']

for ob, _ in piezas:
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    for n in ORDEN:
        ob.vertex_groups.new(name=n)

for ob, hueso in piezas:
    grupos = {g.name: g for g in ob.vertex_groups}
    for v in ob.data.vertices:
        if hueso:
            grupos[hueso].add([v.index], 1.0, 'REPLACE')
            continue
        p = v.co
        candidatos = []
        for n in DEFORMAN:
            a, b = SEGMENTOS[n]
            d = distancia_segmento(p, a, b)
            # La melena solo sigue a cabeza, cuello y pecho.
            if ob.name == 'melena' and n not in ('cabeza', 'cuello', 'pecho'):
                continue
            # Brazos y piernas no se roban vértices entre lados.
            if (n.endswith('.L') and p.y < -.02) or (n.endswith('.R') and p.y > .02):
                continue
            candidatos.append((d, n))
        candidatos.sort()
        (d0, n0), (d1, n1) = candidatos[0], candidatos[1]
        w0, w1 = 1 / max(d0, 1e-4) ** 4, 1 / max(d1, 1e-4) ** 4
        grupos[n0].add([v.index], w0 / (w0 + w1), 'REPLACE')
        grupos[n1].add([v.index], w1 / (w0 + w1), 'REPLACE')

bpy.ops.object.select_all(action='DESELECT')
for ob, _ in piezas:
    ob.select_set(True)
bpy.context.view_layer.objects.active = cuerpo
bpy.ops.object.join()
cuerpo.name = 'cristina'
cuerpo.parent = esqueleto
mod = cuerpo.modifiers.new('esqueleto', 'ARMATURE')
mod.object = esqueleto


# --- Poses y animaciones -------------------------------------------------------------

def poner_pose(direcciones, bajar_cadera=0.0, adelante=0.0, al_suelo=True):
    """Coloca cada hueso apuntando a su dirección (en el espacio del modelo).
    Con al_suelo, sube o baja la cadera para que el pie más bajo pise."""
    for pb in esqueleto.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    bpy.context.view_layer.update()
    cadera = esqueleto.pose.bones['cadera']
    for n in ORDEN:
        if n not in direcciones and n != 'cadera':
            continue
        pb = esqueleto.pose.bones[n]
        bpy.context.view_layer.update()
        m = pb.matrix.copy()
        actual = (m.to_3x3() @ Vector((0, 1, 0))).normalized()
        if n in direcciones:
            q = actual.rotation_difference(Vector(direcciones[n]).normalized())
            nueva = q.to_matrix().to_4x4() @ m.to_3x3().to_4x4()
        else:
            nueva = m.to_3x3().to_4x4()
        nueva.translation = m.translation
        if n == 'cadera':
            nueva.translation = pb.bone.head_local + Vector((adelante, 0, -bajar_cadera))
        pb.matrix = nueva
    bpy.context.view_layer.update()
    if al_suelo:
        z_min = min(min(esqueleto.pose.bones[f'pie.{l}'].head.z, esqueleto.pose.bones[f'pie.{l}'].tail.z)
                    for l in 'LR')
        m = cadera.matrix.copy()
        m.translation.z += .03 - z_min
        cadera.matrix = m
        bpy.context.view_layer.update()


def clave(accion, fotograma):
    for pb in esqueleto.pose.bones:
        pb.keyframe_insert('rotation_quaternion', frame=fotograma, group=pb.name)
        pb.keyframe_insert('location', frame=fotograma, group=pb.name)


GUARDIA = {
    'cadera': (0, 0, 1), 'columna': (.10, 0, 1), 'pecho': (.16, -.04, 1), 'cuello': (.14, 0, 1),
    'cabeza': (.04, 0, 1),
    # Brazo adelantado (izquierdo, el lejano): codo abajo, puño a la altura de la cara.
    'brazo.L': (.42, .1, -.8), 'antebrazo.L': (.5, -.18, .85), 'mano.L': (.5, -.2, .84),
    # Brazo de atrás (derecho, el cercano): puño junto a la barbilla.
    'brazo.R': (.18, -.08, -.95), 'antebrazo.R': (.42, .28, .86), 'mano.R': (.4, .3, .86),
    # Piernas: la izquierda delante, rodillas flexionadas.
    'muslo.L': (.42, .02, -.9), 'pierna.L': (-.08, 0, -1), 'pie.L': (1, 0, -.15),
    'muslo.R': (-.18, -.02, -.98), 'pierna.R': (-.36, 0, -.93), 'pie.R': (1, 0, -.2),
}


def variar(base, **cambios):
    d = dict(base)
    for k, v in cambios.items():
        d[k.replace('_', '.')] = v
    return d


def accion(nombre, poses, bucle):
    """poses: [(fotograma, direcciones, bajar_cadera, adelante)]"""
    esqueleto.animation_data_create()
    a = bpy.data.actions.new(nombre)
    a.use_fake_user = True
    esqueleto.animation_data.action = a
    for f, dirs, bajar, adelante in poses:
        poner_pose(dirs, bajar, adelante)
        clave(a, f)
    a.frame_range = (poses[0][0], poses[-1][0])
    a.use_cyclic = bucle
    return a


# Guardia: respiración y un leve vaivén, en bucle de 48 ticks.
respira = variar(GUARDIA, pecho=(.18, -.04, 1), antebrazo_L=(.48, -.18, .86))
accion('guardia', [(0, GUARDIA, .07, 0), (24, respira, .085, 0), (48, GUARDIA, .07, 0)], True)

# Andar (adelante): paso corto de luchador, el pie de delante avanza y el de
# atrás le sigue sin cruzarse. 32 ticks.
paso1 = variar(GUARDIA, muslo_L=(.62, .02, -.78), pierna_L=(.2, 0, -.98))
paso2 = variar(GUARDIA, muslo_R=(.08, -.02, -.99), pierna_R=(-.45, 0, -.89), muslo_L=(.3, .02, -.95))
accion('andar', [(0, GUARDIA, .07, 0), (8, paso1, .05, 0), (16, GUARDIA, .06, 0),
                 (24, paso2, .05, 0), (32, GUARDIA, .07, 0)], True)

# Jab: 11 ticks, los del movimiento stand_lp (3 + 3 + 5). Brazo adelantado
# recto a la cara, hombro y torso acompañan.
extendido = variar(GUARDIA, hombro_L=(.45, 1, 0), brazo_L=(1, .05, .02), antebrazo_L=(1, -.02, .03),
                   mano_L=(1, -.02, .02), pecho=(.28, .05, 1), columna=(.16, .03, 1), cabeza=(.02, 0, 1))
accion('jab', [(0, GUARDIA, .07, 0), (3, extendido, .08, .02), (6, extendido, .08, .02), (11, GUARDIA, .07, 0)], False)

esqueleto.animation_data.action = bpy.data.actions['guardia']
poner_pose(GUARDIA, .07)


# --- Exportar -----------------------------------------------------------------------------

bpy.ops.object.select_all(action='DESELECT')
esqueleto.select_set(True)
cuerpo.select_set(True)
glb = os.path.join(SALIDA, 'cristina.glb')
bpy.ops.export_scene.gltf(
    filepath=glb, export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_frame_range=False, export_yup=True, export_apply=False,
)
print('EXPORTADO', glb, len(cuerpo.data.vertices), 'vértices')
# El .blend NO se guarda dentro del proyecto: Godot intenta importar cualquier
# .blend que encuentre. El producto es el .glb; el .blend se regenera con este
# script cuando haga falta.


# --- Previews -----------------------------------------------------------------------------

if PREVIEWS:
    os.makedirs(PREVIEWS, exist_ok=True)
    escena.render.engine = 'BLENDER_WORKBENCH'
    escena.display.shading.light = 'STUDIO'
    escena.display.shading.color_type = 'TEXTURE'
    escena.display.shading.show_object_outline = True
    escena.display.shading.object_outline_color = (.08, .04, .11)
    escena.render.resolution_x, escena.render.resolution_y = 600, 600
    escena.render.film_transparent = False
    escena.world = bpy.data.worlds.new('fondo')
    escena.world.color = (.3, .25, .35)
    cam_datos = bpy.data.cameras.new('cam')
    cam_datos.type = 'ORTHO'
    cam_datos.ortho_scale = 2.0
    cam = bpy.data.objects.new('cam', cam_datos)
    escena.collection.objects.link(cam)
    escena.camera = cam
    vistas = {'lado': ((0, -4, .9), (90, 0, 0)), 'tres_cuartos': ((2.6, -2.6, 1.2), (82, 0, 45)),
              'cara': ((.9, -.9, 1.6), (90, 0, 45))}
    for nombre_accion, fotograma in (('guardia', 0), ('jab', 4), ('andar', 8)):
        esqueleto.animation_data.action = bpy.data.actions[nombre_accion]
        escena.frame_set(fotograma)
        for vista, (loc, rot) in vistas.items():
            if vista != 'lado' and nombre_accion != 'guardia':
                continue
            cam.location = loc
            cam.rotation_euler = [math.radians(r) for r in rot]
            cam_datos.ortho_scale = .55 if vista == 'cara' else 2.0
            if vista == 'cara':
                cam.location = (.9, -.9, 1.58)
            escena.render.filepath = os.path.join(PREVIEWS, f'cristina_{nombre_accion}_{vista}.png')
            bpy.ops.render.render(write_still=True)
    print('PREVIEWS', PREVIEWS)
