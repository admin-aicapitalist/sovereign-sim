"""Original medieval character miniatures, authored and animated in Blender.

blender --background --python godot/tools/render_characters.py -- --only warrior
The geometry helpers are shared with the original art; the characters, costumes,
anatomy, poses and lighting are authored here. No third-party game assets.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/art'))
import render_palace as art
import render_units as geo

TAU = math.tau
TYPES = [*geo.TYPES, 'warlord']
ANIMATIONS = {'idle': 4, 'walk': 8, 'attack': 6}
M = {}
G = None
SOCKETS = {}


def part(name):
    G.group = name


def ball(c, r, material, rings=10, sides=16):
    geo.ellipsoid(c, r, M[material], rings, sides)


def tube(a, b, r, material, sides=10):
    G.rod(a, b, r, M[material], sides)


def limb(a, b, r1, r2, material):
    geo.limb(a, b, r1, r2, M[material])


def poly(points, material):
    G.poly(points, M[material])


def box(c, size, material):
    G.box(c, size, M[material])


def cone(c, r, end, material, sides=10):
    a, b = Vector(c), Vector(end)
    axis = b - a
    tangent = axis.cross(Vector((0, 1, 0))).normalized()
    if tangent.length < .01:
        tangent = Vector((1, 0, 0))
    other = axis.normalized().cross(tangent)
    for i in range(sides):
        p = a + r * (math.cos(TAU*i/sides)*tangent + math.sin(TAU*i/sides)*other)
        q = a + r * (math.cos(TAU*(i+1)/sides)*tangent + math.sin(TAU*(i+1)/sides)*other)
        poly([p, q, b], material)


def loft(rings, material, sides=24, folds=0, phase=0):
    if not folds:
        geo.loft(rings, M[material], sides)
        return
    # Real fold geometry, including the changing cloth hem, survives small renders.
    vertices, faces = G.parts.setdefault((G.group, M[material].name), ([], []))
    start = len(vertices)
    for row, (x,y,z,rx,ry) in enumerate(rings):
        for col in range(sides):
            a = TAU*col/sides
            wave = 1 + folds*math.cos(a*10 + phase*.22) * (1-row/len(rings)*.55)
            vertices.append((x+rx*math.cos(a)*wave, y+ry*math.sin(a)*wave, z))
    for row in range(len(rings)-1):
        for i in range(sides):
            faces.append(tuple(start+k for k in (row*sides+i, row*sides+(i+1)%sides,
                (row+1)*sides+(i+1)%sides, (row+1)*sides+i)))


def seam(points, material='gold', radius=.008):
    for a,b in zip(points, points[1:]):
        tube(a,b,radius,material,6)


def strap(a, b, width=.06, material='leather'):
    a,b = Vector(a),Vector(b)
    d=(b-a).normalized(); across=Vector((d.z,0,-d.x))*width/2
    poly([a-across,a+across,b+across,b-across],material)
    seam([a-across,b-across], 'stitch', .003)
    seam([a+across,b+across], 'stitch', .003)


def buckle(x,y,z,s=.075):
    for dx in (-s/2,s/2): tube((x+dx,y,z-s/2),(x+dx,y,z+s/2),.010,'gold',6)
    for dz in (-s/2,s/2): tube((x-s/2,y,z+dz),(x+s/2,y,z+dz),.010,'gold',6)
    tube((x,y-.008,z-s/2),(x,y-.008,z+s/2),.007,'gold',6)


def belt(z, width=.245, depth=.155, color='leather'):
    loft([(0,0,z-.036,width,depth),(0,0,z+.036,width,depth)],color)
    buckle(.025,-depth-.018,z)
    for i in range(5): ball((-.15+i*.06,-depth-.008,z),(.007,.005,.007),'gold',4,6)


def pouch(x,y,z,s=.10, color='leather'):
    loft([(x,y,z-s,s*.65,s*.48),(x,y,z-s*.65,s,s*.60),
          (x,y,z+s*.70,s,s*.6),(x,y,z+s,s*.70,s*.45)],color)
    box((x,y-s*.61,z+s*.46),(s*1.6,.017,s*.62),'leatherLight')
    buckle(x,y-s*.71,z+s*.35,s*.4)


def cloak(z, length, width, color, phase, trim=False, ragged=False):
    part('Tailored cloak / wind and scalloped folds')
    def point(u,t):
        return (u*width*(.76+t*.32), .17+.23*t+.055*math.sin(u*9+phase*.7)*t,
                z-length*t+.028*math.cos(u*12)*t + (.07*math.sin(u*21)*t**8 if ragged else 0))
    for row in range(12):
        for col in range(20):
            a,b=row/12,(row+1)/12; u,v=-1+col*.1,-.9+col*.1
            poly([point(u,a),point(v,a),point(v,b),point(u,b)],color)
    if trim:
        for u in (-1,1): seam([point(u,i/12) for i in range(13)],'gold',.012)
        seam([point(-1+i*.1,1) for i in range(21)],'gold',.011)


def head(center, kind='human', hair='hair', beard=False):
    x,y,z=center; skin='goblin' if kind=='goblin' else 'skin'
    gob=kind=='goblin'
    part('Anatomy / jaw, cheekbones, brow and recessed eyes')
    loft([(x,y-.008,z-.20,.080,.08),(x,y-.028,z-.16,.122,.104),
          (x,y,z-.045,.148,.130),(x,y+.008,z+.075,.143,.132),
          (x,y+.012,z+.17,.117,.111),(x,y+.018,z+.207,.047,.053)],skin)
    for side in (-1,1):
        ball((x+side*.071,y-.117,z+.025),(.044,.021,.028),'socket',6,10)
        ball((x+side*.071,y-.135,z+.023),(.025,.008,.011),'eye' if not gob else 'amber',6,10)
        ball((x+side*.068,y-.143,z+.023),(.008,.005,.009),'black',4,8)
        seam([(x+side*.039,y-.132,z+.060),(x+side*.099,y-.118,z+.069)],hair,.018)
        ball((x+side*.102,y-.100,z-.052),(.055,.046,.046),skin,6,10)
        if gob:
            cone((x+side*.132,y,z+.025),.073,(x+side*.36,y+.10,z+.22),skin)
            poly([(x+side*.148,y-.04,z+.045),(x+side*.305,y+.05,z+.18),
                  (x+side*.15,y-.024,z-.037)],'ear')
        else:
            ball((x+side*.143,y+.015,z-.025),(.028,.032,.053),skin,8,10)
            ball((x+side*.16,y-.01,z-.019),(.009,.009,.024),'ear',6,8)
    # Angular nose and philtrum; no spherical cartoon muzzle.
    poly([(x-.029,y-.113,z+.09),(x+.029,y-.113,z+.09),
          (x+.038,y-.165,z-.054),(x,y-.207,z-.034),(x-.038,y-.165,z-.054)],skin)
    seam([(x-.044,y-.126,z-.108),(x,y-.145,z-.115),(x+.044,y-.126,z-.108)],'lip',.009)
    if gob:
        for s in (-1,1): cone((x+s*.057,y-.144,z-.137),.022,(x+s*.050,y-.174,z-.062),'bone',8)
    if beard:
        for i in range(9):
            dx=(i-4)*.027
            cone((x+dx,y-.095,z-.085),.040,(x+dx*.62,y-.12,z-.23-.14*(1-abs(dx)/.15)),hair,8)
    else:
        # Sideburns and layered locks follow the skull, rather than a ball on top.
        loft([(x,y+.022,z+.08,.153,.13),(x,y+.023,z+.19,.126,.116),
              (x,y+.025,z+.219,.050,.055)],hair)
        for s in (-1,1): ball((x+s*.133,y+.04,z-.061),(.035,.071,.102),hair,6,10)


def hood(z, color, pointed=False):
    part('Cowl / opening, folded shoulders and pointed hood')
    # Open front: the face is actually exposed between the two sides of the hood.
    rings=[(z-.20,.19,.17),(z-.04,.196,.176),(z+.14,.179,.17),(z+.25,.10,.12)]
    for row in range(3):
        for i in range(20):
            a=-.63+4.40*i/20; b=-.63+4.40*(i+1)/20
            za,rx,ry=rings[row]; zb,qx,qy=rings[row+1]
            poly([(rx*math.cos(a),ry*math.sin(a)+.02,za),(rx*math.cos(b),ry*math.sin(b)+.02,za),
                  (qx*math.cos(b),qy*math.sin(b)+.02,zb),(qx*math.cos(a),qy*math.sin(a)+.02,zb)],color)
    for side in (-1,1):
        seam([(side*.16,-.082,z-.20),(side*.185,-.075,z-.04),(side*.167,-.065,z+.13),(side*.086,-.041,z+.25)],'stitch',.009)
    cone((0,.06,z+.22),.105,(0,.24 if pointed else .09,z+.34),color,16)
    loft([(0,0,z-.34,.36,.235),(0,.02,z-.17,.19,.18)],color,32,.06)


def helm(z, closed=False):
    part('Steel / forged bascinet and articulated visor' if closed else 'Steel / kettle helm and nasal guard')
    loft([(0,.018,z-.012,.167,.155),(0,.020,z+.15,.167,.15),
          (0,.037,z+.24,.103,.092),(0,.055,z+.295,.015,.025)],'steel',24)
    seam([(0,-.13,z+.09),(0,-.11,z+.20),(0,.055,z+.295),(0,.165,z+.12)],'edge',.014)
    if closed:
        poly([(-.157,-.086,z+.042),(.157,-.086,z+.042),(.112,-.193,z-.122),
              (0,-.23,z-.168),(-.112,-.193,z-.122)],'steel')
        for side in (-1,1):
            poly([(side*.018,-.190,z+.013),(side*.124,-.140,z+.029),
                  (side*.120,-.158,z-.004),(side*.018,-.204,z-.015)],'black')
            for i in range(3): ball((side*(.045+i*.028),-.208+i*.006,z-.084),(.008,.006,.010),'black',4,6)
        seam([(0,-.190,z+.04),(0,-.23,z-.168)],'edge',.010)
    else:
        loft([(0,.018,z+.016,.235,.207),(0,.018,z+.039,.167,.157)],'steel')
        box((0,-.187,z-.015),(.032,.025,.15),'edge')
        for side in (-1,1):
            poly([(side*.158,-.025,z+.018),(side*.153,-.08,z-.15),(side*.10,-.12,z-.17),(side*.12,-.125,z+.01)],'steel')
    for i in range(12):
        a=TAU*i/12
        ball((.169*math.cos(a),.018+.155*math.sin(a),z+.057),(.010,.010,.010),'gold',4,6)


def pauldron(c, size=1, color='steel'):
    x,y,z=c
    part('Steel / overlapping shoulder lames, rolled edges and rivets')
    for i in range(3):
        zz=z-i*.071*size; w=(.19-i*.018)*size; d=.202*size
        loft([(x,y,zz,w,d),(x,y,zz+.055*size,w*.97,d*.98),
              (x,y,zz+.112*size,w*.52,d*.75)],color,16)
        for a in (-2.4,-1.57,-.75):
            ball((x+w*math.cos(a),y+d*math.sin(a)-.005,zz+.026*size),(.011*size,)*3,'gold',4,6)


def shield(hand, color='red', round=False, battered=False):
    x,y,z=hand; y-=.11
    part('Equipment / bowed shield, rim, rivets and painted heraldry')
    shape=[(.34*math.cos(i*TAU/24),.34*math.sin(i*TAU/24)) for i in range(24)] if round else [(-.29,.35),(.29,.35),(.27,.03),(.16,-.28),(0,-.43),(-.16,-.28),(-.27,.03)]
    edge=[(x+u,y,z+v) for u,v in shape]; middle=(x,y-.075,z)
    for i in range(len(edge)):
        j=(i+1)%len(edge)
        poly([edge[i],edge[j],middle],color)
        tube(edge[i],edge[j],.017,'rust' if battered else 'gold',8)
        if i%2==0: ball((edge[i][0]*.92+x*.08,y-.01,z+(edge[i][2]-z)*.9),(.012,)*3,'gold',4,6)
    if round:
        ball((x,y-.082,z),(.072,.04,.072),'rust' if battered else 'steel',8,12)
        for dx in (-.16,.16): seam([(x+dx,y-.027,z-.27),(x+dx,y-.03,z+.27)],'leatherDark',.007)
    else:
        poly([(x-.042,y-.089,z+.30),(x+.042,y-.089,z+.30),(x+.035,y-.087,z-.27),
              (x,y-.081,z-.33),(x-.035,y-.087,z-.27)],'ivory')
        poly([(x-.21,y-.058,z+.16),(x+.21,y-.058,z+.16),(x+.21,y-.060,z+.08),(x-.21,y-.060,z+.08)],'ivory')
        for side in (-1,1):
            cone((x+side*.13,y-.049,z-.06),.048,(x+side*.13,y-.051,z+.04),'gold',6)
    if battered:
        for i in range(4): seam([(x-.22+i*.12,y-.065,z+.18),(x-.20+i*.12,y-.077,z-.10)],'woodLight',.008)


def blade(hand, axis, length=.94, rust=False, dagger=False):
    h=Vector(hand); v=Vector(axis).normalized(); t=Vector((1,0,0)); n=v.cross(t).normalized()
    base=h+v*.13; tip=base+v*length
    width=.064 if dagger else .053
    part('Equipment / diamond-section blade, fuller and bound grip')
    for sign in (-1,1):
        ridge=n*.026*sign
        poly([base-t*width,base+ridge,tip,base+v*length*.78-t*width*.7],'rust' if rust else 'edge')
        poly([base+ridge,base+t*width,base+v*length*.78+t*width*.7,tip],'rust' if rust else 'steel')
    tube(h-t*.14+v*.13,h+t*.14+v*.13,.023,'gold',8)
    tube(h-v*.10,h+v*.10,.028,'leatherDark',10)
    for i in range(5): tube(h-v*.08+v*i*.034-t*.028,h-v*.08+v*i*.034+t*.028,.007,'leatherLight',6)
    ball(h-v*.13,(.038,)*3,'gold',6,10)


def interpolate(points,t):
    p=min(len(points)-1.000001,max(0,t)*(len(points)-1)); i=int(p); f=p-i
    f=f*f*(3-2*f)
    return tuple(Vector(points[i]).lerp(Vector(points[i+1]),f))


def motion(animation, frame):
    phase=TAU*frame/ANIMATIONS[animation]
    walk=animation=='walk'; attack=animation=='attack'
    stride=math.cos(phase)*.31 if walk else .025
    bob=.028*math.cos(phase*2) if walk else .009*math.sin(phase) if not attack else 0
    return phase,stride,bob,frame/5 if attack else -1


def humanoid(kind,animation,frame):
    phase,stride,bob,attack=motion(animation,frame)
    armored=kind in ('warrior','guard'); skel=kind=='skeleton'; gob=kind=='goblin'
    wizard=kind=='wizard'; worker=kind=='peasant'; collector=kind=='collector'
    color={'warrior':'red','guard':'blue','ranger':'olive','wizard':'blue','peasant':'linen',
           'collector':'wine','thief':'ink','goblin':'goblin','skeleton':'bone'}[kind]
    skin='bone' if skel else 'goblin' if gob else 'skin'
    part('Anatomy / balanced stance, boots and articulated knees')
    feet={}
    for side in (-1,1):
        lift=max(0,math.sin(phase+(math.pi if side<0 else 0)))*.19 if animation=='walk' else 0
        foot=Vector((side*.155,side*stride,.086+lift)); feet[side]=foot
        knee=Vector((side*.168,side*stride*.48-.042,.55+bob*.25+lift*.36))
        hip=(side*.135,0,1.025+bob)
        limb(hip,knee,.070 if skel else .112,.049 if skel else .084,skin if skel or gob else 'hose' if worker else 'leatherDark')
        if skel:
            for dx in (-.027,.027): limb(knee+Vector((dx,0,0)),foot+Vector((dx,0,0)),.030,.022,'bone')
        else:
            limb(knee,foot,.095,.064,'goblin' if gob else 'leather')
            if armored:
                mid=knee.lerp(foot,.49)
                limb(knee+Vector((0,-.054,-.08)),mid+Vector((0,-.055,-.02)),.091,.073,'steel')
                ball(knee+Vector((0,-.069,0)),(.105,.075,.085),'steel',8,12)
                cone(knee+Vector((side*.08,-.04,0)),.06,knee+Vector((side*.17,-.05,.035)),'edge',6)
            else:
                for zz in (.24,.36):
                    center=knee.lerp(foot,zz/.5)
                    limb(center,center+Vector((0,0,.033)),.088,.088,'leatherLight')
        ball(foot+Vector((0,-.079,-.022)),(.075 if skel else .092,.180,.052 if skel else .066),skin if skel or gob else 'leatherDark',8,12)
        if armored:
            for i in range(3): box(foot+Vector((0,-.045-i*.048,.012-i*.01)),(.166-i*.017,.049,.045),'steel')
        if skel or gob:
            for i in range(3): cone(foot+Vector((-.05+i*.05,-.17,-.015)),.018,foot+Vector((-.05+i*.05,-.24,-.025)),'bone',6)
    part('Costume / sculpted doublet and pleated skirts')
    if skel:
        # Open rib cage, paired arm bones and a visible spine, not a white tunic.
        limb((0,.07,1.02+bob),(0,.055,1.67+bob),.042,.034,'bone')
        for i in range(6):
            z=1.29+bob+i*.060; w=.16+math.sin(i/5*math.pi)*.105
            for side in (-1,1):
                seam([(side*.025,.08,z+.025),(side*w,.02,z+.005),(side*w,-.095,z-.015),
                      (side*.065,-.16,z-.025),(side*.021,-.15,z-.005)],'bone',.019)
        for side in (-1,1):
            ball((side*.105,.015,1.05+bob),(.115,.11,.069),'bone',6,10)
            limb((0,-.105,1.63+bob),(side*.30,0,1.68+bob),.026,.036,'bone')
        loft([(0,0,.82,.255,.17),(0,0,1.09+bob,.22,.16)],'teal',24,.16,phase)
    else:
        loft([(0,0,1.025+bob,.225,.146),(0,0,1.20+bob,.232,.156),
              (0,.006,1.43+bob,.285,.178),(0,.02,1.62+bob,.322,.17),
              (0,.014,1.72+bob,.19,.115)],'chain' if armored else color,32,.025,phase)
        if not gob:
            bottom=.91 if worker else .74 if collector else .84
            loft([(0,.018,bottom,.295,.21),(0,0,1.03+bob,.245,.16),(0,0,1.21+bob,.234,.162)],color,40,.085,phase)
    if armored:
        part('Steel / tapered breastplate, waist lames and gorget')
        loft([(0,-.02,1.21+bob,.238,.178),(0,-.025,1.45+bob,.287,.205),
              (0,-.004,1.62+bob,.295,.189),(0,.015,1.69+bob,.195,.127)],'steel',24)
        seam([(0,-.202,1.21+bob),(0,-.235,1.47+bob),(0,-.134,1.69+bob)],'edge',.013)
        for i in range(3):
            loft([(0,-.005,1.075+i*.045+bob,.255-i*.007,.176),
                  (0,-.005,1.11+i*.045+bob,.252-i*.007,.174)],'steel')
        loft([(0,0,1.66+bob,.185,.132),(0,0,1.76+bob,.124,.106)],'steel')
        # Heraldic cloth hangs through the articulated armor, front and back.
        for side in (-1,1):
            for y in (-.192,.185):
                poly([(side*.04,y,1.17+bob),(side*.198,y,1.17+bob),
                      (side*.24,y+.026*math.sin(phase),.78),(side*.06,y,.73)],color if side<0 else 'ivory')
                seam([(side*.04,y-.005,1.16+bob),(side*.06,y-.005,.73),(side*.24,y-.005,.78)],'gold',.009)
        cloak(1.65+bob,.83,.33,'red' if kind=='warrior' else 'blue',phase,True)
    elif kind in ('ranger','thief'):
        loft([(0,-.016,1.18+bob,.245,.17),(0,-.01,1.52+bob,.29,.185),
              (0,0,1.67+bob,.25,.15)],'leather' if kind=='ranger' else 'leatherDark')
        for i in range(7):
            z=1.27+i*.046+bob
            seam([(-.05,-.187,z),( .05,-.187,z+.033)],'stitch',.006)
            seam([(.05,-.189,z),(-.05,-.189,z+.033)],'stitch',.006)
        strap((-.24,-.15,1.64+bob),(.21,-.176,1.16+bob),.085)
        buckle(.015,-.211,1.39+bob,.075)
        cloak(1.67+bob,.95,.37,'olive' if kind=='ranger' else 'ink',phase,False,kind=='thief')
    elif worker:
        # Broad apron, rolled cuffs, visible tools, woven straw hat.
        poly([(-.18,-.166,1.48+bob),(.18,-.166,1.48+bob),(.24,-.23,.79),(-.24,-.23,.79)],'leather')
        strap((-.18,-.173,1.48+bob),(-.11,-.116,1.73+bob),.033,'leatherLight')
        strap((.18,-.173,1.48+bob),(.11,-.116,1.73+bob),.033,'leatherLight')
        seam([(-.23,-.235,.82),(.23,-.235,.82)],'stitch',.007)
        box((.035,-.231,1.05+bob),(.19,.02,.14),'leatherLight')
    elif collector:
        for side in (-1,1):
            poly([(side*.27,-.14,1.62+bob),(side*.09,-.17,1.37+bob),
                  (side*.029,-.18,1.55+bob),(side*.09,-.12,1.73+bob)],'ivory')
        for i in range(5): ball((0,-.177,1.26+i*.070+bob),(.016,.009,.016),'gold',6,8)
        seam([(-.26,-.14,1.56+bob),(.26,-.14,1.56+bob)],'gold',.010)
    elif wizard:
        loft([(0,0,.13,.39,.27),(0,.035,.40,.345,.255),(0,.015,.90,.29,.22),
              (0,0,1.24+bob,.24,.17)],'blue',48,.09,phase)
        for z,w,d in [(.16,.40,.28),(.24,.385,.275)]:
            loft([(0,0,z,w,d),(0,0,z+.024,w,d)],'gold',48,.035,phase)
        for s in (-1,1):
            poly([(s*.035,-.175,1.62+bob),(s*.15,-.16,1.60+bob),(s*.27,-.255,.28),(s*.12,-.28,.28)],'wine')
            seam([(s*.035,-.184,1.62+bob),(s*.12,-.285,.28)],'gold',.014)
        cloak(1.71+bob,1.24,.43,'wine',phase,True)
        loft([(0,0,1.51+bob,.37,.235),(0,.03,1.73+bob,.14,.115)],'blue',32,.08)
        ball((0,-.195,1.56+bob),(.049,.018,.049),'gold',8,12)
        ball((0,-.215,1.56+bob),(.027,.014,.033),'jewel',8,10)
    elif gob:
        strap((-.24,-.19,1.64+bob),(.2,-.18,1.12+bob),.13)
        loft([(0,0,.79,.28,.20),(0,0,1.16+bob,.235,.165)],'wine',32,.15,phase)
    if not wizard:
        belt(1.15+bob,.259 if armored else .245,.192 if armored else .175)
        if not skel: pouch(.23,.015,1.05+bob,.096)
    headz=1.995+bob
    head_parts=set(G.parts)
    part('Anatomy / neck and collar')
    limb((0,.01,1.64+bob),(0,.008,1.90+bob),.083,.079,skin)
    if skel:
        skull(headz)
        # Broken iron cap and a torn mantle make the skeleton readable from behind.
        loft([(0,.02,headz+.064,.174,.157),(0,.015,headz+.18,.138,.13),(0,.03,headz+.245,.055,.06)],'rust')
        cloak(1.66+bob,.55,.28,'teal',phase,False,True)
    else:
        head((0,0,headz),'goblin' if gob else 'human','whitehair' if wizard else 'hair',wizard)
    if armored:
        helm(headz,kind=='warrior')
        if kind=='warrior':
            for i in range(6):
                ball((0,.05+i*.037,headz+.34-i*.012),(.045,.055,.09-i*.006),'red',6,10)
        else:
            cone((0,.06,headz+.25),.075,(0,.21,headz+.50),'blue',12)
    elif kind in ('ranger','thief'):
        hood(headz,'olive' if kind=='ranger' else 'ink',kind=='ranger')
        if kind=='thief':
            poly([(-.139,-.07,headz-.055),(.139,-.07,headz-.055),(.09,-.151,headz-.17),(0,-.17,headz-.21),(-.09,-.151,headz-.17)],'ink')
            strap((-.29,-.16,1.48+bob),(-.22,-.18,1.35+bob),.11,'red')
    elif worker or collector:
        part('Costume / woven brim or merchant cap with feather')
        loft([(0,.015,headz+.13,.30 if worker else .21,.26 if worker else .20),
              (0,.015,headz+.17,.18,.16),(0,.015,headz+.27,.159,.145),
              (0,.015,headz+.29,.085,.08)],'straw' if worker else 'ink',32)
        loft([(0,.015,headz+.18,.185,.166),(0,.015,headz+.213,.18,.165)],'leatherDark' if worker else 'wine')
        if worker:
            for i in range(32):
                a=i*TAU/32
                seam([(.19*math.cos(a),.015+.166*math.sin(a),headz+.158),
                      (.296*math.cos(a),.015+.255*math.sin(a),headz+.133)],'stitch',.004)
        else:
            for i in range(8):
                ball((-.16-i*.008,.055+i*.014,headz+.21+i*.042),(.032,.02,.061),'ivory',6,8)
            seam([(-.15,.05,headz+.18),(-.22,.16,headz+.52)],'gold',.005)
    elif wizard:
        part('Costume / bent felt hat, embroidered band and brass stars')
        loft([(0,.01,headz+.12,.31,.27),(0,.01,headz+.16,.19,.17),
              (0,.018,headz+.30,.165,.151),(.016,.04,headz+.49,.105,.095),
              (.045,.075,headz+.67,.054,.05),(.14,.1,headz+.74,.008,.008)],'blue',32)
        loft([(0,.01,headz+.17,.194,.176),(0,.013,headz+.217,.187,.17)],'gold',32)
        for i in range(4): ball((-.1+i*.065,-.151,headz+.24+(.09 if i%2 else 0)),(.013,.007,.017),'gold',4,6)
    elif gob:
        loft([(0,.035,headz+.075,.16,.143),(0,.055,headz+.20,.13,.12),(.02,.09,headz+.25,.075,.07)],'wine')
    if not skel and not gob:
        # Human proportions: a smaller head avoids the old toy-soldier silhouette.
        for key in set(G.parts)-head_parts:
            vertices,_=G.parts[key]
            for i,(x,y,z) in enumerate(vertices):
                vertices[i]=(x*.87,y*.87,1.77+bob+(z-1.77-bob)*.90)
    # Hands and weapons follow continuous pose arcs; gait swings the arms opposite the legs.
    swing=math.cos(phase)*.20 if animation=='walk' else 0
    left=(-.43,-.13-swing,1.16+bob); right=(.43,-.11+swing,1.13+bob); axis=(0,-.2,1)
    if attack>=0:
        right=interpolate([(.43,-.10,1.36),(.36,.09,2.07),(.43,-.78,1.25),(.44,-.28,1.06)],attack)
        axis=interpolate([(0,-.2,1),(0,.65,1),(0,-1,-.15),(0,-.3,1)],attack)
        left=(-.40,-.31,1.26)
    if kind=='ranger':
        left=(-.26,-.57 if attack>=0 else -.27,1.47 if attack>=0 else 1.20+bob)
        right=interpolate([(-.20,-.45,1.45),(.12,-.08,1.49),(.14,-.03,1.48),(-.07,-.45,1.42)],attack) if attack>=0 else (.38,-.17+swing,1.15+bob)
    elif wizard:
        right=(.43,-.16,1.30+bob)
        left=interpolate([(-.39,-.15,1.23),(-.43,-.24,1.82),(-.38,-.72,1.53),(-.44,-.38,1.22)],attack) if attack>=0 else (-.42,-.13-swing,1.19+bob)
        if animation=='cast':
            t=frame/(ANIMATIONS['cast']-1)
            right=interpolate([(.43,-.16,1.30),(.36,-.04,1.53),(.36,-.22,1.65),(.42,-.35,1.41),(.43,-.16,1.30)],t)
            left=interpolate([(-.42,-.13,1.19),(-.27,-.24,1.58),(-.22,-.38,1.99),(-.42,-.84,1.60),(-.42,-.13,1.19)],t)
    elif collector:
        left=(-.36,-.32,1.24+bob); right=(.40,-.16+swing,1.11+bob)
    for side,hand in ((-1,left),(1,right)):
        part('Anatomy / elbows, forearms and individual fingers')
        shoulder=Vector((side*.303,.015,1.62+bob)); hand=Vector(hand)
        elbow=shoulder.lerp(hand,.53)+Vector((side*.092,.032,-.073))
        sleeve='chain' if armored else 'linen' if collector else color
        if worker:
            limb(shoulder,elbow,.115,.109,'linen')
            limb(elbow,elbow.lerp(hand,.17),.115,.114,'ivory')
            limb(elbow.lerp(hand,.16),hand,.078,.049,'skin')
        elif skel:
            limb(shoulder,elbow,.036,.042,'bone')
            for dx in (-.022,.022): limb(elbow+Vector((dx,0,0)),hand+Vector((dx,0,0)),.024,.016,'bone')
        else:
            limb(shoulder,elbow,.123 if wizard else .104,.143 if wizard else .084,sleeve)
            limb(elbow,hand,.134 if wizard else .082,.12 if wizard else .053,sleeve)
        if armored:
            pauldron(shoulder+Vector((side*.035,0,.016)))
            limb(elbow.lerp(hand,.2),elbow.lerp(hand,.84),.093,.070,'steel')
            ball(elbow+Vector((0,-.025,0)),(.095,.08,.079),'steel',8,12)
        elif kind in ('ranger','thief','goblin'):
            limb(elbow.lerp(hand,.36),elbow.lerp(hand,.85),.090,.068,'leatherDark')
            for t in (.39,.77):
                center=elbow.lerp(hand,t); direction=(hand-elbow).normalized()
                # Flat buckled straps, not spherical metal cuffs.
                tube(center-direction*.012,center+direction*.012,.083,'leatherLight',12)
                ball(center+Vector((0,-.082,0)),(.018,.009,.018),'gold',4,6)
        ball(hand,(.057,.052,.073),'steel' if armored else skin,8,12)
        for i in range(3): ball(hand+Vector((-.036+i*.027,-.042,-.01)),(.015,.022,.041),'steel' if armored else skin,6,8)
    if kind=='warrior':
        blade(right,axis,1.02); shield(left)
    elif kind=='guard':
        part('Equipment / long ash halberd with hooked steel head')
        h=Vector(right); v=Vector(axis).normalized(); end=h+v*1.35
        tube(h-v*.98,end,.024,'wood')
        cone(end,.047,end+v*.29,'edge',6)
        poly([end-v*.08,end+Vector((.23,0,-.13)),end+Vector((.26,0,-.46)),end-v*.41],'steel')
        seam([end+Vector((.23,0,-.13)),end+Vector((.26,0,-.46))],'edge',.014)
        cone(end-v*.14,.048,end+Vector((-.24,0,-.23)),'steel',6)
        shield(left,'blue',False)
    elif kind=='ranger':
        part('Equipment / yew longbow, drawn string, fletched arrows and quiver')
        x,y,z=left
        points=[(x,y-.18*math.sin(math.pi*i/12),z-.64+i*.107) for i in range(13)]
        seam(points,'woodLight',.020); seam([points[0],points[-1]],'stitch',.005) if attack<0 else seam([points[0],right,points[-1]],'stitch',.005)
        if attack<.58 and attack>=0:
            h=Vector(right); end=Vector((x,y-.70,z))
            tube(h,end,.008,'woodLight',6); cone(end,.025,end+Vector((0,-.12,0)),'edge',6)
            for s in (-1,1): poly([h,h+Vector((s*.045,-.08,0)),h+Vector((0,-.15,0))],'ivory')
        loft([(.21,.21,1.20,.085,.082),(.19,.25,1.87,.09,.085)],'leatherDark')
        for i in range(5):
            x=.145+i*.025; yy=.25+(.025 if i%2 else 0); z=2.08+math.sin(i)*.06
            tube((x,yy,1.5),(x,yy,z),.007,'woodLight',6)
            poly([(x-.028,yy,z),(x-.028,yy,z-.10),(x,yy,z-.13),(x+.028,yy,z-.10),(x+.028,yy,z)],'ivory')
    elif wizard:
        part('Equipment / ironwood staff, carved gold cage and azure crystal')
        x,y,z=right
        # Move the entire staff with the grip; export matching articulated sockets.
        before={key:len(vertices) for key,(vertices,_) in G.parts.items()}
        tube((x,y,.07),(x+.04,y,2.49+bob),.026,'wood')
        for zz in (1.10,1.26,2.35): loft([(x,y,zz,.044,.044),(x,y,zz+.06,.044,.044)],'gold',10)
        for side in (-1,1):
            seam([(x,y,2.30+bob),(x+side*.10,y,2.45+bob),(x+side*.08,y,2.63+bob)],'gold',.018)
        cone((x,y,2.52+bob),.10,(x,y,2.72+bob),'jewel',6)
        cone((x,y,2.52+bob),.10,(x,y,2.36+bob),'magic',6)
        lift=z-1.30-bob
        for key,(vertices,_) in G.parts.items():
            for i in range(before.get(key,0),len(vertices)):
                xx,yy,zz=vertices[i]; vertices[i]=(xx,yy,zz+lift)
        SOCKETS.update(staff=Vector((x,y,2.60+bob+lift)),hand=Vector(left)+Vector((0,-.045,.065)))
        if .15<attack<.8: ball(Vector(left)+Vector((0,-.04,.06)),(.055,.055,.072),'magic',8,12)
    elif worker:
        part('Equipment / carpenters mallet, chisels and measuring rule')
        h=Vector(right); v=Vector(axis).normalized(); end=h+v*.34
        tube(h-v*.13,end,.024,'woodLight'); box(end,(.29,.12,.14),'wood')
        for side in (-1,1): box(end+Vector((side*.123,0,0)),(.027,.127,.145),'iron')
        tube((-.26,.02,.91),(-.26,.02,1.30),.018,'woodLight')
        box((-.26,.02,1.33),(.035,.04,.12),'steel')
        pouch(-.24,-.03,1.06,.085)
    elif collector:
        part('Equipment / clasped ledger, embossed spine and heavy coin purse')
        x,y,z=left
        box((x,y-.06,z),(.25,.13,.32),'teal')
        box((x,y-.064,z+.155),(.22,.115,.017),'ivory')
        box((x-.122,y-.06,z),(.022,.14,.32),'leather')
        for zz in (-.1,.1): box((x,y-.134,z+zz),(.25,.012,.018),'gold')
        buckle(x+.11,y-.139,z,.048)
        pouch(right[0],right[1]-.04,right[2]-.085,.15,'leatherDark')
    elif kind=='thief':
        blade(right,axis,.45,False,True); blade(left,(0,-.8,-.5),.37,False,True)
        pouch(-.23,.07,1.05,.10,'leatherDark')
    elif skel or gob:
        blade(right,axis,.91,True); shield(left,'wood',True,True)
        pauldron((.32,.015,1.63+bob),.85,'rust')
    # A crouched goblin has a low center of gravity, projecting snout and long hands.
    if gob:
        for vertices,_ in G.parts.values():
            for i,(x,y,z) in enumerate(vertices):
                vertices[i]=(x*.89,y*.91-max(0,z-1.1)*.16,z*.79)


def skull(z):
    part('Undead / sculpted skull, deep orbits, nasal cavity and teeth')
    loft([(0,-.025,z-.13,.115,.107),(0,0,z-.015,.162,.137),
          (0,.015,z+.13,.148,.13),(0,.018,z+.21,.08,.08)],'bone')
    for side in (-1,1):
        ball((side*.079,-.12,z+.019),(.059,.034,.051),'black',8,12)
        ball((side*.079,-.148,z+.016),(.012,.007,.012),'magic',6,8)
        ball((side*.122,-.091,z-.063),(.041,.036,.03),'bone',6,10)
    poly([(-.023,-.153,z-.015),(.023,-.153,z-.015),(.036,-.144,z-.074),(-.030,-.144,z-.074)],'black')
    ball((0,-.038,z-.16),(.108,.094,.038),'bone',6,12)
    for i in range(7): box((-.078+i*.026,-.127,z-.113),(.018,.026,.039),'ivory')


def beast(kind, animation, frame):
    phase,stride,bob,attack=motion(animation,frame)
    boss=kind=='warlord'
    skin='ogre' if boss else 'troll'; light='ogreLight' if boss else 'trollLight'
    part('Monster anatomy / bent legs, heavy hocks and broad clawed feet')
    for side in (-1,1):
        lift=max(0,math.sin(phase+(math.pi if side<0 else 0)))*.14 if animation=='walk' else 0
        foot=Vector((side*.34,side*stride,.135+lift))
        knee=Vector((side*.40,-.13+side*stride*.4,.69+bob))
        limb((side*.29,.09,1.27+bob),knee,.265,.205,skin)
        limb(knee,foot,.185,.15,skin)
        ball(foot+Vector((0,-.12,0)),(.235,.33,.135),skin)
        for i in range(3): cone(foot+Vector((-.14+i*.14,-.37,-.02)),.042,foot+Vector((-.14+i*.14,-.51,-.04)),'bone',8)
        if boss:
            limb(knee+Vector((0,-.10,-.02)),foot+Vector((0,-.10,.19)),.21,.16,'iron')
            ball(knee+Vector((0,-.13,.01)),(.22,.10,.16),'iron',8,12)
    part('Monster anatomy / powerful torso, separate pectorals and ridged back')
    loft([(0,.05,1.20+bob,.41,.30),(0,.06,1.56+bob,.47,.32),
          (0,.12,2.01+bob,.65,.38),(0,.15,2.35+bob,.73,.40),
          (0,.10,2.48+bob,.46,.30)],skin,32)
    for side in (-1,1):
        ball((side*.30,-.16,2.10+bob),(.33,.18,.23),light)
        for i in range(3): ball((side*.15,-.25,1.50+i*.14+bob),(.15,.045,.088),light,8,12)
        ball((side*.42,.30,2.18+bob),(.29,.18,.38),skin)
    part('Monster anatomy / jutting jaw, heavy brow, crooked tusks and angry eyes')
    center=Vector((0,-.30,2.73+bob))
    loft([(0,-.35,2.42+bob,.23,.19),(0,-.38,2.56+bob,.34,.23),
          (0,-.28,2.80+bob,.30,.235),(0,-.20,2.98+bob,.24,.20),
          (0,-.15,3.04+bob,.10,.09)],light,24)
    for side in (-1,1):
        ball((side*.146,-.473,2.79+bob),(.084,.031,.045),'socket',8,12)
        ball((side*.143,-.501,2.79+bob),(.041,.011,.019),'ember' if boss else 'amber',6,10)
        limb((side*.053,-.467,2.864+bob),(side*.24,-.425,2.89+bob),.073,.056,skin)
        ball((side*.233,-.43,2.65+bob),(.123,.089,.10),skin)
        cone((side*.21,-.49,2.51+bob),.069,(side*.25,-.60,2.74+bob),'bone',12)
        cone((side*.27,-.19,2.82+bob),.11,(side*.49,-.09,2.98+bob),skin,12)
    ball((0,-.52,2.72+bob),(.113,.098,.085),skin,8,12)
    seam([(-.18,-.578,2.57+bob),(0,-.608,2.54+bob),(.18,-.578,2.57+bob)],'black',.019)
    for i in range(6): box((-.10+i*.04,-.607,2.569+bob),(.027,.026,.033),'bone')
    for i in range(9): cone((-.21+i*.05,-.14,2.99+bob),.061,(-.22+i*.054,.03,3.15+bob+.05*math.sin(i)),'hair',8)
    part('Monster costume / leather bands, ragged hide and hanging trophies')
    loft([(0,0,.95,.49,.35),(0,.045,1.25+bob,.47,.34),(0,.055,1.44+bob,.45,.33)],'wine' if boss else 'hide',40,.14,phase)
    belt(1.43+bob,.48,.37,'leatherDark')
    for i in range(6):
        x=-.31+i*.12
        cone((x,-.37,1.37+bob),.032,(x+.02,-.39,1.18+bob),'bone',8)
    left=(-.91,-.28,1.46+bob)
    right=interpolate([(.86,-.10,1.60),(.81,.07,2.96),(.88,-.92,1.77),(.88,-.28,1.44)],attack) if attack>=0 else (.89,-.12+math.cos(phase)*.13,1.46+bob)
    axis=interpolate([(0,-.25,1),(0,.4,1),(0,-1,-.2),(0,-.3,1)],attack) if attack>=0 else (0,-.25,1)
    for side,hand in ((-1,left),(1,right)):
        shoulder=Vector((side*.66,.09,2.32+bob)); hand=Vector(hand)
        elbow=shoulder.lerp(hand,.55)+Vector((side*.14,.07,-.08))
        part('Monster anatomy / corded arms, knuckles and fingers')
        limb(shoulder,elbow,.275,.20,skin); limb(elbow,hand,.228,.135,skin)
        ball(shoulder.lerp(elbow,.35)+Vector((0,-.07,0)),(.22,.18,.24),light)
        limb(elbow.lerp(hand,.60),elbow.lerp(hand,.92),.19,.16,'iron' if boss else 'leatherDark')
        ball(hand,(.17,.135,.18),light)
        for i in range(4):
            finger=hand+Vector((-.11+i*.071,-.10,-.057))
            ball(finger,(.041,.045,.095),light,6,10)
            cone(finger+Vector((0,-.022,-.06)),.022,finger+Vector((0,-.052,-.115)),'bone',6)
        part('Monster armor / layered shoulder plates and broken horn spikes')
        if boss:
            pauldron(shoulder+Vector((side*.04,0,.07)),1.9,'iron')
        for i in range(4):
            base=shoulder+Vector((-.16+i*.11,.13,.16))
            ball(base,(.105,.15,.075),'iron' if boss else 'stone',6,10)
            cone(base,.079,base+Vector((side*.12,.03,.27+(.08 if i%2 else 0))),'gold' if boss else 'bone',8)
    if boss:
        part('Warlord / blackened breastplate, crown, scarlet mantle and molten sigil')
        loft([(0,-.014,1.56+bob,.47,.35),(0,-.02,2.02+bob,.64,.42),
              (0,.02,2.28+bob,.63,.40)],'iron',24)
        seam([(0,-.37,1.55+bob),(0,-.46,2.02+bob),(0,-.39,2.28+bob)],'gold',.025)
        for s in (-1,1):
            seam([(s*.40,-.23,1.60+bob),(s*.56,-.28,2.17+bob)],'gold',.018)
            for i in range(4): ball((s*.42,-.30,1.68+i*.12+bob),(.022,)*3,'gold',6,8)
        ball((0,-.448,2.12+bob),(.12,.03,.14),'gold',8,12)
        ball((0,-.48,2.12+bob),(.063,.029,.075),'ember',8,12)
        cloak(2.39+bob,1.55,.65,'red',phase,True,True)
        loft([(0,-.19,2.98+bob,.275,.22),(0,-.19,3.07+bob,.277,.22)],'gold')
        for i in range(8):
            a=TAU*i/8; point=Vector((.268*math.cos(a),-.19+.215*math.sin(a),3.05+bob))
            cone(point,.054,point+Vector((math.cos(a)*.035,math.sin(a)*.035,.28 if i%2 else .37)),'gold',6)
    part('Monster equipment / iron-banded maul and wrapped haft')
    h=Vector(right); v=Vector(axis).normalized(); end=h+v*.96
    limb(h-v*.20,end,.058,.112,'wood')
    if boss:
        ball(end,(.245,.23,.30),'iron',8,12)
        for i in range(6):
            a=TAU*i/6; d=Vector((math.cos(a),math.sin(a),.12))
            cone(end+d*.18,.09,end+d*.42,'edge',6)
    else:
        ball(end,(.22,.19,.35),'woodLight',8,12)
        for i in range(3):
            center=end+v*((i-1)*.15)
            limb(center-v*.024,center+v*.024,.222,.222,'iron')
        for i in range(5):
            a=TAU*i/5
            cone(end+Vector((math.cos(a)*.20,math.sin(a)*.17,0)),.03,end+Vector((math.cos(a)*.29,math.sin(a)*.26,.07)),'bone',6)


def rat(animation,frame):
    phase,stride,bob,attack=motion(animation,frame)
    lunge=-.12*math.sin(max(0,attack)*math.pi)
    part('Vermin / arched spine, sinewy haunches and tapered muzzle')
    ball((0,.19,.37+bob),(.29,.45,.32),'fur')
    ball((0,-.19+lunge,.34+bob),(.23,.38,.25),'furLight')
    loft([(0,-.53+lunge,.20,.13,.18),(0,-.50+lunge,.40,.185,.21),
          (0,-.43+lunge,.54,.14,.14)],'furLight')
    ball((0,-.78+lunge,.27),(.115,.25,.105),'furLight')
    ball((0,-1.01+lunge,.285),(.052,.035,.031),'nose',8,12)
    for side in (-1,1):
        ball((side*.184,-.411+lunge,.56),(.111,.054,.137),'fur')
        ball((side*.183,-.453+lunge,.562),(.077,.015,.098),'ear',8,12)
        ball((side*.146,-.632+lunge,.424),(.031,.018,.026),'black',8,12)
        ball((side*.154,-.649+lunge,.431),(.010,.007,.010),'amber',6,8)
        for yy in (-.34,.40):
            swing=math.cos(phase+(0 if (side>0)==(yy>0) else math.pi))*.15 if animation=='walk' else 0
            lift=max(0,math.sin(phase+(0 if (side>0)==(yy>0) else math.pi)))*.055 if animation=='walk' else 0
            hip=Vector((side*.22,yy,.26)); foot=Vector((side*.29,yy+swing-.06,.05+lift))
            knee=hip.lerp(foot,.52)+Vector((side*.035,.07,.01))
            limb(hip,knee,.078,.045,'fur'); limb(knee,foot,.041,.023,'ear')
            for i in range(4):
                toe=foot+Vector((-.039+i*.026,-.082,-.007))
                limb(foot,toe,.016,.010,'ear'); cone(toe,.012,toe+Vector((0,-.046,-.01)),'bone',6)
        for i in range(4):
            seam([(side*.073,-.86+lunge,.30),(side*(.30+i*.037),-.85+lunge+i*.054,.33+i*.013)],'ivory',.003)
    # Hundreds of short, tapered guard hairs break up the outline and catch the key light.
    part('Vermin / individual guard hairs and dorsal bristles')
    for i in range(160):
        a=(i*2.399963)%TAU; t=((i*37)%161)/161
        y=-.33+t*.98; x=.255*math.cos(a); z=.32+.245*math.sin(a)
        if z<.27: continue
        cone((x,y,z),.008,(x*1.10,y+.05,z+.05),'furLight' if i%3 else 'fur',4)
    part('Vermin / tapering ringed tail with animated follow-through')
    points=[(.20*math.sin(i/20*5+phase*.32)*i/20,.56+i/20*.98,.18-.12*i/20+.04*math.sin(i/20*4)) for i in range(21)]
    for i,(a,b) in enumerate(zip(points,points[1:])):
        limb(a,b,.046*(1-i/22),.044*(1-(i+1)/22),'ear')
    for x in (-.025,.025): cone((x,-.90+lunge,.245),.019,(x,-.93+lunge,.15),'bone',8)


def materials():
    palette={'skin':'c6936b','ear':'9b6252','lip':'71463a','socket':'4b3930','eye':'ded4af',
        'hair':'37281f','whitehair':'c5c4b4','steel':'82929a','edge':'c9d4d4','iron':'414b50',
        'gold':'c69b4c','chain':'555d60','red':'a42325','wine':'762937','blue':'234d73',
        'ink':'293947','olive':'586538','teal':'365d58','ivory':'e1d7b6','linen':'bcb396',
        'straw':'ad874b','stitch':'c1a675','leather':'6e452e','leatherLight':'956741',
        'leatherDark':'3e3027','hose':'655d44','black':'171e20','wood':'60432b',
        'woodLight':'9b7748','rust':'735145','bone':'c3b999','goblin':'7b8950',
        'troll':'657358','trollLight':'93956a','ogre':'5c594d','ogreLight':'8a816a',
        'stone':'7e8775','hide':'71583a','fur':'4c4234','furLight':'796b50','nose':'533b36',
        'jewel':'4cbed0','magic':'bcecf0','ember':'ffb346','amber':'ddb066'}
    metals={'steel','edge','gold','iron','rust'}
    for name,color in palette.items():
        mat=art.material('Character / '+name,color,1.3 if name=='ember' else .7 if name=='magic' else .2 if name=='jewel' else 0)
        shader=mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Roughness'].default_value=.49 if name in metals else .87
        shader.inputs['Metallic'].default_value=.50 if name in metals else 0
        if name not in ('black','eye','magic','ember','amber'):
            nodes=mat.node_tree.nodes; links=mat.node_tree.links
            position=nodes.new('ShaderNodeNewGeometry')
            texture=nodes.new('ShaderNodeTexNoise'); texture.inputs['Scale'].default_value=105 if name=='chain' else 48
            links.new(position.outputs['Position'],texture.inputs['Vector'])
            texture.inputs['Detail'].default_value=2
            bump=nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.27 if name=='chain' else .12
            bump.inputs['Distance'].default_value=.016 if name=='chain' else .009
            links.new(texture.outputs['Fac'],bump.inputs['Height']); links.new(bump.outputs['Normal'],shader.inputs['Normal'])
            grain=nodes.new('ShaderNodeTexNoise'); grain.inputs['Scale'].default_value=15 if name in metals else 32
            grain.inputs['Detail'].default_value=3
            links.new(position.outputs['Position'],grain.inputs['Vector'])
            ramp=nodes.new('ShaderNodeValToRGB')
            base=shader.inputs['Base Color'].default_value[:]
            ramp.color_ramp.elements[0].position=.18; ramp.color_ramp.elements[1].position=.82
            ramp.color_ramp.elements[0].color=tuple(v*.67 for v in base[:3])+(1,)
            ramp.color_ramp.elements[1].color=tuple(min(1,v*1.18) for v in base[:3])+(1,)
            links.new(grain.outputs['Fac'],ramp.inputs['Fac']); links.new(ramp.outputs['Color'],shader.inputs['Base Color'])
        M[name]=mat


def articulate(kind,animation,frame):
    """Weighted upper-body motion keeps planted feet stable during follow-through."""
    if kind=='rat': return
    phase=TAU*frame/ANIMATIONS[animation]
    if animation=='attack':
        lean=[0,-.075,-.10,.17,.09,0][frame]
        twist=[0,-.09,-.15,.11,.06,0][frame]
        if kind in ('ranger','wizard','collector'): lean*=.40; twist*=.60
    elif animation=='cast':
        t=frame/(ANIMATIONS['cast']-1)
        lean=interpolate([(0,0,0),(-.06,-.05,0),(-.075,-.12,0),(.10,.10,0),(0,0,0)],t)[0]
        twist=interpolate([(0,0,0),(-.06,-.05,0),(-.075,-.12,0),(.10,.10,0),(0,0,0)],t)[1]
    elif animation=='walk':
        lean=.032; twist=math.sin(phase)*.048
    else:
        lean=math.sin(phase)*.007; twist=math.sin(phase)*.008
    pivot=Vector((0,0,1.18 if kind in ('troll','warlord') else .88 if kind=='goblin' else 1.04))
    rotation=Matrix.Rotation(lean,3,'X') @ Matrix.Rotation(twist,3,'Z')
    for key,p in SOCKETS.items(): SOCKETS[key]=pivot+rotation@(p-pivot)
    for (name,_),(vertices,_) in G.parts.items():
        if any(word in name for word in ('balanced stance','bent legs')): continue
        rigid=any(word in name.lower() for word in ('equipment','elbows','corded arms'))
        for i,point in enumerate(vertices):
            p=Vector(point)
            weight=1 if rigid else min(1,max(0,(p.z-pivot.z)/.38))
            weight=weight*weight*(3-2*weight)
            vertices[i]=tuple(p.lerp(pivot+rotation@(p-pivot),weight))


def setup(resolution,samples,large=False):
    scene,project=geo.setup(resolution,samples,2.15 if large else 1.60)
    scene.camera.data.ortho_scale=6.5 if large else 5.5
    scene.render.use_persistent_data=True
    scene.render.threads=8
    scene.cycles.max_bounces=4
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
    key=bpy.data.objects['Warm afternoon key']; key.data.energy=2100; key.data.size=5
    key.location=(-5,-8,12); key.rotation_euler=(Vector((0,0,1.5))-key.location).to_track_quat('-Z','Y').to_euler()
    for name,location,energy,color,size in [('Cool sky fill',(6,-3,8),700,(.75,.85,1),6),
                                          ('Soft rim',(-1,6,10),1600,(1,.92,.76),5)]:
        data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.color=color; data.size=size
        obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj); obj.location=location
        obj.rotation_euler=(Vector((0,0,1.4))-obj.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    return scene,project


def main():
    global G
    parser=argparse.ArgumentParser()
    parser.add_argument('--only',nargs='+',choices=TYPES,default=TYPES)
    parser.add_argument('--resolution',type=int,default=384)
    parser.add_argument('--samples',type=int,default=32)
    parser.add_argument('--preview',action='store_true')
    parser.add_argument('--portraits',action='store_true')
    parser.add_argument('--casting',action='store_true',help='Additional 16-pose wizard performance; leaves the base character atlases untouched.')
    parser.add_argument('--output',type=Path,default=Path('/tmp/sovereign-unit-renders'))
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output.mkdir(parents=True,exist_ok=True)
    if args.casting: args.only=['wizard']; ANIMATIONS.clear(); ANIMATIONS['cast']=16
    sources=ROOT/'assets/art/units/directional'; sources.mkdir(parents=True,exist_ok=True)
    for kind in args.only:
        bpy.ops.wm.read_factory_settings(use_empty=True); M.clear(); materials()
        scene,project=setup(args.resolution,args.samples,kind in ('troll','warlord'))
        if args.portraits:
            target=Vector((0,-.05,2.60 if kind in ('troll','warlord') else .42 if kind=='rat' else 2.04 if kind=='wizard' else 1.78 if kind!='goblin' else 1.47))
            camera=scene.camera
            camera.location=target+Vector((18,-18,math.sqrt(648)*math.tan(math.radians(22))))
            camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
            camera.data.ortho_scale=2.05 if kind in ('troll','warlord','wizard') else 1.8 if kind!='rat' else 1.9
        poses=[('idle',0)] if args.preview or args.portraits else [(a,i) for a,n in ANIMATIONS.items() for i in range(n)]
        direction_count=1 if args.preview or args.portraits else 8
        mesh_objects=[]; sockets={}
        for animation,frame in poses:
            for obj in mesh_objects:
                data=obj.data; bpy.data.objects.remove(obj,do_unlink=True); bpy.data.meshes.remove(data)
            G=art.Geometry(); geo.g=G; SOCKETS.clear()
            if kind=='rat': rat(animation,frame)
            elif kind in ('troll','warlord'): beast(kind,animation,frame)
            else: humanoid(kind,animation,frame)
            articulate(kind,animation,frame)
            G.finish(); mesh_objects=[o for o in scene.objects if o.type=='MESH']
            for obj in mesh_objects:
                for polygon in obj.data.polygons:
                    polygon.use_smooth=not any(s in obj.name for s in ('blade','shield','halberd','apron','breastplate','Equipment'))
            for direction in range(direction_count):
                # Direction 0 faces screen southeast, then south, southwest, west, NW, N, NE, E.
                for obj in mesh_objects: obj.rotation_euler.z=math.pi/2-direction*math.pi/4
                rotation=Matrix.Rotation(math.pi/2-direction*math.pi/4,3,'Z')
                sockets[f'{animation}-{frame}-{direction}']={key:project(rotation@point) for key,point in SOCKETS.items()}
                scene.render.filepath=str(args.output/f'{kind}-portrait.png' if args.portraits else args.output/f'{kind}-{animation}-{frame}-{direction}.png')
                bpy.ops.render.render(write_still=True)
            if animation=='idle' and frame==0 and not args.portraits:
                for obj in mesh_objects: obj.rotation_euler.z=math.pi/2
                bpy.context.preferences.filepaths.save_version=0
                bpy.ops.wm.save_as_mainfile(filepath=str(sources/f'{kind}.blend'),compress=True)
            print('CHARACTER',kind,animation,frame,'directions',direction_count,flush=True)
            if args.casting and frame==8:
                bpy.context.preferences.filepaths.save_version=0
                bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/art/units/directional/wizard-casting.blend'),compress=True)
        if args.portraits: continue
        metadata={'type':kind,'render_size':args.resolution,'logical_size':156 if kind in ('troll','warlord') else 132,
                  'anchor':project((0,0,0)), 'selection':project((0,0,.35 if kind=='rat' else 1.65 if kind in ('troll','warlord') else .85 if kind=='goblin' else 1.13)),
                  'directions':['SE','S','SW','W','NW','N','NE','E'], 'animations':ANIMATIONS,
                  'selection_radius':16 if kind=='rat' else 31 if kind in ('troll','warlord') else 21}
        metadata['sockets']=sockets
        (args.output/f'{kind}.json').write_text(json.dumps(metadata,indent=2)+'\n')
        print('COMPLETE',kind,flush=True)


if __name__=='__main__': main()
