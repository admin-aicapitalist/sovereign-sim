"""Separate rooftop cloth from the original Blender buildings, retaining poles.

blender --background --python-exit-code 1 --python godot/tools/render_atmosphere.py
Then: .venv/bin/python godot/tools/finish_atmosphere.py
Original scenes/cameras remain untouched. Exact face matching prevents removal
of facade banners, roof trim, market awnings, or other shared cloth materials.
"""
import json
from pathlib import Path
import sys

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/atmosphere'
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT / 'tools/art'))
import render_palace as art

# Original flag() calls in render_palace.py and render_buildings.py.
FLAGS = {'palace': [(-3.25, 2.55, 7.27, .76), (3.25, 2.55, 7.27, .76),
                    (0, 1.02, 9.24, 1.12)],
         'warriors': [(-1.83, 1.01, 4.55, .83)],
         'tower': [(0, .12, 7.51, .75)]}


def signature(vertices):
    # Blender stores mesh coordinates as float32; quantize both paths equally.
    return tuple(sorted(tuple(round(float(v), 4) for v in Vector(p)) for p in vertices))


def tint(material, color):
    rgb = tuple(art.linear(int(color[i:i+2], 16) / 255) for i in (0, 2, 4))
    material.diffuse_color = (*rgb, 1)
    mixes = [n for n in material.node_tree.nodes if n.type == 'MIX_RGB' and n.blend_type == 'MULTIPLY']
    if mixes:
        mixes[-1].inputs[1].default_value = (*rgb, 1)
    else:
        material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*rgb, 1)


metadata = {}
for key, flags in FLAGS.items():
    source = ROOT / ('assets/art/palace/sovereign-palace.blend' if key == 'palace'
                     else f'assets/art/buildings/source/{key}.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    art.gold = bpy.data.materials['Aged brass fittings']
    art.gold_light = bpy.data.materials['Ivory heraldic embroidery']
    art.cloth = bpy.data.materials['Crimson royal cloth']
    art.flag_gold = bpy.data.materials['Ivory silk standards']
    art.geo = art.Geometry()
    for flag in flags:
        art.flag(*flag)
    signatures = set()
    for (_, mat), (vertices, faces) in art.geo.parts.items():
        if mat in (art.cloth.name, art.flag_gold.name):
            signatures.update(signature([vertices[i] for i in face]) for face in faces)
    removed = 0
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH' or not any(m.name in (art.cloth.name, art.flag_gold.name) for m in obj.data.materials):
            continue
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        faces = [face for face in mesh.faces if signature([obj.matrix_world @ v.co for v in face.verts]) in signatures]
        removed += len(faces)
        bmesh.ops.delete(mesh, geom=faces, context='FACES')
        mesh.to_mesh(obj.data)
        mesh.free()
    assert removed == len(flags) * 13, (key, removed, len(flags) * 13)

    # Match the existing royal palette exactly; the timber guild keeps its tiles.
    if key in ('palace', 'tower'):
        slates = ('546a76', '617781', '6c828a', '59747e', '71858d', '526b78', '637985', '788b90', '5a7180')
        stones = ('b2b3a7', 'bfc0af', 'a6ada5', 'b7baad', 'aab0a5', 'c0c1b2')
        colors = {'Terracotta ridge caps': '76838a', 'Roof eave shadows': '34464b',
                  'Weathering · roof_chip': '869196', 'Pale carved edges': 'd5d0b9', 'Crimson royal cloth': 'a52f2a'}
        for mat in bpy.data.materials:
            if mat.name.startswith('Aged terracotta tile'):
                tint(mat, slates[int(mat.name[-2:]) % len(slates)])
            elif mat.name.startswith('Weathered grey masonry'):
                tint(mat, stones[int(mat.name[-2:]) % len(stones)])
            elif mat.name in colors:
                tint(mat, colors[mat.name])

    scene = bpy.context.scene
    bpy.context.view_layer.update()
    def project(point):
        p = world_to_camera_view(scene, scene.camera, Vector(point))
        return [p.x, 1-p.y]
    metadata[key] = {'flags': [], 'removed_cloth_faces': removed}
    for x, y, z, size in flags:
        metadata[key]['flags'].append({
            'at': project((x, y, z+1.36*size)),
            'end': project((x+1.13*size, y, z+1.30*size)),
            'bottom': project((x, y, z+.90*size))})
    scene.render.resolution_x = scene.render.resolution_y = 1440
    scene.render.resolution_percentage = 100
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 8
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.filepath = str(OUT / f'{key}-render.png')
    bpy.ops.render.render(write_still=True)
    print('ATMOSPHERE', key, removed, 'cloth faces separated', flush=True)
(OUT / 'projection.json').write_text(json.dumps(metadata, indent=2) + '\n')
