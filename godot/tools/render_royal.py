"""Refresh civic materials and render an original armored Ember Warlord.

blender --background --python godot/tools/render_royal.py
Then run style_art.py to finish/crop/import the renders. Original scenes stay intact.
"""
import math
from pathlib import Path
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/art/royal'
OUT.mkdir(exist_ok=True)
sys.path.insert(0, str(ROOT/'tools/art'))
import render_palace as art
import render_units as units


def tint(material, color):
    rgb = tuple(art.linear(int(color[i:i+2],16)/255) for i in (0,2,4))
    material.diffuse_color = (*rgb,1)
    shader = material.node_tree.nodes.get('Principled BSDF')
    mixes = [n for n in material.node_tree.nodes if n.type=='MIX_RGB' and n.blend_type=='MULTIPLY']
    if mixes:
        mixes[-1].inputs[1].default_value = (*rgb,1)
    else:
        shader.inputs['Base Color'].default_value = (*rgb,1)


for key in ('palace','wizards','temple','tower'):
    path = ROOT/'assets/art/palace/sovereign-palace.blend' if key=='palace' else ROOT/f'assets/art/buildings/source/{key}.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path))
    slates = ('546a76','617781','6c828a','59747e','71858d','526b78','637985','788b90','5a7180')
    stones = ('b2b3a7','bfc0af','a6ada5','b7baad','aab0a5','c0c1b2')
    for mat in bpy.data.materials:
        if mat.name.startswith('Aged terracotta tile'):
            tint(mat, slates[int(mat.name[-2:])%len(slates)])
        elif mat.name=='Terracotta ridge caps': tint(mat,'76838a')
        elif mat.name=='Roof eave shadows': tint(mat,'34464b')
        elif mat.name=='Weathering · roof_chip': tint(mat,'869196')
        elif mat.name.startswith('Weathered grey masonry'):
            tint(mat, stones[int(mat.name[-2:])%len(stones)])
        elif mat.name=='Pale carved edges': tint(mat,'d5d0b9')
        elif mat.name=='Crimson royal cloth': tint(mat,'a52f2a')
    scene=bpy.context.scene
    scene.render.resolution_x=scene.render.resolution_y=1440
    scene.render.resolution_percentage=100
    scene.render.threads_mode='FIXED'; scene.render.threads=8
    scene.cycles.samples=48; scene.cycles.use_denoising=True
    scene.render.filepath=str(OUT/f'{key}-render.png')
    bpy.ops.render.render(write_still=True)
    print('ROYAL BUILDING', key, flush=True)

# Author the boss as a new miniature with an eight-pose animation timeline.
bpy.ops.wm.read_factory_settings(use_empty=True)
units.M.clear(); units.materials()
for key,color in {'troll':'554f48','trollLight':'81715f','leather':'792b25','leatherDark':'452722','wood':'41484a','woodLight':'647174','rust':'b59b68','hair':'252c2c','moss':'5b6365','stone':'a38c61'}.items():
    tint(units.M[key],color)
units.M['bossplate']=art.weathered_material('Warlord · blackened steel','48555b',22)
units.M['bossgold']=art.material('Warlord · scorched crown','c89b54')
units.M['bossember']=art.material('Warlord · molten amber','efad53',1.5)
scene,project=units.setup(576,32,2.15)
scene.render.threads=8
all_poses=[]
for pose in units.POSES:
    for objects in all_poses:
        for obj in objects: obj.hide_render=True
    before=set(scene.objects)
    units.g=art.Geometry(); units.troll(pose)
    phase=int(pose[-1])*math.pi/2 if pose.startswith('walk') else 0
    bob=.035*math.cos(phase*2) if pose.startswith('walk') else 0
    units.group('Warlord · great spiked pauldrons')
    for side in (-1,1):
        units.ellipsoid((side*.61,.01,2.43+bob),(.37,.40,.22),units.M['bossplate'])
        for i in range(3):
            units.g.frustum(side*(.40+i*.18),.01,2.58+bob,.077,.008,.22+i*.035,units.M['bossgold'],8)
    units.group('Warlord · cuirass and ember sigil')
    units.loft([(0,-.03,1.68+bob,.56,.43),(0,-.01,2.20+bob,.64,.46)],units.M['bossplate'])
    units.g.box((0,-.485,2.01+bob),(.12,.035,.27),units.M['bossgold'])
    units.g.box((0,-.488,2.04+bob),(.28,.04,.08),units.M['bossgold'])
    units.ellipsoid((0,-.52,2.06+bob),(.055,.025,.055),units.M['bossember'])
    units.group('Warlord · jagged ember crown')
    units.loft([(0,-.2,3.01+bob,.30,.23),(0,-.2,3.12+bob,.30,.23)],units.M['bossgold'])
    for i in range(7):
        a=i*math.tau/7
        units.g.frustum(math.cos(a)*.28,-.2+math.sin(a)*.21,3.1+bob,.057,.004,.24 if i%2 else .31,units.M['bossgold'],6)
    for side in (-1,1): units.ellipsoid((side*.111,-.385,2.873+bob),(.027,.012,.023),units.M['bossember'],6,10)
    units.g.finish()
    objects=list(set(scene.objects)-before); all_poses.append(objects)
    for obj in objects:
        obj.rotation_euler.z=math.pi/2
        for poly in obj.data.polygons:
            poly.use_smooth='crown' not in obj.name and 'pauldrons' not in obj.name
    scene.render.filepath=str(OUT/f'warlord-{pose}.png')
    bpy.ops.render.render(write_still=True)
    print('ROYAL WARLORD',pose,flush=True)
for frame in range(8):
    for i,objects in enumerate(all_poses):
        for obj in objects:
            obj.hide_render=(frame!=i); obj.keyframe_insert(data_path='hide_render',frame=frame+1)
scene.render.fps=7; scene.frame_start=1; scene.frame_end=8; scene.frame_set(1)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ember-warlord.blend'))
