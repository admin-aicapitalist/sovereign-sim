"""Original clothed adult courtesans and tavern performances, using the character art helpers.

blender --background --python godot/tools/render_leisure_cast.py -- --output /tmp/sovereign-leisure-cast
The resulting loops are scenery; they never create combatants or change hero state.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_characters as c

KINDS = ('courtesan_red', 'courtesan_black', 'drinker', 'brawl')
FRAMES = 16


def hand(at, glove=False, open_hand=False):
    color = 'black' if glove else 'skin'
    c.ball(at, (.056, .039, .071), color, 8, 12)
    if open_hand:
        for i in range(4):
            root = Vector(at) + Vector((-.037+i*.023, -.012, .04))
            c.tube(root, root+Vector((-.018+i*.01, -.016, .072-abs(i-1.5)*.013)), .010, color, 6)
    c.ball(Vector(at)+Vector((.053, -.016, 0)), (.023, .021, .036), color, 6, 10)


def arm(shoulder, elbow, wrist, sleeve, glove=False, open_hand=False):
    c.limb(shoulder, elbow, .100, .068, sleeve)
    c.limb(elbow, wrist, .065, .035, 'skin')
    c.ball(shoulder, (.11, .115, .095), sleeve, 8, 12)
    hand(wrist, glove, open_hand)


def fan(at, phase, color):
    c.part('Performance / open fan, ribs and scalloped edge')
    at = Vector(at)
    points = []
    for i in range(12):
        a = -.95 + i/11*1.9 + math.sin(phase*2)*.28
        p = at + Vector((math.sin(a)*.34, -.05, math.cos(a)*.34))
        points.append(p)
        c.tube(at, p, .008, 'gold', 6)
    for i in range(11):
        c.poly([at+Vector((0,-.018,0)), points[i], points[i+1]], color if i%2 else 'wine')
    c.seam(points, 'gold', .008)


def courtesan(kind, phase):
    dress = 'red' if kind=='courtesan_red' else 'black'
    trim = 'black' if kind=='courtesan_red' else 'red'
    c.part('Costume / adult court dress with full skirt and fitted bodice')
    sway = math.sin(phase)*.045
    c.loft([(0,0,.12,.39,.27),(sway*.3,0,.49,.33,.23),(sway*.6,0,.88,.27,.19),
            (sway,0,1.20,.19,.14),(sway,0,1.34,.20,.15)], dress, 32, .11, phase)
    c.loft([(sway,0,1.25,.19,.14),(sway,0,1.49,.25,.17),(sway,0,1.68,.27,.16),
            (sway,0,1.77,.14,.11)], trim, 28, .02, phase)
    c.loft([(0,0,.13,.397,.275),(0,0,.17,.392,.273)], 'gold', 32, .08, phase)
    for i in range(5):
        z=1.30+i*.065
        c.seam([(sway-.065,-.16,z),(sway+.065,-.18,z+.055)], 'gold', .008)
        c.seam([(sway+.065,-.16,z),(sway-.065,-.18,z+.055)], 'gold', .008)
    c.part('Anatomy / face, neck, long coiffure and earrings')
    c.limb((sway,0,1.73),(sway,0,1.89),.076,.070,'skin')
    c.head((sway,0,2.00),hair='hair' if kind=='courtesan_red' else 'straw')
    hair='hair' if kind=='courtesan_red' else 'straw'
    for side in (-1,1):
        for i in range(4):
            x=sway+side*(.12+i*.015)
            c.seam([(x,.05,2.14),(x+side*.035,.085,1.97),(x+side*.04,.10,1.70)],hair,.025)
        c.ball((sway+side*.16,-.015,1.94),(.023,.015,.039),'gold',6,10)
    c.ball((sway+.12,-.07,2.18),(.060,.029,.043),'red',8,12)
    c.part('Performance / beckoning hand, wrist turn and fan gesture')
    wrist=(sway+.48+.09*math.sin(phase*2),-.20-.13*math.cos(phase*2),1.88+.11*math.sin(phase*2))
    arm((sway+.245,0,1.67),(sway+.43,-.02,1.51),wrist,dress,False,True)
    left=(sway-.33,-.29,1.44+.055*math.sin(phase*2+.8))
    arm((sway-.245,0,1.67),(sway-.41,-.04,1.33),left,dress,True)
    fan(left,phase,trim)
    c.part('Costume / shoes beneath the hem')
    for side in (-1,1): c.ball((side*.14,-.10,.075),(.07,.15,.06),'black',8,12)


def tavern_body(phase, shirt, lean=0, bald=False):
    c.part('Anatomy / planted boots and bent knees')
    for side in (-1,1):
        foot=Vector((side*.20,-.03 if side<0 else .11,.08))
        knee=Vector((side*.18,-.08,.53))
        c.limb((side*.14,0,1.04),knee,.12,.085,'hose')
        c.limb(knee,foot,.09,.065,'leatherDark')
        c.ball(foot+Vector((0,-.075,-.015)),(.095,.18,.065),'leatherDark',8,12)
    c.part('Costume / crumpled tavern shirt and leather belt')
    c.loft([(0,0,1.0,.24,.17),(0,lean*.4,1.24,.255,.185),(0,lean*.8,1.54,.31,.18),
            (0,lean,1.72,.17,.115)],shirt,28,.04,phase)
    c.belt(1.10,.25,.182)
    c.part('Anatomy / bearded adult face')
    c.limb((0,lean,1.68),(0,lean,1.84),.085,.075,'skin')
    c.head((0,lean,1.97),beard=True,hair='whitehair' if bald else 'hair')


def tankard(wrist, amount):
    c.part('Prop / raised tankard, metal hoops, ale and foam')
    at=Vector(wrist)+Vector((0,-.08,.045))
    tilt=Matrix.Rotation(-amount*.65,3,'X')
    # Transform this prop alone so the mug visibly tips as it reaches the mouth.
    before=set(c.G.parts)
    c.loft([(0,0,0,.09,.09),(0,0,.23,.10,.10)],'wood',16)
    for z in (.035,.195): c.loft([(0,0,z,.103,.103),(0,0,z+.024,.103,.103)],'iron',16)
    c.loft([(0,0,.228,.092,.092),(0,0,.238,.092,.092)],'ivory',16)
    c.seam([(.09,0,.17),(.16,0,.17),(.16,0,.055),(.09,0,.055)],'gold',.018)
    for key in set(c.G.parts)-before:
        vertices,_=c.G.parts[key]
        for i,p in enumerate(vertices): vertices[i]=tuple(at+tilt@Vector(p))


def drinker(phase):
    sip=(.5-.5*math.cos(phase))**1.2
    lean=.075*math.sin(phase)
    tavern_body(phase,'wine',lean,True)
    c.part('Performance / drinking, toasting and swaying')
    wrist=Vector((.39,-.28,1.16)).lerp(Vector((.10,lean-.28,1.88)),sip)
    arm((.27,lean*.8,1.61),(.43,-.08,1.28+sip*.16),wrist,'wine')
    arm((-.27,lean*.8,1.61),(-.35,.0,1.29),(-.22,-.12,1.10),'wine')
    tankard(wrist,sip)


def brawler(phase, side):
    strike=max(0,math.sin(phase))**3
    recoil=max(0,-math.sin(phase))**3
    lean=-.15*strike+.17*recoil
    shirt='linen' if side else 'red'
    tavern_body(phase,shirt,lean,bool(side))
    c.part('Performance / unarmed jab, guard, recoil and counterpunch')
    arm((.28,lean*.8,1.62),(.34,-.18-strike*.13,1.50),
        (.18,-.35-strike*.55,1.69-recoil*.08),shirt)
    arm((-.28,lean*.8,1.62),(-.40,-.12,1.35),(-.14,-.32,1.60),shirt)


def geometry(kind, phase):
    if kind!='brawl':
        c.G=c.geo.g=c.art.Geometry()
        courtesan(kind,phase) if kind.startswith('courtesan') else drinker(phase)
        return c.G
    combined=c.art.Geometry()
    for side in (0,1):
        c.G=c.geo.g=c.art.Geometry()
        brawler(phase+side*math.pi,side)
        rotation=Matrix.Rotation(-math.pi/2 if side else math.pi/2,3,'Z')
        offset=Vector((.64 if side else -.64,.12 if side else -.12,0))
        for (name,mat),(vertices,faces) in c.G.parts.items():
            combined.parts[(name+' / '+str(side),mat)]=([tuple(rotation@Vector(p)+offset) for p in vertices],faces)
    return combined


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--only',nargs='+',choices=KINDS,default=KINDS)
    parser.add_argument('--resolution',type=int,default=384)
    parser.add_argument('--samples',type=int,default=24)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output.mkdir(parents=True,exist_ok=True)
    for kind in args.only:
        bpy.ops.wm.read_factory_settings(use_empty=True);c.M.clear();c.materials()
        c.M['red']=c.art.weathered_material('Performance / rich crimson','bb1741',32)
        c.M['wine']=c.art.weathered_material('Performance / claret','741b35',32)
        c.M['black']=c.art.weathered_material('Performance / black velvet','171320',32)
        scene,project=c.setup(args.resolution,args.samples)
        camera=scene.camera;target=Vector((0,0,1.12))
        camera.location=target+Vector((18,-18,math.sqrt(648)*math.tan(math.radians(30))))
        camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale=4.6;scene.render.threads=6
        bpy.context.view_layer.update()
        (args.output/f'{kind}.json').write_text(json.dumps({'render_size':args.resolution,'logical_size':128,'anchor':project((0,0,0)),'frames':FRAMES,'fps':4})+'\n')
        objects=[]
        for frame in range(FRAMES):
            for obj in objects:
                mesh=obj.data;bpy.data.objects.remove(obj,do_unlink=True);bpy.data.meshes.remove(mesh)
            before=set(scene.objects);g=geometry(kind,frame/FRAMES*math.tau);g.finish()
            objects=list(set(scene.objects)-before)
            for obj in objects:
                for face in obj.data.polygons: face.use_smooth=True
            scene.render.filepath=str(args.output/f'{kind}-{frame:02d}.png')
            bpy.ops.render.render(write_still=True)
            print('PERFORMANCE',kind,frame,flush=True)


if __name__=='__main__': main()
