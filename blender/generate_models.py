"""
2050: Daralan Cember - Blender model uretici.

KULLANIM
1) Blender'i ac (3.6 veya 4.x), yeni Genel (General) dosya.
2) Scripting sekmesi > New > bu dosyanin icerigini yapistir.
3) Asagidaki OUT_DIR yolunu Godot projenin 'models' klasorune ayarla.
4) Run Script. 15 adet .glb dosyasi uretilir (12 bina + 3 vatandas).

Alternatif (arayuzsuz):
   blender -b -P generate_models.py

Olcu: 1 Blender birimi = 1 metre. Taban merkezi (0,0,0), kapladigi alan ~1.7 x 1.7.
Godot'ta Y yukari oldugu icin disari aktarirken eksen otomatik cevrilir.
Kod icinde konumlar GODOT eksenlerinde yazilir: (x, yukari, derinlik). G() Blender'a cevirir.
"""
import bpy
import bmesh
import math
import os

OUT_DIR = os.path.expanduser("~/daralan-cember/models")   # <-- BUNU DEGISTIR

_mats = {}


# ------------------------------------------------------------------ yardimcilar
def G(x, y, z):
    """Godot (x, yukari, derinlik) -> Blender (x, y, z-yukari)."""
    return (x, -z, y)


def mk_mat(color, emit=0.0, alpha=1.0, metal=0.0, rough=0.85):
    key = (tuple(color), emit, alpha, metal)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("mat%d" % len(_mats))
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        sock = b.inputs.get("Emission Color") or b.inputs.get("Emission")
        sock.default_value = (color[0], color[1], color[2], 1.0)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.blend_method = 'BLEND'
        except Exception:
            pass
    _mats[key] = m
    return m


def _finish(o, name, color, parent, **kw):
    o.name = name
    o.data.materials.append(mk_mat(color, **kw))
    if parent is not None:
        o.parent = parent
    return o


def empty(name, pos, parent=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = G(*pos)
    if parent is not None:
        e.parent = parent
    return e


def box(parent, size, pos, color, rx=0.0, ry=0.0, **kw):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.scale = (size[0], size[2], size[1])
    o.location = G(*pos)
    o.rotation_euler = (math.radians(rx), 0.0, math.radians(ry))
    return _finish(o, "box", color, parent, **kw)


def cyl(parent, r_top, r_bot, h, pos, color, **kw):
    bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=r_bot, radius2=r_top, depth=h)
    o = bpy.context.active_object
    o.location = G(*pos)
    return _finish(o, "cyl", color, parent, **kw)


def sphere(parent, r, pos, color, **kw):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=r)
    o = bpy.context.active_object
    o.location = G(*pos)
    return _finish(o, "sphere", color, parent, **kw)


def prism(parent, size, pos, color, **kw):
    """Ucgen kesitli cati. Kesit XY (Godot), uzanim Z."""
    w, h, d = size
    pts = [(-w / 2, -h / 2, d / 2), (w / 2, -h / 2, d / 2), (0, h / 2, d / 2),
           (-w / 2, -h / 2, -d / 2), (w / 2, -h / 2, -d / 2), (0, h / 2, -d / 2)]
    verts = [G(*p) for p in pts]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    me = bpy.data.meshes.new("prism")
    me.from_pydata(verts, [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("prism", me)
    bpy.context.collection.objects.link(o)
    o.location = G(*pos)
    return _finish(o, "prism", color, parent, **kw)


def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        o.select_set(True)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_yup=True, export_apply=True)
    print("Yazildi:", path)


def C(r, g, b):
    return (r, g, b)


# ------------------------------------------------------------------ binalar
def house():
    box(None, (1.3, 0.8, 1.2), (0, 0.4, 0), C(0.93, 0.88, 0.78))
    prism(None, (1.55, 0.6, 1.4), (0, 1.1, 0), C(0.75, 0.28, 0.22))
    box(None, (0.22, 0.42, 0.05), (0, 0.21, 0.61), C(0.3, 0.2, 0.15))
    box(None, (0.22, 0.2, 0.05), (0.42, 0.52, 0.61), C(1.0, 0.85, 0.4), emit=0.8)
    box(None, (0.22, 0.2, 0.05), (-0.42, 0.52, 0.61), C(1.0, 0.85, 0.4), emit=0.8)
    box(None, (0.2, 0.5, 0.2), (0.45, 1.25, -0.2), C(0.55, 0.3, 0.25))  # baca


def apartment():
    box(None, (1.4, 0.5, 1.4), (0, 0.25, 0), C(0.6, 0.62, 0.68))
    box(None, (1.1, 2.6, 1.1), (0, 1.8, 0), C(0.82, 0.84, 0.88))
    for i in range(6):
        box(None, (1.14, 0.14, 1.14), (0, 0.95 + i * 0.38, 0), C(0.22, 0.4, 0.62), emit=0.4)
    box(None, (0.5, 0.3, 0.5), (0, 3.25, 0), C(0.5, 0.52, 0.56))
    cyl(None, 0.02, 0.03, 0.6, (0, 3.7, 0), C(0.7, 0.7, 0.72))
    # balkonlar
    for i in range(3):
        box(None, (0.5, 0.05, 0.25), (0, 1.1 + i * 0.75, 0.68), C(0.55, 0.57, 0.6))


def farm():
    box(None, (1.8, 0.08, 1.8), (0, 0.04, 0), C(0.5, 0.36, 0.2))
    for i in range(4):
        box(None, (1.1, 0.18, 0.2), (-0.3, 0.17, -0.7 + i * 0.45), C(0.4, 0.72, 0.25))
    box(None, (0.5, 0.45, 0.5), (0.62, 0.3, -0.55), C(0.7, 0.2, 0.18))
    prism(None, (0.6, 0.3, 0.55), (0.62, 0.7, -0.55), C(0.35, 0.2, 0.15))
    cyl(None, 0.12, 0.12, 0.7, (0.62, 0.35, 0.1), C(0.75, 0.75, 0.78))  # silo


def vfarm():
    box(None, (1.5, 0.2, 1.5), (0, 0.1, 0), C(0.5, 0.52, 0.55))
    box(None, (1.3, 2.2, 1.3), (0, 1.3, 0), C(0.5, 0.95, 0.75), alpha=0.35)
    for i in range(4):
        box(None, (1.1, 0.12, 1.1), (0, 0.6 + i * 0.5, 0), C(0.3, 0.75, 0.3))
        box(None, (1.0, 0.04, 0.1), (0, 0.78 + i * 0.5, 0.4), C(0.9, 0.4, 0.95), emit=1.2)
    box(None, (1.4, 0.1, 1.4), (0, 2.45, 0), C(0.25, 0.28, 0.3))


def market():
    box(None, (1.5, 0.7, 1.3), (0, 0.35, 0), C(0.88, 0.82, 0.7))
    box(None, (1.6, 0.08, 1.4), (0, 0.74, 0), C(0.4, 0.4, 0.45))
    for i in range(4):
        col = C(0.85, 0.2, 0.2) if i % 2 == 0 else C(0.95, 0.95, 0.95)
        box(None, (0.38, 0.06, 0.5), (-0.57 + i * 0.38, 0.62, 0.8), col, rx=-20)
    box(None, (1.0, 0.25, 0.06), (0, 0.95, 0.5), C(0.2, 0.45, 0.8), emit=0.6)
    for i in range(3):  # kasalar
        box(None, (0.18, 0.15, 0.18), (-0.4 + i * 0.4, 0.08, 0.95), C(0.7, 0.5, 0.25))


def factory():
    box(None, (1.6, 0.9, 1.4), (0, 0.45, 0), C(0.55, 0.58, 0.62))
    for i in range(3):
        prism(None, (0.5, 0.4, 1.4), (-0.5 + i * 0.5, 1.1, 0), C(0.42, 0.45, 0.5))
    cyl(None, 0.15, 0.18, 1.6, (0.6, 1.5, 0.45), C(0.6, 0.3, 0.25))
    box(None, (0.5, 0.45, 0.06), (-0.4, 0.3, 0.72), C(0.25, 0.27, 0.3))  # kapi


def coal():
    box(None, (1.5, 0.9, 1.0), (-0.05, 0.45, 0.5), C(0.28, 0.28, 0.3))
    cyl(None, 0.32, 0.45, 1.8, (0.45, 0.9, -0.45), C(0.4, 0.4, 0.43))
    cyl(None, 0.32, 0.45, 1.8, (-0.45, 0.9, -0.5), C(0.4, 0.4, 0.43))
    box(None, (1.6, 0.06, 0.2), (0, 0.95, 0.9), C(0.9, 0.7, 0.1), emit=0.6)
    for i in range(3):  # komur yigini
        sphere(None, 0.22, (-0.6 + i * 0.25, 0.1, 0.98), C(0.1, 0.1, 0.11))


def solar():
    box(None, (1.7, 0.08, 1.7), (0, 0.04, 0), C(0.55, 0.57, 0.6))
    for i in range(3):
        box(None, (1.5, 0.06, 0.45), (0, 0.34, -0.55 + i * 0.55), C(0.12, 0.25, 0.6), rx=-25, metal=0.6, emit=0.15)
        box(None, (0.06, 0.3, 0.06), (0, 0.18, -0.55 + i * 0.55), C(0.7, 0.7, 0.72))


def wind():
    box(None, (0.5, 0.1, 0.5), (0, 0.05, 0), C(0.6, 0.6, 0.62))
    cyl(None, 0.06, 0.12, 2.6, (0, 1.35, 0), C(0.93, 0.93, 0.95))
    box(None, (0.2, 0.2, 0.4), (0, 2.65, 0.05), C(0.9, 0.9, 0.92))
    rotor = empty("Rotor", (0, 2.65, 0.3))          # <- oyun bu ismi bulup dondurur
    for k in range(3):
        arm = empty("Arm%d" % k, (0, 0, 0), rotor)
        arm.rotation_euler = (0.0, -math.radians(k * 120.0), 0.0)
        box(arm, (0.1, 0.95, 0.025), (0, 0.5, 0), C(0.96, 0.96, 0.98))
    sphere(rotor, 0.09, (0, 0, 0), C(0.9, 0.9, 0.92))


def capture():
    box(None, (1.6, 0.3, 1.6), (0, 0.15, 0), C(0.6, 0.65, 0.7))
    cyl(None, 0.55, 0.62, 1.6, (0, 1.1, 0), C(0.8, 0.85, 0.9))
    cyl(None, 0.66, 0.66, 0.08, (0, 1.0, 0), C(0.2, 0.9, 0.8), emit=1.4)
    cyl(None, 0.66, 0.66, 0.08, (0, 1.45, 0), C(0.2, 0.9, 0.8), emit=1.4)
    rotor = empty("Rotor", (0, 1.95, 0))             # <- oyun bu ismi bulup dondurur
    for k in range(2):
        box(rotor, (1.0, 0.05, 0.12), (0, 0, 0), C(0.2, 0.8, 0.75), ry=k * 90.0)


def park():
    cyl(None, 0.85, 0.85, 0.08, (0, 0.04, 0), C(0.3, 0.6, 0.28))
    spots = [(-0.4, 0.3), (0.38, -0.3), (0.1, 0.5), (-0.3, -0.45)]
    for k, s in enumerate(spots):
        h = 0.6 + (k % 3) * 0.15
        cyl(None, 0.05, 0.07, 0.4, (s[0], 0.25, s[1]), C(0.4, 0.27, 0.15))
        cyl(None, 0.0, 0.3, h, (s[0], 0.45 + h * 0.5, s[1]), C(0.15 + 0.05 * k, 0.5, 0.2))
    box(None, (0.4, 0.08, 0.14), (0.3, 0.14, 0.55), C(0.5, 0.35, 0.2))


def seawall():
    box(None, (1.9, 0.9, 0.7), (0, 0.45, 0), C(0.62, 0.63, 0.66))
    box(None, (1.9, 0.5, 0.35), (0, 0.25, 0.45), C(0.55, 0.56, 0.6), rx=18)
    for i in range(4):
        box(None, (0.3, 0.25, 0.7), (-0.7 + i * 0.467, 1.02, 0), C(0.7, 0.71, 0.74))
    box(None, (1.9, 0.06, 0.1), (0, 0.75, 0.36), C(0.2, 0.55, 0.9), emit=0.6)


# ------------------------------------------------------------------ vatandaslar
def citizen_factory(shirt):
    def build():
        skin = C(0.9, 0.72, 0.58)
        for sx in (-0.05, 0.05):
            box(None, (0.07, 0.2, 0.08), (sx, 0.1, 0), C(0.2, 0.25, 0.4))          # bacak
            box(None, (0.05, 0.18, 0.06), (sx * 2.2, 0.31, 0), shirt)               # kol
        box(None, (0.2, 0.22, 0.11), (0, 0.31, 0), shirt)                           # govde
        sphere(None, 0.075, (0, 0.5, 0), skin)                                      # kafa
    return build


BUILDERS = {
    "house": house, "apartment": apartment, "farm": farm, "vfarm": vfarm,
    "market": market, "factory": factory, "coal": coal, "solar": solar,
    "wind": wind, "capture": capture, "park": park, "seawall": seawall,
    "citizen_a": citizen_factory(C(0.85, 0.3, 0.25)),
    "citizen_b": citizen_factory(C(0.25, 0.5, 0.85)),
    "citizen_c": citizen_factory(C(0.9, 0.75, 0.2)),
}


def main():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for name, fn in BUILDERS.items():
        reset()
        fn()
        export(name)
    reset()
    print("Bitti. Dosyalar:", OUT_DIR)


main()
