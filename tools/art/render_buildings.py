"""Render the ten kingdom buildings with the Palace's geometry and materials.

blender --background --factory-startup --python-exit-code 1 \
  --python tools/art/render_buildings.py -- --resolution 1920 --samples 96
"""

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
THEME = ROOT / "assets/art/palace/color-theme.json"
TYPES = {
    "warriors": "Warriors’ Guild", "rangers": "Rangers’ Lodge",
    "wizards": "Wizards’ Guild", "marketplace": "Marketplace",
    "temple": "Temple of Light", "tower": "Guard Tower",
    "house": "Peasant Cottage", "sewer": "The Old Sewer",
    "graveyard": "Haunted Graveyard", "goblin": "Goblin Camp",
    "thieves": "Thieves’ Guild", "inn": "Inn", "brothel": "Brothel",
}
TAU = math.tau
g = None
rng = None
effects = []
walls = []


def group(name):
    g.group = name


def stone_block(x, y, base, w, d, h):
    art.masonry_box((x,y,base+h/2),(w,d,h))
    walls.extend([((x,y-d/2),0,w,h,base),((x+w/2,y),math.pi/2,d,h,base)])


def paving(w=6.2, d=6.2, ruined=False):
    group("Dressed foundations and worn paving")
    g.box((0,0,.09),(w,d,.18),art.foundation)
    nx,ny=math.ceil(w/.5),math.ceil(d/.5)
    for iy in range(ny):
        for ix in range(nx):
            x=-w/2+(ix+.5)*w/nx
            y=-d/2+(iy+.5)*d/ny
            if ruined and rng.random()<.18:
                continue
            g.box((x,y,.193),(w/nx-.023,d/ny-.025,.05),rng.choice(art.pavers))
    for x,y in ((-w/2+.18,d/2-.25),(w/2-.2,d/2-.25),(w/2-.2,-d/2+.24)):
        art.shrub(x,y,.23,.19 if w<4 else .27)


def door(x,y,z=.24,w=.8,h=1.55,angle=0):
    art.arch((x,y),angle,z,w,h,art.door_dark,art.stone_trim,.12)
    r=w/2
    spring=z+h-r
    for i in range(7):
        u=-r+(i+.5)*w/7
        top=spring+math.sqrt(max(0,r*r-u*u))-.035
        pts=[art.point_on_face(a,-.055,b,(x,y),angle) for a,b in
             ((u-w/14+.009,z+.02),(u+w/14-.009,z+.02),
              (u+w/14-.009,top),(u-w/14+.009,top))]
        g.poly(pts,art.woods[i%len(art.woods)])
    for zz in (z+.23,z+h*.63):
        g.rod(art.point_on_face(-r+.025,-.068,zz,(x,y),angle),
              art.point_on_face(r-.025,-.068,zz,(x,y),angle),.025,art.iron,4)
    g.frustum(x+w*.19,y-.08,z+.65,.04,.04,.045,art.gold,8)


def gable_roof(x,y,z,w,d,h,damaged=False):
    group("Overlapping terracotta roof tiles")
    g.box((x,y,z-.06),(w+.08,d+.08,.12),art.roof_dark)
    for yy in (y-d/2+.09,y+d/2-.09):
        g.poly([(x-w/2+.1,yy,z),(x+w/2-.1,yy,z),(x,yy,z+h-.03)],plaster)
    rows=max(6,round(h/.16))
    cols=max(6,round(d/.22))
    for side in (-1,1):
        for row in range(rows):
            a,b=row/rows,(row+1)/rows
            for col in range(cols):
                if damaged and side==1 and row>rows*.35 and 1<col<cols*.45:
                    continue
                ya=y-d/2+col*d/cols+.007
                yb=ya+d/cols-.014
                xa=x+side*(w/2*(1-a)+.025)
                xb=x+side*w/2*(1-b)
                g.poly([(xa,ya,z+h*a),(xa,yb,z+h*a),
                        (xb,yb,z+h*b),(xb,ya,z+h*b)],rng.choice(art.roofs))
    for i in range(math.ceil(d/.23)):
        yy=y-d/2+(i+.5)*d/math.ceil(d/.23)
        g.frustum(x,yy,z+h-.035,.095,.065,.105,art.roof_ridge,6)
    for yy in (y-d/2-.015,y+d/2+.015):
        for side in (-1,1):
            g.rod((x+side*w/2,yy,z),(x,yy,z+h),.052,art.woods[0],4)
    if damaged:
        for yy in (y-d*.3,y-d*.05):
            g.rod((x,yy,z+h),(x+w/2,yy,z),.065,art.woods[0],4)


def timber_hall(x,y,w,d,h=2.6,roof_h=1.35,windows=True):
    group("Stone footing and plastered timber frame")
    stone_block(x,y,.23,w,d,.7)
    g.box((x,y,.93+(h-.7)/2),(w-.07,d-.07,h-.7),plaster)
    for xx in (x-w/2,x+w/2):
        for yy in (y-d/2,y+d/2):
            g.box((xx,yy,.23+h/2),(.12,.12,h),art.woods[0])
    for z in (1.0,h*.6+.23,h+.23):
        g.box((x,y-d/2-.025,z),(w+.08,.13,.12),art.woods[0])
        g.box((x+w/2+.025,y,z),(.13,d+.08,.12),art.woods[0])
    for xx in (x-w*.24,x+w*.24):
        g.box((xx,y-d/2-.025,.93+(h-.7)/2),(.09,.12,h-.7),art.woods[1])
    for yy in (y-d*.27,y,y+d*.27):
        g.box((x+w/2+.025,yy,.93+(h-.7)/2),(.12,.09,h-.7),art.woods[1])
    for sign in (-1,1):
        g.rod((x+sign*w*.48,y-d/2-.07,1.04),
              (x+sign*w*.25,y-d/2-.07,h*.6+.17),.045,art.woods[1],4)
    if windows:
        for xx in (x-w*.28,x+w*.28):
            art.window((xx,y-d/2-.075),0,h-.62,.38,.62,True)
        for yy in (y-d*.28,y+d*.28):
            art.window((x+w/2+.07,yy),math.pi/2,1.25,.38,.69,True)
    gable_roof(x,y,h+.3,w+.43,d+.5,roof_h)


def chimney(x,y,z,h=1):
    group("Soot-stained chimney")
    stone_block(x,y,z,.43,.48,h)
    g.box((x,y,z+h+.03),(.57,.61,.12),art.stone_trim)
    g.box((x,y,z+h+.095),(.32,.35,.018),art.soot)
    effects.append({"type":"smoke","point":[x,y,z+h+.13]})


def barrel(x,y,z=.23,s=1):
    group("Oak barrels and iron hoops")
    for i in range(12):
        a,b=i*TAU/12+.008,(i+1)*TAU/12-.008
        for zz,hh,ra,rb in ((0,.25,.2,.25),(.25,.25,.25,.2)):
            g.poly([(x+ra*s*math.cos(a),y+ra*s*math.sin(a),z+zz*s),
                    (x+ra*s*math.cos(b),y+ra*s*math.sin(b),z+zz*s),
                    (x+rb*s*math.cos(b),y+rb*s*math.sin(b),z+(zz+hh)*s),
                    (x+rb*s*math.cos(a),y+rb*s*math.sin(a),z+(zz+hh)*s)],art.woods[i%4])
    for zz in (.09,.39):
        g.frustum(x,y,z+zz*s,.233*s,.233*s,.035*s,art.iron,12)
    g.frustum(x,y,z+.498*s,.20*s,.20*s,.018*s,art.woods[1],12)


def crate(x,y,z=.23,s=.55):
    group("Stacked provision crates")
    g.box((x,y,z+s/2),(s,s,s),art.woods[1])
    for i in range(4):
        xx=x-s/2+(i+.5)*s/4
        g.box((xx,y-s/2-.014,z+s/2),(s/4-.014,.025,s-.025),art.woods[i])
    for zz in (z+.06,z+s-.06):
        g.box((x,y-s/2-.032,zz),(s,.05,.08),art.woods[0])
    g.rod((x-s*.4,y-s/2-.05,z+.07),(x+s*.4,y-s/2-.05,z+s-.07),.035,art.woods[0],4)


def shield(x,y,z,s=.7):
    group("Guild heraldry")
    pts=[(-.45,.5),(.45,.5),(.4,-.13),(0,-.55),(-.4,-.13)]
    g.poly([(x+a*s,y,z+b*s) for a,b in pts],art.cloth)
    for i in range(5):
        a,b=pts[i],pts[(i+1)%5]
        g.rod((x+a[0]*s,y-.012,z+a[1]*s),(x+b[0]*s,y-.012,z+b[1]*s),.02,art.gold,4)
    g.rod((x,y-.025,z-.3*s),(x,y-.025,z+.35*s),.035,art.gold_light,4)
    g.rod((x-.27*s,y-.025,z+.13*s),(x+.27*s,y-.025,z+.13*s),.035,art.gold_light,4)


def sword(x,y,z,lean=.25,s=1):
    g.rod((x,y,z),(x+lean*s,y,z+1.0*s),.035,steel,4)
    g.rod((x-.15*s,y-.01,z+.15*s),(x+.16*s,y-.01,z+.15*s),.028,art.gold,4)
    g.rod((x,y,z-.15*s),(x,y,z+.12*s),.04,art.woods[0],6)


def target(x,y,z=.23,s=.55):
    group("Archery targets")
    for dx in (-.25,.25):
        g.rod((x+dx,y,z),(x,y+.14,z+1.1),.055,art.woods[0],6)
    for rr,mat,offset in ((1,art.woods[1],0),(.9,art.gold_light,-.015),(.59,art.cloth,-.022),(.27,art.gold_light,-.03)):
        g.poly([(x+math.cos(a)*s*rr,y+offset,z+.95+math.sin(a)*s*rr)
                for a in [i*TAU/32 for i in range(32)]],mat)
    for dx,dz in ((-.12,.07),(.09,-.09)):
        g.rod((x+dx,y-.35,z+.95+dz),(x+dx,y+.03,z+.95+dz),.012,art.woods[2],4)


def fence(points,height=1,iron=False):
    group("Boundary fence")
    mat=art.iron if iron else art.woods[0]
    for a,b in zip(points,points[1:]):
        v1,v2=Vector((*a,.23)),Vector((*b,.23))
        n=max(1,round((v2-v1).length/(.26 if iron else .6)))
        for i in range(n+1):
            pos=v1.lerp(v2,i/n)
            g.rod(pos,pos+Vector((0,0,height)),.023 if iron else .065,mat,6)
            g.frustum(pos.x,pos.y,.23+height,.052 if iron else .077,0,.11,mat,6)
        for zz in (height*.35,height*.78):
            g.rod(v1+Vector((0,0,zz)),v2+Vector((0,0,zz)),.024 if iron else .047,mat,6)


def stairs(x,y,width=1.3,count=3):
    group("Worn entrance steps")
    for i in range(count):
        h=.09*(i+1)
        g.box((x,y+i*.19,h/2),(width,.22,h),art.stone_trim if i%2 else art.stone_light)


def round_ring(center,radius,normal,mat,thickness=.022):
    normal=Vector(normal).normalized()
    tangent=normal.cross(Vector((0,0,1)))
    if tangent.length<.01:
        tangent=Vector((1,0,0))
    tangent.normalize()
    second=normal.cross(tangent)
    pts=[Vector(center)+radius*(math.cos(i*TAU/40)*tangent+math.sin(i*TAU/40)*second) for i in range(41)]
    for a,b in zip(pts,pts[1:]):
        g.rod(a,b,thickness,mat,6)


def weather(ruined=False):
    group("Cracks, damp masonry and creeping ivy")
    for center,angle,w,h,base in walls:
        # Damp streaks and small fractures stay near corners, away from windows.
        for side in (-1,1):
            u=side*w*.36
            top=base+min(h*.7,1.3)
            pts=[(u,top),(u-.06,top-.2),(u+.06,top-.38),(u-.025,top-.52)]
            for a,b in zip(pts,pts[1:]):
                g.rod(art.point_on_face(a[0],-.077,a[1],center,angle),
                      art.point_on_face(b[0],-.077,b[1],center,angle),.009,art.crack_stone,4)
            for i in range(5 if ruined else 3):
                zz=base+.12+i*.09
                uu=u+rng.uniform(-.13,.13)
                verts=[art.point_on_face(uu+math.cos(a)*.13,-.08,zz+math.sin(a)*.08,center,angle)
                       for a in [j*TAU/7 for j in range(7)]]
                g.poly(verts,rng.choice([art.old_stone,art.lichen,art.leaves[2]]))
    for i in range(22 if ruined else 9):
        x=rng.uniform(-2.8,2.8) if current_type not in ("house","tower") else rng.uniform(-1.2,1.2)
        y=rng.choice((-1,1))*(2.75 if current_type not in ("house","tower") else 1.24)
        g.frustum(x,y,.23,.09,.06,.06,rng.choice(art.pavers),5)


def build_house():
    paving(3.1,3.1)
    timber_hall(-.05,.17,2.25,2.1,1.85,1.05)
    door(-.25,-.9,w=.61,h=1.35)
    chimney(.64,.69,2.72,.85)
    group("Sheltered doorstep")
    gable_roof(-.24,-1.08,1.7,1.05,.78,.37)
    for x in (-.72,.24):
        g.box((x,-1.39,.86),(.065,.065,1.3),art.woods[1])
    stairs(-.24,-1.6,.85,2)
    barrel(1.21,.72,s=.75)
    g.box((1.13,-.32,.59),(.29,1.0,.12),art.woods[1])
    for y in (-.63,0):
        g.box((1.13,y,.4),(.09,.1,.32),art.woods[0])
    fence([(-1.43,.86),(-1.43,1.43),(.92,1.43)],.54)


def build_warriors():
    paving()
    group("Fortified guild hall")
    stone_block(.45,.46,.23,3.9,3.9,3.4)
    gable_roof(.45,.46,3.69,4.32,4.25,1.48)
    door(.43,-1.51,w=1.02,h=2.0)
    for x in (-.87,1.74):
        art.window((x,-1.525),0,1.13,.38,.92)
        art.banner((x,-1.54),0,2.35,.48,.85)
    for y in (-.7,.6,1.68):
        art.window((2.42,y),math.pi/2,1.23,.4,1.12)
    shield(.45,-1.61,3.08,.86)
    group("Crenellated armory tower")
    stone_block(-1.84,.9,.23,1.6,1.65,4.25)
    g.box((-1.84,.9,4.51),(1.86,1.91,.17),art.stone_trim)
    for xx in (-2.56,-1.83,-1.11):
        for yy in (.14,1.67):
            g.chipped_box((xx,yy,4.78),(.33,.4,.4),art.stone_trim)
    for yy in (.66,1.17):
        for xx in (-2.56,-1.11):
            g.box((xx,yy,4.78),(.36,.29,.4),art.stone_trim)
    art.flag(-1.83,1.01,4.55,.83)
    art.window((-1.83,.06),0,2.56,.29,.85)
    group("Weapons rack and training yard")
    for x in (-2.52,-1.66):
        g.rod((x,-2.12,.23),(x,-2.12,1.66),.065,art.woods[0])
    g.rod((-2.59,-2.12,1.44),(-1.59,-2.12,1.44),.06,art.woods[0])
    for i in range(3):
        sword(-2.37+i*.27,-2.2,.5,.07,.94)
    shield(-1.71,-2.23,1.06,.59)
    target(2.43,-2.19,s=.38)
    barrel(2.63,1.53)
    crate(-2.45,2.5)
    stairs(.43,-2.04,1.35,3)
    chimney(1.46,1.36,4.56,.9)


def build_rangers():
    paving()
    timber_hall(.55,.61,3.58,3.56,2.72,1.42)
    door(.41,-1.2,w=.86,h=1.69)
    group("Timber porch and hunting balcony")
    for x in (-1.19,2.29):
        g.box((x,-2.13,1.28),(.12,.12,2.1),art.woods[0])
    for i in range(13):
        g.box((-.99+i*.254,-1.71,.35),(.236,1.03,.12),art.woods[1])
    g.poly([(-1.38,-1.03,2.81),(2.48,-1.03,2.81),(2.48,-2.35,2.4),(-1.38,-2.35,2.4)],art.roof_dark)
    for i in range(19):
        x=-1.36+i*.201
        for j in range(6):
            y=-1.05-j*.214
            z=2.815-j*.068
            g.poly([(x,y,z),(x+.195,y,z),(x+.195,y-.225,z-.071),(x,y-.225,z-.071)],rng.choice(art.roofs))
    for x in (-1.18,2.26):
        g.rod((x,-2.12,1.87),(x,-1.73,2.54),.055,art.woods[0])
    art.banner((1.62,-1.24),0,1.04,.5,1.12)
    target(-2.18,-1.76,s=.48)
    target(-2.2,-.3,s=.42)
    group("Hunting sign")
    g.rod((2.33,-.3,2.23),(2.93,-.3,2.23),.036,art.iron)
    g.box((2.84,-.3,1.94),(.09,.67,.46),art.woods[1])
    round_ring((2.895,-.31,1.95),.16,(1,0,0),art.gold_light,.018)
    fence([(-2.81,.89),(-2.81,2.78),(2.72,2.78)],.92)
    for i in range(5):
        g.rod((2.54,.16+i*.17,.35),(2.54,1.01+i*.1,.35),.075,art.woods[i%4],8)
    barrel(2.48,2.07)
    chimney(1.22,1.68,3.7,.9)


def build_wizards():
    paving()
    group("Arcane octagonal tower")
    art.tower("Arcane tower",-.46,.59,5.65,1.22,2.15,False)
    for zz in (1.42,3.12,4.75):
        g.frustum(-.46,.59,zz,1.29,1.29,.11,art.gold,16)
    door(-.46,-.645,w=.79,h=1.95)
    group("Alchemist's annex")
    stone_block(1.55,.63,.23,1.54,2.72,2.13)
    art.hip_roof(1.55,.63,2.43,.93,1.53,1.1,10)
    art.window((2.34,.2),math.pi/2,1.0,.42,.9,True)
    art.window((2.34,1.2),math.pi/2,1.0,.42,.9)
    art.banner((-.47,-.675),0,3.23,.64,1.1)
    group("Brass armillary sphere")
    for normal in ((0,0,1),(1,.4,.4),(.3,1,-.3)):
        round_ring((-.46,.59,8.29),.43,normal,art.gold,.03)
    g.frustum(-.46,.59,8.12,.13,.13,.28,crystal,8)
    g.rod((-.46,.59,7.91),(-.46,.59,8.87),.032,art.gold,8)
    group("Garden of astronomical stones")
    for x,y in ((-2.14,-1.54),(1.78,-1.88),(2.56,2.11)):
        g.frustum(x,y,.23,.29,.22,.44,art.stone_trim,6)
        g.frustum(x,y,.67,.23,0,.59,crystal,6)
    group("Arcane entry mosaic")
    for radius in (.61,.89):
        round_ring((-.46,-1.67,.25),radius,(0,0,1),art.gold,.018)
    barrel(2.54,.07)
    crate(1.24,2.45,s=.47)
    stairs(-.46,-1.22,1.22,3)


def build_marketplace():
    paving()
    timber_hall(0,.93,4.48,2.9,2.54,1.38)
    door(.02,-.545,w=.85,h=1.73)
    group("Striped market awning")
    for i in range(14):
        xa=-2.49+i*4.98/14
        xb=xa+4.98/14
        mat=art.cloth if i%2 else art.flag_gold
        for row in range(9):
            a,b=row/9,(row+1)/9
            def p(x,t):
                return (x,-.54-t*1.72,2.42-t*.42-.12*math.sin(math.pi*t))
            g.poly([p(xa,a),p(xb,a),p(xb,b),p(xa,b)],mat)
        g.poly([(xa,-2.27,2.0),(xb,-2.27,2.0),(xb,-2.27,1.79),((xa+xb)/2,-2.27,1.72),(xa,-2.27,1.79)],mat)
    for x in (-2.43,0,2.43):
        g.rod((x,-2.2,.23),(x,-2.2,2.05),.051,art.woods[0])
    group("Produce counters")
    for x in (-1.43,1.41):
        g.box((x,-1.97,.85),(1.55,.67,.13),art.woods[1])
        for dx in (-.58,.58):
            g.box((x+dx,-1.97,.52),(.085,.52,.58),art.woods[0])
        for i in range(3):
            xx=x-.51+i*.51
            g.box((xx,-1.97,.94),(.47,.55,.10),art.woods[0])
            for j in range(7):
                a=j*2.4
                px=xx+math.cos(a)*.14
                py=-1.97+math.sin(a)*.16
                mat=[art.cloth,art.roof_ridge,art.leaves[1]][i]
                g.frustum(px,py,1.0,.075,.095,.08,mat,8)
                g.frustum(px,py,1.08,.095,.018,.065,mat,8)
    group("Merchant sign and provisions")
    g.rod((2.29,.42,2.17),(2.95,.42,2.17),.043,art.iron)
    g.box((2.81,.42,1.81),(.065,.56,.52),art.woods[1])
    round_ring((2.85,.42,1.82),.18,(1,0,0),art.gold,.04)
    for i in range(3):
        barrel(-2.6,.04+i*.57,s=.82)
    crate(2.66,1.75,s=.52)
    crate(2.62,2.35,s=.51)
    crate(2.65,2.02,z=.75,s=.48)


def build_temple():
    paving()
    group("Temple nave and carved buttresses")
    stone_block(.55,.63,.23,3.24,4.45,3.74)
    gable_roof(.55,.63,4.05,3.66,4.79,1.74)
    for y in (-1.28,.02,1.34,2.65):
        g.box((2.27,y,1.55),(.28,.32,2.65),art.stone_trim)
        g.box((2.27,y,2.96),(.4,.43,.17),art.stone_light)
    for y in (-.61,.7,2.02):
        art.window((2.185,y),math.pi/2,1.31,.46,1.78,True)
    door(.55,-1.62,w=1.11,h=2.18)
    group("Rose window")
    for rr,mat,yy in ((.52,art.stone_light,-1.63),(.42,amber_glass,-1.65)):
        g.poly([(.55+math.cos(a)*rr,yy,3.16+math.sin(a)*rr) for a in [i*TAU/32 for i in range(32)]],mat)
    for i in range(8):
        a=i*TAU/8
        g.rod((.55,-1.676,3.16),(.55+math.cos(a)*.42,-1.676,3.16+math.sin(a)*.42),.025,art.stone_light)
    group("Bell tower")
    stone_block(-1.71,.99,.23,1.52,1.65,4.54)
    for xx in (-2.35,-1.07):
        for yy in (.28,1.68):
            g.box((xx,yy,5.48),(.21,.21,1.55),art.stone_trim)
    g.box((-1.71,.99,6.27),(1.78,1.91,.17),art.stone_trim)
    g.frustum(-1.71,.99,5.07,.44,.21,.6,art.gold,16)
    g.rod((-1.71,.99,5.0),(-1.71,.99,6.11),.032,art.iron)
    art.hip_roof(-1.71,.99,6.39,1.0,1.06,1.46,13)
    group("Temple gold crosses")
    for x,y,z,s in ((-1.71,.99,7.88,.83),(.55,-1.55,5.71,.57)):
        g.rod((x,y,z),(x,y,z+s),.048,art.gold,4)
        g.rod((x-s*.26,y,z+s*.68),(x+s*.26,y,z+s*.68),.048,art.gold,4)
    art.banner((-1.71,.14),0,2.65,.55,1.22)
    stairs(.55,-2.32,1.57,4)
    group("Votive garden")
    for x in (-.79,1.88):
        g.frustum(x,-2.18,.23,.26,.20,.68,art.stone_trim,8)
        g.frustum(x,-2.18,.91,.24,.29,.16,art.gold,8)
        g.frustum(x,-2.18,1.08,.11,0,.25,art.flame,7)


def build_tower():
    paving(3.1,3.1)
    group("Defensive tower masonry")
    stone_block(0,.12,.23,1.87,1.87,4.1)
    for z in (1.01,2.32,4.13):
        g.box((0,.12,z),(2.02,2.02,.12),art.stone_trim)
    door(0,-.83,w=.61,h=1.44)
    for z in (2.26,3.26):
        art.window((0,-.83),0,z,.22,.61)
        art.window((.94,.12),math.pi/2,z,.22,.61)
    group("Timber hoarding and watch roof")
    g.box((0,.12,4.45),(2.6,2.6,.19),art.woods[1])
    for x in (-1.17,1.17):
        for y in (-1.05,1.29):
            g.box((x,y,5.06),(.115,.115,1.13),art.woods[0])
            g.rod((x*.75,.12+(y-.12)*.75,3.85),(x,y,4.45),.06,art.woods[1],4)
    for i in range(9):
        x=-1.17+i*.2925
        g.box((x,-1.1,4.81),(.23,.09,.57),art.woods[0 if i%3 else 1])
        g.box((1.2,x+.12,4.81),(.09,.23,.57),art.woods[0 if i%3 else 1])
    art.hip_roof(0,.12,5.69,1.49,1.49,1.78,15)
    art.flag(0,.12,7.51,.75)
    art.banner((0,-.98),0,1.79,.62,1.07)
    group("Mounted crossbow")
    g.rod((1.24,-.34,4.65),(1.51,-.51,5.14),.055,art.woods[1])
    g.rod((1.28,-.28,5.03),(1.87,-.73,5.03),.048,art.woods[0])
    g.rod((1.29,-.84,5.05),(1.9,-.13,5.05),.031,art.iron)
    barrel(-1.18,.79,s=.7)


def build_sewer():
    paving(6.2,6.2,True)
    group("Collapsed sewer vault")
    stone_block(0,1.03,.23,4.03,2.35,2.65)
    art.arch((0,-.16),0,.24,2.54,2.23,art.door_dark,art.stone_trim,.27)
    for i in range(11):
        x=-1.15+i*.23
        top=1.2+math.sqrt(max(0,1.27**2-x*x))
        g.rod((x,-.24,.32),(x,-.24,top-.06),.029,rust,6)
    for zz in (.83,1.54):
        g.rod((-1.12,-.27,zz),(1.12,-.27,zz),.043,rust,6)
    group("Broken coping")
    for i in range(10):
        x=-1.8+i*.4
        g.chipped_box((x,-.04,3.0),(.38,.48,rng.uniform(.21,.5)),art.stone_trim)
    for i in range(5):
        g.box((rng.uniform(-1.5,1.5),rng.uniform(.2,1.8),2.95),(.36,.41,.25),rng.choice(art.stones))
    group("Stagnant drainage channel")
    g.box((0,-1.55,.249),(1.65,2.65,.022),water)
    for x in (-1.03,1.03):
        stone_block(x,-1.45,.23,.38,2.85,.4)
    for i in range(11):
        x,y=rng.uniform(-.65,.65),rng.uniform(-2.74,-.25)
        round_ring((x,y,.269),rng.uniform(.03,.12),(0,0,1),art.leaves[0],.012)
    group("Abandoned pipe and rubble")
    for i in range(25):
        x=rng.choice((-1,1))*rng.uniform(1.52,2.85)
        y=rng.uniform(-2.65,2.7)
        g.chipped_box((x,y,.29),(.21,.32,rng.uniform(.13,.34)),rng.choice(art.stones))
    for x,y in ((-2.1,-.55),(2.27,.5),(-1.55,1.71)):
        art.shrub(x,y,.24,.32)
    g.frustum(2.25,1.71,.23,.43,.43,.63,rust,16)
    g.frustum(2.25,1.71,.86,.32,.32,.025,art.door_dark,16)


def gravestone(x,y,h=.7,angle=0):
    group("Weathered gravestones")
    g.box((x,y-.26,.26),(.65,1.0,.07),art.old_stone)
    shape=[(-.27,0),(.27,0),(.27,h-.22)]
    shape +=[(.27*math.cos(i*math.pi/12),h-.22+.27*math.sin(i*math.pi/12)) for i in range(13)]
    g.poly([art.point_on_face(u,-.035,.3+z,(x,y),angle) for u,z in shape],art.stone_trim)
    for a,b in (((0,.44),(0,.84)),((-.14,.67),(.14,.67))):
        g.rod(art.point_on_face(a[0],-.049,a[1],(x,y),angle),
              art.point_on_face(b[0],-.049,b[1],(x,y),angle),.022,art.old_stone,4)


def build_graveyard():
    paving(6.2,6.2,True)
    group("Ruined funerary chapel")
    stone_block(-.55,1.2,.23,2.65,2.65,2.86)
    gable_roof(-.55,1.2,3.17,3.02,3.06,1.41,True)
    art.arch((-.55,-.15),0,.25,.96,1.91,art.door_dark,art.stone_trim,.18)
    art.window((.785,1.2),math.pi/2,1.21,.55,1.19)
    group("Broken chapel bell gable")
    for x in (-1.11,.01):
        g.chipped_box((x,-.05,3.89),(.31,.44,1.46),art.stone_trim)
    g.chipped_box((-.55,-.05,4.7),(1.56,.49,.32),art.stone_trim)
    g.frustum(-.55,-.05,3.83,.28,.13,.39,rust,12)
    g.rod((-.55,-.05,4.15),(-.55,-.05,4.65),.032,art.iron)
    for x,y in ((-2.18,-1.07),(-1.08,-1.56),(.12,-2.04),(1.44,-1.15),(2.1,.07),(1.92,1.81)):
        gravestone(x,y,rng.uniform(.62,.94))
    fence([(-2.84,-2.71),(-2.84,2.81),(2.84,2.81),(2.84,-2.71)],.98,True)
    for x in (-.7,.7):
        stone_block(x,-2.74,.23,.39,.44,1.18)
        g.frustum(x,-2.74,1.43,.25,0,.32,art.stone_trim,4,math.pi/4)
    group("Ruined stones and votive lanterns")
    for x,y in ((-2.47,.45),(1.12,2.42),(2.58,-1.77)):
        g.chipped_box((x,y,.36),(.43,.37,.25),art.stone_trim)
        g.frustum(x,y,.49,.13,.13,.18,haunt,6)
        g.frustum(x,y,.68,.17,0,.17,art.iron,6)


def build_goblin():
    paving(6.2,6.2,True)
    group("Rough log stronghold")
    for row in range(8):
        z=.34+row*.18
        for y in (-.58,2.16):
            g.rod((-1.9,y,z),(1.55,y,z),.108,art.woods[row%4],8)
        for x in (-1.79,1.44):
            g.rod((x,-.7,z),(x,2.29,z),.105,art.woods[(row+1)%4],8)
    group("Patched hide roof")
    for side in (-1,1):
        for row in range(7):
            a,b=row/7,(row+1)/7
            for col in range(8):
                ya=-.97+col*.45
                g.poly([(-.17+side*1.98*(1-a),ya,1.9+a*1.55),
                        (-.17+side*1.98*(1-a),ya+.44,1.9+a*1.55),
                        (-.17+side*1.98*(1-b),ya+.44,1.9+b*1.55),
                        (-.17+side*1.98*(1-b),ya,1.9+b*1.55)],rng.choice(hides))
    g.rod((-.17,-1.05,3.48),(-.17,2.76,3.48),.066,art.woods[0],7)
    art.arch((-.17,-.735),0,.23,1.02,1.36,art.door_dark,art.woods[0],.14)
    group("Crooked defensive stakes")
    for a,b in (((-2.69,-1.45),(-2.69,2.75)),((-2.69,2.75),(2.69,2.75)),((2.69,2.75),(2.69,-1.59))):
        n=round((Vector(a)-Vector(b)).length/.27)
        for i in range(n):
            x,y=Vector(a).lerp(Vector(b),i/n)
            h=rng.uniform(1.0,1.72)
            g.frustum(x,y,.23,.115,.10,h,art.woods[i%4],7)
            g.frustum(x,y,.23+h,.11,0,.26,art.woods[(i+1)%4],7)
    group("War trophy totems")
    for x in (-2.22,2.19):
        g.rod((x,-1.95,.23),(x+.12,-1.93,2.57),.105,art.woods[0],7)
        g.frustum(x+.12,-1.93,2.43,.22,.25,.31,art.gold_light,8)
        for dx in (-.09,.09):
            g.box((x+.12+dx,-2.171,2.6),(.075,.025,.083),art.door_dark)
        g.rod((x-.27,-1.92,2.02),(x+.5,-1.92,2.15),.035,art.gold_light,6)
    group("Campfire")
    for i in range(6):
        a=i*TAU/6
        g.rod((.5+math.cos(a)*.37,-2.02+math.sin(a)*.37,.28),(.5,-2.02,.56),.065,art.woods[0],6)
    for dx,dy,h in ((0,0,.6),(.14,.02,.38),(-.12,-.02,.32)):
        g.frustum(.5+dx,-2.02+dy,.42,.15,0,h,art.flame,7)
    effects.append({"type":"fire","point":[.5,-2.02,.54]})
    barrel(1.91,.16,s=.85)
    crate(-2.0,.56,s=.54)
    shield(-.16,-.9,2.07,.65)


def build_thieves():
    paving()
    group("Weathered thieves' counting house")
    timber_hall(.6,.65,3.5,3.65,2.9,1.6)
    door(.6,-1.22,w=.8,h=1.7)
    group("Lookout tower and shadowed passage")
    stone_block(-1.83,.65,.23,1.62,2.2,3.8)
    timber_hall(-1.83,.65,1.78,2.3,4.05,1.3,windows=False)
    for z in (1.2,2.7,3.45):
        art.window((-1.83,-.52),0,z,.27,.6)
    group("Balcony, iron bars and brass key sign")
    g.box((.6,-1.53,2.12),(2.5,.9,.13),art.woods[0])
    for i in range(10):
        x=-.58+i*2.35/9
        g.rod((x,-1.86,2.19),(x,-1.86,2.78),.02,art.iron)
    for x in (-.58,1.77):
        g.rod((x,-1.86,.24),(x,-1.86,2.12),.065,art.woods[0])
        g.rod((x,-1.86,2.19),(x,-1.86,2.87),.023,art.iron)
    g.rod((-.58,-1.86,2.78),(1.77,-1.86,2.78),.027,art.iron)
    art.banner((1.58,-1.28),0,1.18,.4,.8)
    g.rod((2.39,-.65,2.55),(2.95,-.65,2.55),.035,art.iron)
    g.box((2.89,-.65,2.2),(.08,.72,.53),art.woods[0])
    round_ring((2.94,-.81,2.29),.105,(1,0,0),art.gold_light,.025)
    g.rod((2.94,-.72,2.24),(2.94,-.45,2.08),.025,art.gold_light)
    g.rod((2.94,-.5,2.11),(2.94,-.57,2.02),.025,art.gold_light)
    for x,y in ((-2.36,-1.86),(2.47,2.36)):
        barrel(x,y,s=.8)
    crate(2.47,-1.65,s=.6)
    crate(2.5,-2.34,s=.43)
    stairs(.6,-2.28,1.18,3)
    chimney(1.7,1.5,4.02,.95)


def build_inn():
    paving()
    timber_hall(-.3,.55,4.0,3.7,3.0,1.55)
    door(-.35,-1.33,w=.9,h=1.8)
    chimney(1.1,1.6,4.1,1.1)
    group("Inn · tankard sign and outdoor benches")
    g.rod((1.77,-1.3,2.65),(2.6,-1.3,2.65),.04,art.iron)
    g.box((2.4,-1.3,2.22),(.7,.1,.62),art.woods[0])
    g.box((2.33,-1.37,2.2),(.24,.045,.31),art.gold_light)
    round_ring((2.54,-1.4,2.22),.105,(0,1,0),art.gold_light,.027)
    for x in (-1.65,.85):
        g.box((x,-2.25,.93),(1.3,.65,.12),art.woods[1])
        for dx in (-.43,.43):
            g.box((x+dx,-2.25,.58),(.13,.48,.67),art.woods[0])
        for y in (-2.75,-1.8):
            g.box((x,y,.58),(1.3,.23,.13),art.woods[0])
    barrel(2.45,.75,s=.85)
    barrel(2.45,1.65,s=.75)


def build_brothel():
    paving()
    timber_hall(.1,.65,4.35,3.6,3.65,1.45)
    door(.15,-1.2,w=1.0,h=1.9)
    group("Brothel · crimson curtains and lanterned veranda")
    g.box((.1,-1.65,2.35),(4.6,1.1,.16),art.woods[0])
    for x in (-1.95,2.15):
        g.rod((x,-2.08,.24),(x,-2.08,2.4),.065,art.woods[0])
        art.banner((x,-2.12),0,1.05,.4,.9)
    for x in (-1.3,1.5):
        art.banner((x,-1.21),0,2.8,.65,.67)
        g.box((x,-1.35,1.9),(.23,.23,.4),amber_glass)
    for i in range(12):
        x=-2.05+i*.4
        g.rod((x,-2.1,2.42),(x,-2.1,2.94),.023,art.iron)
    g.rod((-2.05,-2.1,2.94),(2.35,-2.1,2.94),.035,art.iron)
    stairs(.15,-2.7,1.4,3)


BUILDERS={key:globals()["build_"+key] for key in TYPES}


def setup_scene(resolution,samples,out,key):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=samples
    scene.cycles.use_denoising=True
    scene.cycles.max_bounces=6
    scene.render.threads_mode="FIXED"
    scene.render.threads=10
    scene.render.resolution_x=scene.render.resolution_y=resolution
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.image_settings.color_depth="8"
    scene.render.filepath=str(out/f"{key}-render.png")
    scene.view_settings.view_transform="Standard"
    scene.view_settings.look="None"
    world=bpy.data.worlds.new("Palace daylight")
    scene.world=world
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.52,.62,.76,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=.4
    light_data=bpy.data.lights.new("Warm afternoon key","AREA")
    light_data.energy=2600
    light_data.shape="DISK"
    light_data.size=6
    light_data.color=(1,.93,.82)
    light=bpy.data.objects.new("Warm afternoon key",light_data)
    scene.collection.objects.link(light)
    light.location=(-7,-10,16)
    light.rotation_euler=(Vector((0,0,2))-light.location).to_track_quat("-Z","Y").to_euler()
    cam_data=bpy.data.cameras.new("Shared 2 to 1 isometric projection")
    camera=bpy.data.objects.new("Shared 2 to 1 isometric projection",cam_data)
    scene.collection.objects.link(camera)
    target=Vector((0,0,3.7))
    camera.location=target+Vector((18,-18,math.sqrt(18**2+18**2)*math.tan(math.radians(30))))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    cam_data.type="ORTHO"
    cam_data.ortho_scale=14.3
    scene.camera=camera
    bpy.context.view_layer.update()
    def project(point):
        p=world_to_camera_view(scene,camera,Vector(point))
        return [p.x,1-p.y]
    # A single physical scale keeps cottages, guilds and towers proportional.
    metadata={"name":TYPES[key],"type":key,"render_size":[resolution,resolution],
              "logical_size":[240,240],"ground_anchor_normalized":project((0,0,0)),
              "camera_elevation_degrees":30,"ortho_scale":14.3,
              "plot_size":1 if key in ("house","tower") else 2,
              "effects":[{"type":e["type"],"at_normalized":project(e["point"])} for e in effects]}
    (out/f"{key}.json").write_text(json.dumps(metadata,indent=2)+"\n")


def main():
    global g,rng,effects,walls,current_type,plaster,steel,crystal,amber_glass,water,rust,haunt,hides
    parser=argparse.ArgumentParser()
    parser.add_argument("--resolution",type=int,default=1920)
    parser.add_argument("--samples",type=int,default=96)
    parser.add_argument("--only",nargs="*",choices=list(TYPES))
    parser.add_argument("--output",type=Path,default=ROOT/"assets/art/buildings/source")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    args.output.mkdir(parents=True,exist_ok=True)
    for key in args.only or TYPES:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        art.init_materials(THEME)
        current_type=key
        rng=random.Random(19271+list(TYPES).index(key)*173)
        art.RNG=rng
        g=art.geo=art.Geometry()
        effects=[]
        walls=[]
        plaster=art.weathered_material("Aged lime plaster","d1c7af",15)
        steel=art.material("Tempered steel","b5beb9")
        crystal=art.material("Faded violet arcane glass","9185a9",.14)
        amber_glass=art.material("Amber stained glass","d1a454",.16)
        water=art.material("Stagnant olive water","485d43")
        rust=art.weathered_material("Rust and blackened iron","705a43",19)
        haunt=art.material("Faint haunted glass","8faaa1",.23)
        hides=[art.weathered_material("Patched campaign hide "+str(i),c,14)
               for i,c in enumerate(("7c7557","696a49","8b7854","756044"))]
        print("Building",key,flush=True)
        BUILDERS[key]()
        weather(key in ("sewer","graveyard","goblin"))
        g.finish()
        setup_scene(args.resolution,args.samples,args.output,key)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(args.output/f"{key}.blend"))
        bpy.ops.render.render(write_still=True)
        print("Rendered",key,flush=True)


if __name__=="__main__":
    main()
