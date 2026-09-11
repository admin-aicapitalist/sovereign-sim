"""Original isometric woodland and scenery, using the kingdom's Blender lighting."""

import argparse
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_palace as art

ROOT = Path(__file__).resolve().parents[2]
TAU = math.tau
KEYS = ([f'pine{i}' for i in range(6)] + [f'oak{i}' for i in range(6)] +
        [f'rock{i}' for i in range(4)] + [f'shrub{i}' for i in range(3)] +
        [f'flowers{i}' for i in range(2)] + [f'grass{i}' for i in range(2)] +
        [f'reeds{i}' for i in range(2)] + ['stump', 'log', 'bridge-rail'])
g = None
rng = None
M = {}


def group(name):
    g.group = name


def branch(points, radius, taper=.16):
    for i, (a, b) in enumerate(zip(points, points[1:])):
        a,b=Vector(a),Vector(b)
        axis=(b-a).normalized();side=axis.cross(Vector((0,0,1)))
        if side.length<.01:side=Vector((1,0,0))
        side.normalize();other=axis.cross(side)
        r0=radius*(1-i/(len(points)-1)*(1-taper))
        r1=radius*(1-(i+1)/(len(points)-1)*(1-taper))
        lower=[a+(side*math.cos(j*TAU/9)+other*math.sin(j*TAU/9))*r0 for j in range(9)]
        upper=[b+(side*math.cos(j*TAU/9)+other*math.sin(j*TAU/9))*r1 for j in range(9)]
        for j in range(9):
            k=(j+1)%9;g.poly([lower[j],lower[k],upper[k],upper[j]],M['bark'][j%len(M['bark'])])
        g.poly(upper,M['bark'][1])


def leaf(center, length, width, direction, materials):
    c, v = Vector(center), Vector(direction).normalized()
    n = v.cross(Vector((0, 0, 1)))
    if n.length < .01:
        n = Vector((1, 0, 0))
    n.normalize()
    ridge = c + Vector((0, 0, width * .3))
    a, b = c - v * length * .48, c + v * length * .52
    l, r = c - n * width * .52, c + n * width * .52
    g.poly([a, l, b, ridge], rng.choice(materials))
    g.poly([a, ridge, b, r], rng.choice(materials))


def tuft(center, direction, size, materials):
    """A spray of pointed needles, with irregular tips rather than solid cones."""
    c, v = Vector(center), Vector(direction).normalized()
    side = v.cross(Vector((0, 0, 1))).normalized()
    if side.length < .01:
        side = Vector((1, 0, 0))
    for i in range(14):
        t = i / 14
        base = c + v * size * t
        spread = size * (.45 - .28 * t)
        for sign in (-1, 1):
            end = base + side * spread * sign + v * size * .23 + Vector((0, 0, rng.uniform(-.08, .12)))
            middle = base.lerp(end, .5)
            leaf(middle, (end - base).length, size * .055, end - base, materials)


def trunk(height, radius, lean=.08):
    group('Furrowed bark, roots and broken twigs')
    centers = [Vector((lean * math.sin(t * 2), lean * .3 * t, t * height)) for t in [i / 14 for i in range(15)]]
    sides = 14
    for i in range(14):
        a, b = centers[i:i + 2]
        r0, r1 = radius * (1 - i / 15) ** .7, radius * (1 - (i + 1) / 15) ** .7
        for j in range(sides):
            angles = [j * TAU / sides, (j + 1) * TAU / sides]
            pts = [a + Vector((math.cos(v) * r0, math.sin(v) * r0, 0)) for v in angles]
            pts += [b + Vector((math.cos(v) * r1, math.sin(v) * r1, 0)) for v in reversed(angles)]
            g.poly(pts, M['bark'][j % len(M['bark'])])
    for i in range(7):
        a = i * TAU / 7
        branch([(0, 0, .32), (math.cos(a) * radius * 1.6, math.sin(a) * radius * 1.6, .095),
                (math.cos(a) * radius * 2.9, math.sin(a) * radius * 2.9, .015)], radius * .42,.025)
    for i in range(26):
        a, z = rng.uniform(0, TAU), rng.uniform(.15, height * .55)
        rr = radius * (1 - z / height) ** .7
        g.rod((math.cos(a) * rr, math.sin(a) * rr, z),
              (math.cos(a + .07) * rr, math.sin(a + .07) * rr, z + rng.uniform(.12, .42)),
              .012, M['bark'][0], 4)


def pine(variant):
    height = [7.6, 7.0, 8.2, 6.8, 7.8, 6.9][variant]
    breadth = [2.05, 1.7, 1.65, 2.1, 1.85, 2.0][variant]
    trunk(height, .20, .11 + variant * .027)
    leaves = M['needles'] if variant != 4 else M['pineSun']
    for row in range(12):
        z = 1.35 + row * (height - 1.8) / 12
        span = breadth * (1 - row / 13) ** .72
        count = 8 if row < 8 else 6
        for j in range(count):
            angle = j * TAU / count + row * 2.43 + rng.uniform(-.22, .22)
            v = Vector((math.cos(angle), math.sin(angle), 0))
            base = Vector((.08 * math.sin(z), 0, z))
            end = base + v * span + Vector((0, 0, -.18 + rng.uniform(-.14, .14)))
            group('Whorled pine boughs')
            branch([base, base.lerp(end, .5) - Vector((0, 0, .15)), end], .055 * (1 - row / 15))
            group('Individual evergreen needle sprays')
            for k in range(7):
                t = .18 + k * .12
                c = base.lerp(end, t)
                side = Vector((-v.y, v.x, 0))
                for sign in (-1, 1):
                    direction = (v * .6 + side * sign * .8 + Vector((0, 0, rng.uniform(-.4, .1)))).normalized()
                    size = (.38 + span * .12) * (1 - t * .48)
                    tuft(c, direction, size, leaves)
            tuft(end, v + Vector((0, 0, .4)), .32, leaves)
    for z in (height - .65, height - .35, height - .15):
        for a in range(5):
            tuft((.08, 0, z), (math.cos(a * TAU / 5), math.sin(a * TAU / 5), .8), .28, leaves)


def foliage_cluster(center, radius, count, materials):
    cx, cy, cz = center
    rx, ry, rz = radius
    for _ in range(count):
        az, elev = rng.uniform(0, TAU), rng.uniform(-1, 1)
        rr = rng.random() ** .33
        side = math.sqrt(1 - elev * elev)
        point = (cx + math.cos(az) * side * rr * rx,
                 cy + math.sin(az) * side * rr * ry, cz + elev * rr * rz)
        direction = (math.cos(az + rng.uniform(-1, 1)), math.sin(az), rng.uniform(-.8, .8))
        leaf(point, rng.uniform(.17, .31), rng.uniform(.095, .16), direction, materials)


def oak(variant):
    height = [5.6, 5.2, 6.1, 5.0, 5.8, 5.5][variant]
    width = [2.1, 2.15, 2.0, 1.9, 2.25, 2.0][variant]
    colors = M['oakGold'] if variant == 3 else M['oakRust'] if variant == 1 else M['leaves']
    trunk(height * .78, .30, .23)
    for i in range(11):
        angle = i * 2.4
        radius = width * (.28 if i > 7 else .71)
        target = Vector((math.cos(angle) * radius, math.sin(angle) * radius,
                         height * (.77 if i < 8 else .98) + rng.uniform(-.25, .25)))
        root = Vector((0, 0, 1.8 + (i % 3) * .4))
        middle = root.lerp(target, .6)
        group('Twisting oak limbs and fine twigs')
        branch([root, middle, target], .16 if i < 8 else .11)
        for k in range(3):
            tip = target + Vector((math.cos(angle + k * 1.9) * .62, math.sin(angle + k * 1.9) * .62, .35))
            branch([middle, target, tip], .038)
        group('Layered individual oak leaves')
        foliage_cluster(target, (1.03, .94, .85), 540, colors)


def rock_shape(center, radius, height, moss=True):
    x, y, z = center
    n = 9
    rings = []
    for level, scale in ((0, .88), (.30, 1), (.76, .74), (1, .32)):
        rings.append([(x + math.cos(i * TAU / n) * radius * scale * rng.uniform(.83, 1.15),
                       y + math.sin(i * TAU / n) * radius * scale * rng.uniform(.74, 1.12),
                       z + height * level * rng.uniform(.88, 1.12)) for i in range(n)])
    for row in range(3):
        for j in range(n):
            k = (j + 1) % n
            g.poly([rings[row][j], rings[row][k], rings[row + 1][k]], rng.choice(M['stone']))
            g.poly([rings[row][j], rings[row + 1][k], rings[row + 1][j]], rng.choice(M['stone']))
    g.poly(rings[-1], M['stone'][-1])
    if moss:
        for i in range(12):
            a = rng.uniform(0, TAU)
            c = Vector((x + math.cos(a) * radius * .31, y + math.sin(a) * radius * .31, z + height * 1.015))
            leaf(c, rng.uniform(.09, .22), .09, (math.cos(a), math.sin(a), -.1), M['lichen'])


def rocks(variant):
    group('Fractured granite and lichen')
    rock_shape((0, 0, 0), [.7, .8, .5, .65][variant], [.63, .41, .85, .53][variant])
    for i in range(3 + variant):
        a, d = i * 2.4, rng.uniform(.48, .91)
        rock_shape((math.cos(a) * d, math.sin(a) * d, 0), rng.uniform(.10, .26), rng.uniform(.12, .26), False)


def grass_patch(variant, flowers=False):
    group('Meadow blades and wildflowers' if flowers else 'Long meadow grass')
    for i in range(65 if flowers else 90):
        a, r = rng.uniform(0, TAU), math.sqrt(rng.random()) * .70
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rng.uniform(.12, .40 if flowers else .48)
        lean = Vector((rng.uniform(-.13, .13), rng.uniform(-.13, .13), h))
        g.poly([(x-.011, y, 0), (x+.011, y, 0), (x+lean.x, y+lean.y, h)], rng.choice(M['grasses']))
        if flowers and i % 4 == 0:
            c = Vector((x + lean.x, y + lean.y, h))
            for j in range(5):
                angle = j * TAU / 5
                direction = Vector((math.cos(angle), math.sin(angle), .15))
                leaf(c + direction * .025, .07, .035, direction, M['flowerGold'] if variant else M['flowerIvory'])
            g.frustum(c.x, c.y, c.z, .017, .018, .022, M['pollen'], 7)


def shrub(variant):
    group('Hawthorn stems and leaves')
    for i in range(7):
        a = i * 2.4
        end = Vector((math.cos(a) * .46, math.sin(a) * .46, .42 + rng.random() * .42))
        branch([(0, 0, 0), end * .5, end], .023)
        foliage_cluster(end, (.41, .37, .37), 130, M['leaves'] if variant < 2 else M['oakGold'])
        if variant == 1:
            for _ in range(8):
                c = end + Vector((rng.uniform(-.21, .21), rng.uniform(-.21, .21), rng.uniform(.02, .21)))
                g.frustum(c.x, c.y, c.z, .025, .016, .04, M['berries'], 7)


def reeds(variant):
    group('Waterside reeds and cattails')
    for i in range(28):
        x, y = rng.uniform(-.49, .49), rng.uniform(-.32, .32)
        height = rng.uniform(.45, 1.22)
        tip = Vector((x + rng.uniform(-.21, .21), y + rng.uniform(-.15, .15), height))
        g.rod((x, y, 0), tip, .012, rng.choice(M['grasses']), 5)
        for side in (-1, 1):
            g.poly([(x, y, .05), (x+side*.027, y, height*.44),
                    (tip.x+side*.25, tip.y, height*.84)], rng.choice(M['grasses']))
        if i % 4 == variant:
            g.rod(tip - Vector((0, 0, .05)), tip + Vector((0, 0, .19)), .037, M['bark'][1], 9)


def deadwood(kind):
    group('Split wood, bark and growth rings')
    if kind == 'stump':
        trunk(.80, .40, .015)
        for i in range(6):
            g.frustum(0, 0, .791+i*.002, .32-i*.047, .32-i*.047, .004, M['wood'][i%3], 18)
        branch([(.05, .0, .42), (.59, .10, .76)], .08)
    else:
        a, b = Vector((-.95, .25, .25)), Vector((.9, -.2, .25))
        g.rod(a, b, .24, M['bark'][0], 12)
        direction = (b-a).normalized()
        for i in range(6):
            g.rod(b+direction*(.003+i*.003), b+direction*(.006+i*.003), .21-i*.031, M['wood'][i%3], 18)
        branch([(-.28,.1,.41),(-.14,.37,.68),(-.25,.59,.74)],.075)
        for i in range(15):
            x=rng.uniform(-.8,.7)
            leaf((x,.06,.48),.16,.13,(1,.1,.1),M['lichen'])


def rail():
    group('Aged oak bridge posts, rails and iron nails')
    for x in (-1, 1):
        g.box((x, 0, .42), (.13, .15, .84), M['wood'][0])
        g.box((x, 0, .86), (.19, .21, .065), M['wood'][1])
        for z in (.30, .65):
            g.rod((x,-.092,z),(x,-.106,z),.026,M['iron'],8)
    for z in (.29, .66):
        g.box((0,0,z),(2.06,.11,.11),M['wood'][1])
        for i in range(8):
            x=rng.uniform(-.97,.85)
            g.rod((x,-.058,z+.01),(x+.13,-.058,z+.016),.004,M['bark'][0],4)
    g.rod((-1,0,.26),(1,0,.65),.025,M['wood'][2],4)


def materials():
    theme = json.loads((ROOT / 'assets/art/palace/color-theme.json').read_text())['materials']
    palettes = {'bark':['514936','67543b','746346','887354','5b4f39'],
                'wood':theme['wood'], 'stone':['777c75','92968b','a5a99e','bcc0b0','aeb3a2'],
                'leaves':['536835','637b3c','738541','81944a','91a156'],
                'needles':['374f35','465f3d','557043','657e4b','738750'],
                'pineSun':['53643c','647443','7d8949','8b9651'],
                'oakGold':['89763c','a38c43','b49b4d','c0a65b','78804a'],
                'oakRust':['6e6b3d','92633a','a5753d','b18a47','7e783e'],
                'grasses':['626f38','7e8b45','94a055','a3a966','697d40'],
                'lichen':['78804c','92966b','a3a983'],
                'flowerIvory':['d5d2b5','ece3c3'], 'flowerGold':['c5a348','dcc06a']}
    for name, colors in palettes.items():
        M[name] = [art.weathered_material(name+str(i), color, 12 if name=='stone' else 35)
                   for i,color in enumerate(colors)]
    M['berries']=art.material('Hawthorn berries','9c4931')
    M['pollen']=art.material('Flower pollen','b79642')
    M['iron']=art.material('Old iron nails','424d47')


def setup(resolution, samples, key):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=samples
    scene.cycles.use_denoising=True;scene.cycles.max_bounces=5
    scene.render.threads_mode='FIXED';scene.render.threads=10
    scene.render.resolution_x=scene.render.resolution_y=resolution;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    world=bpy.data.worlds.new('Kingdom daylight');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.52,.62,.76,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
    light_data=bpy.data.lights.new('Warm afternoon key','AREA');light_data.energy=2600
    light_data.shape='DISK';light_data.size=6;light_data.color=(1,.93,.82)
    light=bpy.data.objects.new('Warm afternoon key',light_data);scene.collection.objects.link(light)
    light.location=(-7,-10,16);light.rotation_euler=(Vector((0,0,2))-light.location).to_track_quat('-Z','Y').to_euler()
    tree=key.startswith(('pine','oak'))
    logical=160 if tree else 96
    ortho=9.8 if tree else (96/32*math.sqrt(2) if key=='bridge-rail' else 5.4)
    target=Vector((0,0,3.55 if tree else .48))
    camera_data=bpy.data.cameras.new('Kingdom 30-degree camera')
    camera=bpy.data.objects.new('Kingdom 30-degree camera',camera_data);scene.collection.objects.link(camera)
    camera.location=target+Vector((18,-18,math.sqrt(18**2+18**2)*math.tan(math.radians(30))))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO';camera_data.ortho_scale=ortho;scene.camera=camera
    bpy.context.view_layer.update()
    p=world_to_camera_view(scene,camera,Vector((0,0,0)))
    return scene, {'logical_size':[logical,logical], 'ground_anchor_normalized':[p.x,1-p.y],
                   'ortho_scale':ortho, 'camera_elevation_degrees':30,
                   'shadow_radius':23 if tree else 10 if key.startswith('rock') else 12 if key=='log' else 8}


def main():
    global g,rng
    parser=argparse.ArgumentParser()
    parser.add_argument('--resolution',type=int,default=1280)
    parser.add_argument('--samples',type=int,default=48)
    parser.add_argument('--only',nargs='*',choices=KEYS)
    parser.add_argument('--output',type=Path,default=ROOT/'assets/art/environment/source')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output.mkdir(parents=True,exist_ok=True)
    for key in args.only or KEYS:
        bpy.ops.wm.read_factory_settings(use_empty=True);M.clear();materials()
        rng=random.Random(8831+sum((i+1)*ord(c) for i,c in enumerate(key)))
        g=art.Geometry()
        if key.startswith('pine'):pine(int(key[-1]))
        elif key.startswith('oak'):oak(int(key[-1]))
        elif key.startswith('rock'):rocks(int(key[-1]))
        elif key.startswith('shrub'):shrub(int(key[-1]))
        elif key.startswith('flowers'):grass_patch(int(key[-1]),True)
        elif key.startswith('grass'):grass_patch(int(key[-1]))
        elif key.startswith('reeds'):reeds(int(key[-1]))
        elif key=='bridge-rail':rail()
        else:deadwood(key)
        g.finish()
        scene,meta=setup(args.resolution,args.samples,key)
        meta.update({'key':key,'render_size':[args.resolution,args.resolution]})
        scene.render.filepath=str(args.output/f'{key}-render.png')
        bpy.ops.render.render(write_still=True)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(args.output/f'{key}.blend'))
        (args.output/f'{key}.json').write_text(json.dumps(meta,indent=2)+'\n')
        print('Rendered',key,flush=True)


if __name__=='__main__':
    main()
