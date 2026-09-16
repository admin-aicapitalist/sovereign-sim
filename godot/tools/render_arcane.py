"""Author original mineral ice and an incandescent meteor in Blender.

blender --background --python-exit-code 1 --python godot/tools/render_arcane.py
"""
import json, math, random, sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'godot/tools'))
import render_characters as characters

OUT=ROOT/'godot/assets/arcane'; OUT.mkdir(exist_ok=True)
SOURCE=ROOT/'assets/art/magic'; SOURCE.mkdir(parents=True,exist_ok=True)
metadata={}

def clear_meshes():
    for obj in list(bpy.data.objects):
        if obj.type=='MESH': bpy.data.objects.remove(obj,do_unlink=True)

def crystal(location,height,width,angle,material):
    sides=6; vertices=[]
    for z,r in [(0,width*.78),(height*.71,width),(height,.008)]:
        for i in range(sides):
            a=i*math.tau/sides; vertices.append((math.cos(a)*r,math.sin(a)*r,z))
    faces=[]
    for ring in range(2):
        for i in range(sides): faces.append((ring*sides+i,ring*sides+(i+1)%sides,(ring+1)*sides+(i+1)%sides,(ring+1)*sides+i))
    mesh=bpy.data.meshes.new('Six-sided mineral facets'); mesh.from_pydata(vertices,[],faces); mesh.materials.append(material)
    obj=bpy.data.objects.new('Fractured glacial quartz',mesh); bpy.context.scene.collection.objects.link(obj)
    obj.location=location; obj.rotation_euler=(angle*.45,angle,angle*.7)
    bevel=obj.modifiers.new('Minute chipped glints','BEVEL'); bevel.width=.008; bevel.segments=1

bpy.ops.wm.read_factory_settings(use_empty=True)
scene,project=characters.setup(384,48)
scene.camera.data.ortho_scale=3.6
target=Vector((0,0,1.10)); scene.camera.location=target+Vector((18,-18,19))
scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat('-Z','Y').to_euler()
ice=bpy.data.materials.new('Glacial blue mineral with silver faces'); ice.use_nodes=True
nodes=ice.node_tree.nodes; links=ice.node_tree.links; shader=nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=(.15,.55,.66,1)
shader.inputs['Metallic'].default_value=.32; shader.inputs['Roughness'].default_value=.22
shader.inputs['Coat Weight'].default_value=.6; shader.inputs['Coat Roughness'].default_value=.10
shader.inputs['Transmission Weight'].default_value=.20; shader.inputs['IOR'].default_value=1.46
noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=18; noise.inputs['Detail'].default_value=3
bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.07; bump.inputs['Distance'].default_value=.025
links.new(noise.outputs['Fac'],bump.inputs['Height']); links.new(bump.outputs['Normal'],shader.inputs['Normal'])
for variant in range(4):
    clear_meshes(); rng=random.Random(41972+variant)
    crystal((0,0,0),1.65+variant*.09,.22,variant*.085-.1,ice)
    for i in range(5):
        a=i*math.tau/5; crystal((math.cos(a)*.27,math.sin(a)*.27,0),.40+rng.random()*.6,.10+rng.random()*.05,math.sin(a)*.3,ice)
    scene.render.filepath=str(SOURCE/f'ice-{variant}.png'); bpy.ops.render.render(write_still=True)
    metadata[f'ice-{variant}']={'origin':project((0,0,0))}
    if variant==0:
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'glacial-quartz.blend'),compress=True)

clear_meshes()
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=.78,location=(0,0,1.1))
rock=bpy.context.object; rock.name='Pitted obsidian meteor / cooling crust and molten fissures'
rng=random.Random(762)
for vertex in rock.data.vertices: vertex.co*=.86+rng.random()*.27
rock.rotation_euler=(.3,.5,.2)
material=bpy.data.materials.new('Obsidian crust / emissive Voronoi fissures'); material.use_nodes=True
nodes=material.node_tree.nodes; links=material.node_tree.links; shader=nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value=.87
vor=nodes.new('ShaderNodeTexVoronoi'); vor.feature='DISTANCE_TO_EDGE'; vor.inputs['Scale'].default_value=5.8
ramp=nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
for position,color in [(0,(1,.32,.045,1)),(.026,(.95,.12,.012,1)),(.052,(.025,.009,.004,1)),(.16,(.042,.037,.03,1))]:
    element=ramp.color_ramp.elements[0] if position==0 else ramp.color_ramp.elements.new(position)
    element.position=position; element.color=color
links.new(vor.outputs['Distance'],ramp.inputs['Fac']); links.new(ramp.outputs['Color'],shader.inputs['Base Color'])
links.new(ramp.outputs['Color'],shader.inputs['Emission Color']); shader.inputs['Emission Strength'].default_value=1.2
noise=nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=38; noise.inputs['Detail'].default_value=4
bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.65; bump.inputs['Distance'].default_value=.09
links.new(noise.outputs['Fac'],bump.inputs['Height']); links.new(bump.outputs['Normal'],shader.inputs['Normal'])
rock.data.materials.append(material)
for variant in range(8):
    rock.rotation_euler=(.3+variant*.25,.5+variant*.39,.2+variant*.28)
    scene.render.filepath=str(SOURCE/f'meteor-{variant}.png'); bpy.ops.render.render(write_still=True)
    metadata[f'meteor-{variant}']={'origin':project((0,0,1.1))}
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'obsidian-meteor.blend'),compress=True)
(SOURCE/'projection.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('Rendered four glacial quartz formations and eight meteor rotations.')
