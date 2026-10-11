"""Poses the realistic anatomy model with the exercise keyframes from
assets/data/exercises.json and renders looping frames for every exercise
(worked muscles in red), plus a still for the thumbnail.

    python3 -I pose_render.py -- body.blend exercises.json OUT_DIR [size] [frames] [only_ids]
"""
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import mannequin_fk as fk  # noqa: E402

args = sys.argv[sys.argv.index('--') + 1:]
BLEND, EXJSON, OUT = args[0], args[1], args[2]
SIZE = int(args[3]) if len(args) > 3 else 360
NFRAMES = int(args[4]) if len(args) > 4 else 10
ONLY = set(args[5].split(',')) if len(args) > 5 and args[5] else None
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
O = {o.name: o for o in meshes}


def verts(o):
    n = len(o.data.vertices)
    a = np.empty(n * 3, dtype=np.float32)
    o.data.vertices.foreach_get('co', a)
    a = a.reshape(-1, 3)
    m = np.array(o.matrix_world)
    return a @ m[:3, :3].T + m[:3, 3]


def top(o, frac=0.05, low=False):
    v = verts(o)
    z = v[:, 2]
    zmin, zmax = z.min(), z.max()
    if low:
        sel = v[z < zmin + (zmax - zmin) * frac]
    else:
        sel = v[z > zmax - (zmax - zmin) * frac]
    return Vector(sel.mean(axis=0))


# ---------------------------------------------------------------- landmarks
L = {}
for s in ('l', 'r'):
    fem = verts(O['Femur.' + s])
    zt = fem[:, 2].max()
    head = fem[fem[:, 2] > zt - 0.05]
    # femoral head = most medial part of the top region
    med = head[np.argsort(np.abs(head[:, 0]))[: max(5, len(head) // 3)]]
    L['hip_' + s] = Vector(med.mean(axis=0))
    L['knee_' + s] = (top(O['Femur.' + s], 0.04, low=True) + top(O['Tibia.' + s], 0.04)) / 2
    L['ankle_' + s] = Vector(verts(O['Talus.' + s]).mean(axis=0))
    cal = verts(O['Calcaneus.' + s])
    L['heel_' + s] = Vector(cal[np.argmax(cal[:, 1])])
    toes = np.concatenate([verts(o) for n, o in O.items() if 'of foot.' + s in n and 'phalanx' in n.lower()])
    L['toe_' + s] = Vector(toes[np.argmin(toes[:, 1])])
    hum = O['Humerus.' + s]
    L['shoulder_' + s] = top(hum, 0.06)
    L['elbow_' + s] = top(hum, 0.04, low=True)
    L['wrist_' + s] = (top(O['Radius.' + s], 0.04, low=True) + top(O['Ulna.' + s], 0.04, low=True)) / 2
    hand = np.concatenate([verts(o) for n, o in O.items() if 'of hand.' + s in n and 'phalanx' in n.lower()])
    L['hand_' + s] = Vector(hand[np.argmin(hand[:, 2])])
L['pelvis'] = (L['hip_l'] + L['hip_r']) / 2
L['shoulders'] = (L['shoulder_l'] + L['shoulder_r']) / 2
L['neck'] = Vector(verts(O['Vertebra C7']).mean(axis=0))
skull = np.concatenate([verts(O[n]) for n in ('Frontal bone', 'Occipital bone') if n in O])
L['head'] = Vector((0, float(skull[:, 1].mean()), float(skull[:, 2].max())))
print({k: tuple(round(x, 3) for x in v) for k, v in L.items()})

# ---------------------------------------------------------------- armature
arm_data = bpy.data.armatures.new('rig')
arm = bpy.data.objects.new('rig', arm_data)
scn.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
SPEC = [('root', 'pelvis', None, None), ('torso', 'pelvis', 'neck', 'root'), ('neck', 'neck', 'head', 'torso')]
for s in ('l', 'r'):
    SPEC += [('upper_' + s, 'shoulder_' + s, 'elbow_' + s, 'torso'), ('fore_' + s, 'elbow_' + s, 'wrist_' + s, 'upper_' + s),
             ('hand_' + s, 'wrist_' + s, 'hand_' + s, 'fore_' + s), ('thigh_' + s, 'hip_' + s, 'knee_' + s, 'root'),
             ('shin_' + s, 'knee_' + s, 'ankle_' + s, 'thigh_' + s), ('foot_' + s, 'ankle_' + s, 'toe_' + s, 'shin_' + s)]
for name, h, t, parent in SPEC:
    b = eb.new(name)
    b.head = L[h]
    b.tail = L[t] if t else L[h] + Vector((0, 0, 0.1))
    if parent:
        b.parent = eb[parent]
bpy.ops.object.mode_set(mode='OBJECT')
BONES = [s[0] for s in SPEC]
SEG = {}
for name, h, t, _ in SPEC:
    SEG[name] = (np.array(L[h]), np.array(L[t] if t else L[h] + Vector((0, 0, 0.1))))

TORSO_WORDS = ('intercost', 'serratus', ' rib', 'vertebra', 'sternum', 'spinal', 'thorac', 'lumbar', 'lumborum', 'abdomin',
               'external oblique', 'internal oblique', 'latissimus', 'pectoral', 'trapezius', 'rhomboid', 'erector', 'iliocostal', 'longissim', 'multifid',
               'diaphragm', 'costal', 'manubrium', 'xiphoid', 'scapul', 'clavic', 'subclav', 'levator', 'splenius',
               'semispinal', 'rectus abdominis', 'pyramidal', 'linea')
PELVIS_WORDS = ('sacrum', 'coccy', 'hip bone', 'pubi', 'ilium', 'ischi', 'iliacus', 'psoas', 'piriformis',
                'obturator', 'gemell', 'quadratus femoris', 'levator ani')
HEAD_Z = L['shoulders'].z + 0.07


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


LEG_WORDS = ('femor', 'femur', 'vastus', 'sartor', 'gracil', 'adductor longus', 'adductor brevis', 'adductor magnus',
             'adductor minimus', 'tibi', 'fibul', 'gastroc', 'soleus', 'patell', 'calcane', 'talus', 'tars', 'of foot',
             'hallucis', 'plantar', 'gluteus', 'popliteus', 'peron', 'semitend', 'semimembr', 'tensor fasciae',
             'pectineus', 'navicular', 'cuneiform', 'cuboid', 'calcaneal', 'malleol', 'quadriceps', 'achilles')
ARM_WORDS = ('brachi', 'humer', 'radius', 'radial', 'ulna', 'carp', 'pollicis', 'of hand', 'metacarp', 'anconeus',
             'supinator', 'pronator', 'deltoid', 'triceps brachii', 'palmar', 'thenar', 'scaphoid', 'lunate', 'triquetr',
             'pisiform', 'trapezium', 'trapezoid', 'capitate', 'hamate', 'index finger', 'digiti minimi muscle of hand',
             'cubital', 'olecran', 'teres', 'infraspinat', 'supraspinat', 'subscapular', 'coracobrach')


def candidates(o, v):
    n = o.name.lower()
    cx = float(v[:, 0].mean()); cz = float(v[:, 2].mean())
    side = 'l' if cx > 0.02 else ('r' if cx < -0.02 else None)
    if cz > HEAD_Z and abs(cx) < 0.12:
        return ['neck', 'torso']
    leg = any(w in n for w in LEG_WORDS)
    armw = any(w in n for w in ARM_WORDS)
    if side and leg and not armw:
        return ['root', 'thigh_' + side, 'shin_' + side, 'foot_' + side]
    if side and armw and not leg:
        return ['torso', 'upper_' + side, 'fore_' + side, 'hand_' + side]
    if side and not leg and not armw:
        hand_zone = abs(cx) > 0.2 and cz < L['shoulders'].z - 0.1
        if hand_zone:
            return ['upper_' + side, 'fore_' + side, 'hand_' + side]
        if cz < L['pelvis'].z - 0.08:
            return ['root', 'thigh_' + side, 'shin_' + side, 'foot_' + side]
    if cz > HEAD_Z and abs(cx) < 0.12:
        return ['neck', 'torso']
    if any(w in n for w in ('deltoid', 'teres', 'infraspinat', 'supraspinat', 'subscapular', 'coracobrach')) and side:
        return ['upper_' + side, 'torso']
    if any(w in n for w in TORSO_WORDS):
        return ['torso', 'root', 'neck'] + (['upper_' + side] if side and 'pectoral' in n else [])
    if any(w in n for w in PELVIS_WORDS):
        return ['root', 'torso'] + (['thigh_' + side] if side else ['thigh_l', 'thigh_r'])
    if side is None:
        return ['root', 'torso', 'thigh_l', 'thigh_r']
    return ['root', 'torso'] + [b for b in BONES if b.endswith('_' + side)]


for o in meshes:
    if o.data.users > 1:
        o.data = o.data.copy()  # mirrored parts share mesh data; weights live on the mesh
    v = verts(o)
    cand = candidates(o, v)
    d = np.stack([seg_dist(v, *SEG[b]) for b in cand], axis=1)
    if o.get('ff_kind') == 'bone' and ('femur' in o.name.lower() or 'tibia' in o.name.lower() or 'humerus' in o.name.lower()
                                        or 'radius' in o.name.lower() or 'ulna' in o.name.lower() or 'fibula' in o.name.lower()):
        temp = 0.002  # long bones stay rigid
    else:
        temp = 0.018
    w = np.exp(-(d - d.min(axis=1, keepdims=True)) / temp)
    w /= w.sum(axis=1, keepdims=True)
    for j, b in enumerate(cand):
        idx = np.nonzero(w[:, j] > 0.01)[0]
        if len(idx) == 0:
            continue
        vg = o.vertex_groups.get(b) or o.vertex_groups.new(name=b)
        for wv in np.unique(np.round(w[idx, j], 2)):
            sel = idx[np.round(w[idx, j], 2) == wv]
            vg.add(sel.tolist(), float(wv), 'REPLACE')
    mod = o.modifiers.new('arm', 'ARMATURE'); mod.object = arm
print('skinned', len(meshes))

# ---------------------------------------------------------------- materials, props, camera, lights
def principled(name, rgb, rough=0.5, metal=0.0, ao=True):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if not ao:
        b.inputs['Base Color'].default_value = (*rgb, 1)
        return m
    # darken the gaps between muscles (ambient occlusion), as on the body map
    a = nt.nodes.new('ShaderNodeAmbientOcclusion'); a.inputs['Distance'].default_value = 0.025
    gm = nt.nodes.new('ShaderNodeMath'); gm.operation = 'POWER'; gm.inputs[1].default_value = 1.6
    nt.links.new(a.outputs['AO'], gm.inputs[0])
    mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'
    mx.inputs[6].default_value = (rgb[0] * 0.25, rgb[1] * 0.25, rgb[2] * 0.27, 1)
    mx.inputs[7].default_value = (*rgb, 1)
    nt.links.new(gm.outputs[0], mx.inputs['Factor'])
    nt.links.new(mx.outputs[2], b.inputs['Base Color'])
    return m


GREY = (0.72, 0.72, 0.74)
grey = principled('grey', GREY)
bone_m = principled('bone', (0.66, 0.65, 0.63))
red_mats = [principled('red%d' % i, tuple(GREY[c] + ((0.80, 0.16, 0.10)[c] - GREY[c]) * (i / 5) for c in range(3)), 0.45) for i in range(6)]
dark = principled('prop', (0.12, 0.13, 0.17), 0.35, 0.6, ao=False)
steel = principled('steel', (0.55, 0.57, 0.62), 0.25, 0.9, ao=False)


def prim_cyl(name, r, depth, loc, rot, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=24)
    o = bpy.context.active_object; o.name = name; o.data.materials.append(mat); return o


def prim_box(name, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = size; o.data.materials.append(mat); return o


def parent_to_bone(o, bone):
    o.parent = arm; o.parent_type = 'BONE'; o.parent_bone = bone
    pb = arm.pose.bones[bone]
    o.matrix_parent_inverse = (arm.matrix_world @ Matrix.Translation(pb.tail) @ pb.matrix.to_3x3().to_4x4()).inverted() \
        if False else (arm.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.length, 0))).inverted()


props = {}
for s in ('l', 'r'):
    c = (L['wrist_' + s] + L['hand_' + s]) / 2
    parts = [prim_cyl('db_bar_' + s, 0.016, 0.16, c, (0, math.radians(90), 0), steel)]
    for dx in (-0.075, 0.075):
        parts.append(prim_cyl('db_plate_%s%d' % (s, dx > 0), 0.055, 0.035, c + Vector((dx, 0, 0)), (0, math.radians(90), 0), dark))
    for p in parts:
        parent_to_bone(p, 'hand_' + s)
    props['dumbbells_' + s] = parts
cb = (L['wrist_l'] + L['wrist_r']) / 2 + Vector((0, 0, -0.05))
bar = [prim_cyl('barbell_bar', 0.014, 1.5, cb, (0, math.radians(90), 0), steel)]
for dx in (-0.6, 0.6):
    bar.append(prim_cyl('barbell_plate%d' % (dx > 0), 0.22, 0.05, cb + Vector((dx, 0, 0)), (0, math.radians(90), 0), dark))
for p in bar:
    parent_to_bone(p, 'hand_l')
props['barbell'] = bar
props['bar'] = [prim_cyl('pullbar', 0.018, 1.4, (0, 0, 0), (0, math.radians(90), 0), steel)]
props['bench'] = [prim_box('bench_top', (0.5, 0.7, 0.08), (0, 0, 0), dark)]
props['wall'] = [prim_box('wall', (1.6, 0.1, 2.4), (0, 0, 0), principled('wallm', (0.35, 0.37, 0.45), 0.8))]

bpy.ops.mesh.primitive_plane_add(size=6, location=(0, 0, 0))
floor = bpy.context.active_object; floor.is_shadow_catcher = True

cam_d = bpy.data.cameras.new('cam'); cam_d.type = 'ORTHO'
cam = bpy.data.objects.new('cam', cam_d); scn.collection.objects.link(cam); scn.camera = cam
w = bpy.data.worlds.new('w'); scn.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.03, 0.03, 0.04, 1)
w.node_tree.nodes['Background'].inputs[1].default_value = 0.5
for name, loc, energy, size in [('key', (2.5, -2.5, 3.2), 120, 2.5), ('fill', (-3, -2.2, 1.6), 30, 3),
                                ('rim', (-1.5, 3, 2.8), 110, 2), ('rim2', (3, 2.5, 1.5), 55, 2)]:
    ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy; ld.size = size
    lo = bpy.data.objects.new(name, ld); scn.collection.objects.link(lo); lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 0.9)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
scn.render.engine = 'CYCLES'; scn.cycles.device = 'CPU'; scn.cycles.samples = 24; scn.cycles.use_denoising = True
scn.render.film_transparent = True
scn.render.resolution_x = scn.render.resolution_y = SIZE
scn.view_settings.view_transform = 'AgX'; scn.view_settings.look = 'AgX - Medium High Contrast'

# ---------------------------------------------------------------- posing
REST = {b.name: b.matrix_local.copy() for b in arm_data.bones}


def to3(d2, rest_dir, front):
    """2D drawing direction (x right/forward, y down) -> 3D model direction."""
    if front:
        v = Vector((d2[0], 0, -d2[1])).normalized()
        k = rest_dir.y
        out = Vector((v.x * math.sqrt(max(0, 1 - k * k)), k, v.z * math.sqrt(max(0, 1 - k * k))))
    else:
        v = Vector((0, -d2[0], -d2[1])).normalized()
        k = rest_dir.x
        out = Vector((k, v.y * math.sqrt(max(0, 1 - k * k)), v.z * math.sqrt(max(0, 1 - k * k))))
    return out.normalized()


def pose(kf, u):
    j, front = fk.solve(kf, u)
    sub = lambda a, b: (j[a][0] - j[b][0], j[a][1] - j[b][1])
    D = {'torso': sub('shoulder', 'hip'), 'neck': sub('head', 'shoulder')}
    if front:
        shc = ((j['shoulder'][0] + j['shoulder2'][0]) / 2, j['shoulder'][1])
        hpc = ((j['hip'][0] + j['hip2'][0]) / 2, j['hip'][1])
        D['torso'] = (shc[0] - hpc[0], shc[1] - hpc[1])
        D['neck'] = (j['head'][0] - shc[0], j['head'][1] - shc[1])
        # 2D '' = person's left (screen right) = model .l (+x)
        for s2, s in (('', 'l'), ('2', 'r')):
            D['upper_' + s] = sub('elbow' + s2, 'shoulder' + s2); D['fore_' + s] = sub('wrist' + s2, 'elbow' + s2)
            D['thigh_' + s] = sub('knee' + s2, 'hip' + s2); D['shin_' + s] = sub('ankle' + s2, 'knee' + s2)
    else:
        # near side ('' in 2D) faces the camera (+x) = model left
        for s2, s in (('', 'l'), ('2', 'r')):
            hip = 'hip'
            D['upper_' + s] = sub('elbow' + s2, 'shoulder'); D['fore_' + s] = sub('wrist' + s2, 'elbow' + s2)
            D['thigh_' + s] = sub('knee' + s2, hip); D['shin_' + s] = sub('ankle' + s2, 'knee' + s2)
            D['foot_' + s] = sub('toe' + s2, 'heel' + s2)
    for b in arm.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for name in BONES:
        pb = arm.pose.bones[name]
        if name not in D:
            continue
        rest = REST[name]
        rest_dir = (rest.to_3x3() @ Vector((0, 1, 0))).normalized()
        target = to3(D[name], rest_dir, front)
        # current (inherited) direction after parents were posed
        cur = (pb.matrix.to_3x3() @ Vector((0, 1, 0))).normalized()
        q = cur.rotation_difference(target)
        m = pb.matrix.copy()
        loc = m.to_translation()
        pb.matrix = Matrix.Translation(loc) @ (q.to_matrix() @ m.to_3x3()).to_4x4()
        bpy.context.view_layer.update()
    return front


def world_point(bone, at_tail=True, off=0.0):
    pb = arm.pose.bones[bone]
    return arm.matrix_world @ (pb.tail if at_tail else pb.head)


CONTACT = [('foot_l', True, 0.0), ('foot_r', True, 0.0), ('foot_l', False, 0.06), ('foot_r', False, 0.06),
           ('shin_l', False, 0.06), ('shin_r', False, 0.06), ('root', False, 0.12), ('neck', True, 0.1),
           ('hand_l', True, 0.02), ('hand_r', True, 0.02), ('torso', True, 0.1), ('fore_l', False, 0.05), ('fore_r', False, 0.05)]


def ground(kf, front):
    root = arm.pose.bones['root']
    if kf.get('anchor') == 'wrist':
        return
    zs = [world_point(b, t).z - off for b, t, off in CONTACT if b in arm.pose.bones]
    if front:
        zs = [world_point(b, True).z for b in ('foot_l', 'foot_r')]
    dz = -min(zs)
    root.matrix = Matrix.Translation(Vector((0, 0, dz))) @ root.matrix
    bpy.context.view_layer.update()


data = json.load(open(EXJSON))
for ex in data['exercises']:
    if ONLY and ex['id'] not in ONLY:
        continue
    kf = ex['keyframes']
    tot = sum(ex['muscles'].values())
    wts = {m: v / tot for m, v in ex['muscles'].items()}
    for o in meshes:
        g = o.get('ff_group') or ''
        lvl = 0 if not g else min(5, round(min(1.0, wts.get(g, 0) * 2.6) * 5))
        mat = bone_m if o.get('ff_kind') == 'bone' else (red_mats[lvl] if lvl else grey)
        o.data.materials.clear(); o.data.materials.append(mat)
    on = set(kf.get('props', []))
    for key, objs in props.items():
        show = (key.startswith('dumbbells') and 'dumbbells' in on) or key in on
        for p in objs:
            p.hide_render = not show
    timed = ex['mode'] == 'timed'
    n = 1 if timed else NFRAMES
    us = [0.0] if timed else [0.5 - 0.5 * math.cos(math.pi * i / (n - 1)) for i in range(n)]
    # first pass: collect bounds and anchors
    frames_pts = []
    anchor0 = None
    for u in us:
        front = pose(kf, u)
        if kf.get('anchor') == 'wrist':
            wp = (world_point('hand_l', False) + world_point('hand_r', False)) / 2
            if anchor0 is None:
                anchor0 = wp.copy()
            root = arm.pose.bones['root']
            root.matrix = Matrix.Translation(anchor0 - wp) @ root.matrix
            bpy.context.view_layer.update()
        ground(kf, front)
        pts = [world_point(b, t) for b in BONES for t in (True, False)]
        frames_pts.append(pts)
    allp = [p for f in frames_pts for p in f]
    xs = [p.x for p in allp]; ys = [p.y for p in allp]; zs = [p.z for p in allp]
    lift = 0.0
    if 'bar' in on:
        lift = 2.3 - anchor0.z
    elif kf.get('anchor') == 'wrist':
        feet = [p.z for f in frames_pts for p in f[BONES.index('foot_l') * 2:BONES.index('foot_l') * 2 + 2] + f[BONES.index('foot_r') * 2:BONES.index('foot_r') * 2 + 2]]
        lift = -min(feet)
    cxyz = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2 + lift))
    ext = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)) * 1.12 + 0.18
    cam_d.ortho_scale = ext
    yaw = math.radians(-30 if front else 45)
    dirv = Vector((math.sin(yaw), -math.cos(yaw), 0.18)).normalized()
    cam.location = cxyz + dirv * 6
    cam.rotation_euler = (-dirv).to_track_quat('-Z', 'Y').to_euler()
    # static props
    if 'bar' in on:
        wp = anchor0 + Vector((0, 0, lift))
        props['bar'][0].location = wp
    if 'bench' in on:
        h = anchor0.z + lift - 0.03
        props['bench'][0].location = Vector((anchor0.x, anchor0.y + 0.2, h / 2)); props['bench'][0].scale = (0.7, 0.45, h)
    if 'wall' in on:
        pose(kf, 0.0); ground(kf, False)
        props['wall'][0].location = world_point('root', False) + Vector((0, 0.24, 0)); props['wall'][0].location.z = 1.1
    for i, u in enumerate(us):
        front = pose(kf, u)
        if kf.get('anchor') == 'wrist':
            wp = (world_point('hand_l', False) + world_point('hand_r', False)) / 2
            root = arm.pose.bones['root']
            root.matrix = Matrix.Translation(anchor0 + Vector((0, 0, lift)) - wp) @ root.matrix
            bpy.context.view_layer.update()
        ground(kf, front)
        scn.render.filepath = os.path.join(OUT, '%s_%02d.png' % (ex['id'], i))
        bpy.ops.render.render(write_still=True)
    if os.environ.get('FF_DEBUG'):
        dg = bpy.context.evaluated_depsgraph_get()
        segs = [(world_point(b, False), world_point(b, True)) for b in BONES if b != 'root']
        bad = []
        for o in meshes:
            ev = o.evaluated_get(dg); me = ev.to_mesh()
            if len(me.vertices) == 0:
                ev.to_mesh_clear(); continue
            c = sum((ev.matrix_world @ v.co for v in me.vertices), Vector()) / len(me.vertices)
            ev.to_mesh_clear()
            dmin = min((c - (a + (b - a) * max(0, min(1, (c - a).dot(b - a) / max(1e-9, (b - a).length_squared))))).length for a, b in segs)
            if dmin > 0.12:
                bad.append((round(dmin, 2), o.name, list(o.vertex_groups.keys())))
        bad.sort(reverse=True); print('OUTLIERS', len(bad), bad[:25])
    print('rendered', ex['id'], flush=True)
print('ALL DONE')
