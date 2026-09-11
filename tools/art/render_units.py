"""Render Sovereign's character miniatures and eight baked animation poses per type."""

import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

sys.path.insert(0,str(Path(__file__).resolve().parent))
import render_palace as art

ROOT=Path(__file__).resolve().parents[2]
TYPES={"warrior":"Warrior","ranger":"Ranger","wizard":"Wizard","guard":"Palace Guard",
       "peasant":"Peasant","collector":"Tax Collector","rat":"Giant Rat",
       "goblin":"Goblin Raider","skeleton":"Restless Skeleton","troll":"Hill Troll","thief":"Thief"}
POSES=["idle"]+[f"walk-{i}" for i in range(4)]+[f"attack-{i}" for i in range(3)]
TAU=math.tau
g=None
M={}


def group(name):
    g.group=name


def ellipsoid(c,r,mat,rings=10,sides=20):
    """Shared vertices give skin and cloth smooth normals without flattening details."""
    vertices,faces=g.parts.setdefault((g.group,mat.name),([],[]))
    start=len(vertices)
    for row in range(rings+1):
        phi=math.pi*row/rings
        for col in range(sides):
            a=TAU*col/sides
            vertices.append((c[0]+r[0]*math.sin(phi)*math.cos(a),
                             c[1]+r[1]*math.sin(phi)*math.sin(a),c[2]+r[2]*math.cos(phi)))
    for row in range(rings):
        for col in range(sides):
            nxt=(col+1)%sides
            faces.append(tuple(start+i for i in (row*sides+col,row*sides+nxt,(row+1)*sides+nxt,(row+1)*sides+col)))


def loft(rings,mat,sides=20):
    vertices,faces=g.parts.setdefault((g.group,mat.name),([],[]))
    start=len(vertices)
    for x,y,z,rx,ry in rings:
        for i in range(sides):
            a=TAU*i/sides
            vertices.append((x+math.cos(a)*rx,y+math.sin(a)*ry,z))
    for row in range(len(rings)-1):
        for i in range(sides):
            j=(i+1)%sides
            faces.append(tuple(start+k for k in (row*sides+i,row*sides+j,(row+1)*sides+j,(row+1)*sides+i)))
    faces.append(tuple(start+i for i in reversed(range(sides))))
    faces.append(tuple(start+(len(rings)-1)*sides+i for i in range(sides)))


def limb(a,b,r1,r2,mat):
    a,b=Vector(a),Vector(b)
    axis=(b-a).normalized()
    tangent=axis.cross(Vector((0,0,1)))
    if tangent.length<.01:tangent=Vector((1,0,0))
    tangent.normalize();other=axis.cross(tangent)
    vertices,faces=g.parts.setdefault((g.group,mat.name),([],[]))
    start=len(vertices);sides=14
    for center,r in ((a,r1),(a.lerp(b,.45),max(r1,r2)*1.035),(b,r2)):
        for i in range(sides):
            vertices.append(tuple(center+r*(math.cos(TAU*i/sides)*tangent+math.sin(TAU*i/sides)*other)))
    for row in range(2):
        for i in range(sides):
            j=(i+1)%sides
            faces.append(tuple(start+k for k in (row*sides+i,row*sides+j,(row+1)*sides+j,(row+1)*sides+i)))
    ellipsoid(a,(r1,r1,r1),mat,6,12)
    ellipsoid(b,(r2,r2,r2),mat,6,12)


def line(points,r,mat):
    for a,b in zip(points,points[1:]):g.rod(a,b,r,mat,8)


def belt(z,width=.255,depth=.155):
    loft([(0,0,z-.042,width,depth),(0,0,z+.042,width,depth)],M["leather"])
    g.box((0,-depth-.012,z),(.105,.034,.092),M["brass"])
    g.box((0,-depth-.033,z),(.061,.015,.051),M["dark"])


def pouch(x,y,z,s=.15):
    ellipsoid((x,y,z),(s,s*.7,s*1.18),M["leather"])
    g.box((x,y-s*.68,z+s*.52),(s*1.7,.034,s*.5),M["leatherLight"])
    ellipsoid((x,y-s*.84,z+s*.4),(.02,.014,.022),M["brass"],6,10)


def face(center,skin,kind="human"):
    x,y,z=center
    gob=kind=="goblin";troll=kind=="troll";skel=kind=="skeleton"
    rx=.25 if gob else .29 if troll else .185
    rz=.28 if gob or troll else .235
    ellipsoid((x,y,z),(rx,.185 if gob or troll else .157,rz),skin,14,24)
    if skel:
        ellipsoid((x,y-.018,z-.14),(.14,.14,.09),skin)
        for dx in (-.086,.086):
            ellipsoid((x+dx,y-.137,z+.02),(.060,.036,.068),M["dark"])
            ellipsoid((x+dx,y-.175,z+.017),(.014,.009,.013),M["haunt"],6,12)
        g.poly([(x-.029,y-.17,z-.035),(x+.029,y-.17,z-.035),(x,y-.187,z-.095)],M["dark"])
        for i in range(6):
            g.box((x-.087+i*.035,y-.144,z-.123),(.027,.037,.048),skin)
        return
    eye_y=y-(.166 if gob or troll else .139)
    for side in (-1,1):
        xx=x+side*(.111 if gob or troll else .076)
        ellipsoid((xx,eye_y,z+.033),(.032,.021,.017),M["ivory"],8,16)
        ellipsoid((xx,eye_y-.018,z+.033),(.014,.010,.014),M["ember"] if gob else M["dark"],8,12)
        line([(xx-side*.035,eye_y-.009,z+.094),(xx+side*.035,eye_y+.001,z+.079)],.021,skin if troll else M["hair"])
    ellipsoid((x,y-(.187 if gob or troll else .156),z-.017),(.069 if gob else .047,.109 if gob else .068,.075),skin)
    line([(x-.05,y-.15,z-.112),(x+.05,y-.15,z-.112)],.008,M["mouth"])
    if gob or troll:
        for side in (-1,1):
            g.frustum(x+side*.104,y-.176,z-.16,.045,.004,.14,M["bone"],10)
        for side in (-1,1):
            g.poly([(x+side*rx*.79,y-.02,z+.06),(x+side*(rx+.31),y+.035,z+.20),
                    (x+side*rx*.9,y-.015,z-.10)],skin)
            g.poly([(x+side*rx*.96,y-.028,z+.05),(x+side*(rx+.23),y+.02,z+.17),
                    (x+side*rx,y-.032,z-.06)],M["goblinShade"])
    else:
        for side in (-1,1):ellipsoid((x+side*.18,y,z),(.037,.047,.065),skin)


def helmet(x,y,z,guard=False):
    group("Steel helm, brow band and cheek guards")
    # A rounded upper shell leaves the face and eyes readable.
    loft([(x,y,z+.02,.194,.17),(x,y,z+.16,.193,.17),(x,y,z+.245,.12,.10),(x,y,z+.27,.025,.025)],M["steel"])
    loft([(x,y,z+.02,.202,.178),(x,y,z+.062,.202,.178)],M["brass"])
    for side in (-1,1):
        g.poly([(x+side*.18,y-.075,z+.02),(x+side*.17,y-.13,z-.15),
                (x+side*.11,y-.166,z-.19),(x+side*.12,y-.17,z+.028)],M["steel"])
    g.box((x,y-.185,z+.003),(.039,.03,.14),M["steelLight"])
    line([(x,y-.14,z+.235),(x,y+.10,z+.24)],.027,M["steelLight"])
    if guard:
        for i in range(7):
            yy=y+.17-i*.047
            ellipsoid((x,yy,z+.31+.048*math.sin(i*.45)),(.055,.052,.12),M["red"])


def sword(hand,axis,length=1.08,rust=False):
    group("Forged blade and leather grip")
    h=Vector(hand);v=Vector(axis).normalized();t=Vector((1,0,0));n=v.cross(t).normalized()
    base=h+v*.14;tip=base+v*length
    mat=M["rust"] if rust else M["steelLight"]
    for sign in (-1,1):
        spine=n*.021*sign
        g.poly([tuple(base-t*.055),tuple(base+spine),tuple(tip),tuple(base+v*length*.82-t*.043)],mat)
        g.poly([tuple(base+spine),tuple(base+t*.055),tuple(base+v*length*.82+t*.043),tuple(tip)],M["steel"] if not rust else M["rust"])
    g.rod(h-t*.17+v*.12,h+t*.17+v*.12,.028,M["brass"],8)
    g.rod(h-v*.12,h+v*.105,.037,M["leather"],10)
    ellipsoid(h-v*.14,(.047,.047,.047),M["brass"],8,12)


def shield(hand,size=.75,wood=False,round_shield=False):
    group("Shield, rim, rivets and heraldry")
    x,y,z=hand;y-=.075
    if round_shield:
        shape=[(math.cos(a)*.42,math.sin(a)*.42) for a in [i*TAU/24 for i in range(24)]]
    else:shape=[(-.34,.41),(.34,.41),(.32,.04),(.19,-.31),(0,-.49),(-.19,-.31),(-.32,.04)]
    front=[(x+u*size,y-.036,z+v*size) for u,v in shape]
    back=[(x+u*size,y+.042,z+v*size) for u,v in shape]
    g.poly(front,M["leatherLight"] if wood else M["red"])
    g.poly(back,M["leather"])
    for i in range(len(front)):
        j=(i+1)%len(front)
        g.poly([front[i],front[j],back[j],back[i]],M["steel"])
        g.rod(front[i],front[j],.021,M["rust"] if wood else M["brass"],8)
    if wood:
        ellipsoid((x,y-.054,z),(.09,.038,.09),M["rust"])
        for dx in (-.18,0,.18):
            g.rod((x+dx*size,y-.04,z-.23*size),(x+dx*size,y-.04,z+.24*size),.008,M["leather"])
    else:
        crown=[(-.17,.035),(-.22,.23),(-.085,.17),(0,.31),(.085,.17),(.22,.23),(.17,.035)]
        g.poly([(x+u*size,y-.061,z+v*size) for u,v in crown],M["ivory"])
        g.rod((x-.16*size,y-.064,z-.018),(x+.16*size,y-.064,z-.018),.018,M["brass"])


def cape(bob,phase,mat,length=.9,width=.34):
    group("Layered cloth cape")
    for row in range(10):
        a,b=row/10,(row+1)/10
        for col in range(10):
            lo,hi=-1+col*.2,-1+(col+1)*.2
            def p(u,t):
                return (u*width*(.8+t*.38),.12+t*.16+.023*math.sin(u*8+phase)*t,
                        1.61+bob-length*t+.027*math.cos(u*9)*t)
            g.poly([p(lo,a),p(hi,a),p(hi,b),p(lo,b)],mat)


def pose_data(type,pose):
    walk=pose.startswith("walk");attack=pose.startswith("attack")
    phase=int(pose[-1])*math.pi/2 if walk else 0
    step=math.cos(phase)*.24 if walk else 0
    bob=.025*math.cos(phase*2) if walk else 0
    stage=int(pose[-1]) if attack else -1
    left=(-.44,-.18-.08*step,1.12+bob)
    right=(.43,-.11+.10*step,1.12+bob)
    weapon=(0,-.09,1)
    if attack:
        right=[(.44,.04,1.94),(.42,-.61,1.32),(.45,-.28,1.03)][stage]
        weapon=[(0,.17,1),(0,-1,-.12),(0,-.58,.79)][stage]
    if type=="ranger":
        left=(-.20,-.58 if attack else -.34,1.38+bob)
        right=(-.13,[-.06,-.53,-.22][stage] if attack else -.17,1.38+bob)
    if type=="wizard":
        right=(.44,-.14,1.25+bob)
        left=[(-.44,-.29,1.60),(-.44,-.70,1.38),(-.44,-.48,1.25)][stage] if attack else (-.44,-.20,1.10+bob)
    if type=="collector":
        left=(-.39,-.18,1.04+bob)
        right=(.39,[-.34,-.48,-.27][stage] if attack else -.24,1.16+bob)
    return phase,step,bob,stage,left,right,weapon


def humanoid(type,pose):
    phase,step,bob,stage,left,right,weapon=pose_data(type,pose)
    armored=type in ("warrior","guard")
    gob=type=="goblin";skel=type=="skeleton";wizard=type=="wizard"
    skin=M["bone"] if skel else M["goblin"] if gob else M["skin"]
    shirt=M["chain"] if armored else M["olive"] if type=="ranger" else M["violet"] if wizard else M["redDark"] if type=="collector" else M["linen"] if type=="peasant" else M["leather"]
    if type=="thief":shirt=M["charcoal"]
    group("Boots, articulated legs and knees")
    for side in (-1,1):
        lift=max(0,math.sin(phase+(math.pi if side<0 else 0)))*.13 if pose.startswith('walk') else 0
        foot=(side*.14,side*step,.10+lift)
        knee=(side*.145,side*step*.42-.05,.51+bob*.25+lift*.28)
        hip=(side*.135,0,.94+bob)
        limb(hip,knee,.073 if skel else .105,.055 if skel else .093,skin if skel else M["trousers"])
        limb(knee,foot,.048 if skel else .10,.04 if skel else .078,skin if skel else M["leather"])
        if skel:
            ellipsoid((foot[0],foot[1]-.05,foot[2]),(.068,.14,.045),skin)
            for i in range(3):g.rod((foot[0]-.047+i*.047,foot[1]-.11,foot[2]),(foot[0]-.047+i*.047,foot[1]-.19,foot[2]-.01),.018,skin)
        else:
            ellipsoid((foot[0],foot[1]-.072,foot[2]),(.094,.182,.079),M["leather"])
            loft([(foot[0],foot[1],.21+lift,.091,.087),(foot[0],foot[1],.40+lift,.10,.093)],M["leather"])
            if armored:
                ellipsoid((knee[0],knee[1]-.06,knee[2]),(.104,.06,.09),M["steel"])
                limb((knee[0],knee[1]-.04,knee[2]-.07),(foot[0],foot[1]-.025,.24+lift),.061,.045,M["steel"])
    group("Torso and layered clothing")
    if skel:
        for i in range(8):ellipsoid((0,.025,.96+bob+i*.087),(.055,.059,.038),skin,7,12)
        for zz,width in ((1.20,.20),(1.29,.245),(1.39,.265),(1.48,.26),(1.56,.22)):
            for side in (-1,1):
                pts=[(side*width*math.sin(a),.02-.13*math.cos(a),zz+bob-.045*math.sin(a)) for a in [i*math.pi/10 for i in range(11)]]
                line(pts,.023,skin)
        g.rod((0,-.118,1.19+bob),(0,-.118,1.57+bob),.028,skin)
        for side in (-1,1):
            ellipsoid((side*.11,0,.96+bob),(.12,.105,.10),skin)
            g.rod((0,0,1.62+bob),(side*.32,.015,1.59+bob),.032,skin)
    else:
        loft([(0,0,.90+bob,.25,.16),(0,0,1.09+bob,.24,.15),(0,0,1.42+bob,.32,.19),
              (0,0,1.59+bob,.33,.17),(0,0,1.70+bob,.14,.115)],shirt)
        if armored:
            loft([(0,-.014,1.1+bob,.251,.164),(0,-.014,1.40+bob,.332,.208),(0,-.012,1.58+bob,.31,.183)],M["steel"])
            g.rod((0,-.213,1.15+bob),(0,-.23,1.49+bob),.016,M["steelLight"])
            for side in (-1,1):
                g.poly([(side*.12,-.19,.82+bob),(side*.24,-.15,.84+bob),(side*.22,-.166,1.2+bob),(side*.1,-.20,1.2+bob)],M["red"])
            cape(bob,phase,M["redDark"],.81,.34)
        elif type in ("ranger","goblin"):
            loft([(0,-.018,1.02+bob,.251,.17),(0,-.018,1.52+bob,.32,.192)],M["leather"])
            if type=="ranger":cape(bob,phase,M["oliveDark"],.91,.40)
            for zz in (1.14,1.28,1.43):
                line([(-.12,-.214,zz+bob),(.12,-.214,zz+.05+bob)],.011,M["linen"])
        elif type=="thief":
            cape(bob,phase,M["charcoal"],.84,.37)
            line([(-.25,-.15,1.60+bob),(0,-.22,1.35+bob),(.22,-.17,1.10+bob)],.035,M["leather"])
            pouch(-.25,-.055,1.04+bob,.12)
            g.poly([(-.19,-.185,.85+bob),(.11,-.20,.82+bob),(.12,-.21,1.07+bob),(-.20,-.18,1.07+bob)],M["redDark"])
        elif type=="peasant":
            for side in (-1,1):
                g.poly([(side*.07,-.195,.81+bob),(side*.22,-.167,.83+bob),(side*.30,-.146,1.53+bob),(side*.16,-.185,1.59+bob)],M["leatherLight"])
            g.poly([(-.21,-.179,.63+bob),(.21,-.179,.63+bob),(.18,-.215,1.13+bob),(-.18,-.215,1.13+bob)],M["leather"])
        elif type=="collector":
            for zz in (1.23,1.34,1.45):ellipsoid((.06,-.194,zz+bob),(.026,.016,.026),M["brass"],7,12)
            line([(-.22,-.146,1.54+bob),(0,-.18,1.39+bob),(.22,-.146,1.54+bob)],.025,M["brass"])
    belt(1.065+bob)
    if not skel:pouch(.255,-.055,.96+bob,.095)
    if wizard:
        group("Long robe, folds and embroidered hems")
        loft([(0,.02,.18,.36,.25),(0,.015,.43,.335,.22),(0,0,.92+bob,.26,.175),(0,0,1.14+bob,.235,.15)],M["violet"])
        for z,rx,ry in ((.22,.363,.254),(.30,.354,.245)):
            loft([(0,.02,z,rx,ry),(0,.02,z+.025,rx,ry)],M["brass"])
        for side in (-1,1):
            line([(side*.12,-.19,1.01+bob),(side*.22,-.231,.51),(side*.25,-.249,.26)],.013,M["violetLight"])
    if gob or skel:
        for i in range(7):
            a=i*TAU/7
            g.poly([(math.cos(a)*.23,math.sin(a)*.17,1.02+bob),
                    (math.cos(a+.7)*.23,math.sin(a+.7)*.17,1.02+bob),
                    (math.cos(a+.65)*.27,math.sin(a+.65)*.19,.73+bob),
                    (math.cos(a+.1)*.28,math.sin(a+.1)*.20,.77+bob)],M["redDark"])
    group("Arms, bracers and hands")
    for side,hand in ((-1,left),(1,right)):
        shoulder=(side*.335,0,1.565+bob)
        elbow=(side*.45,(hand[1]+.03)*.42,(hand[2]+1.54+bob)*.5-.08)
        uppermat=skin if skel or gob else shirt
        limb(shoulder,elbow,.056 if skel else .13,.042 if skel else .095,uppermat)
        limb(elbow,hand,.043 if skel else .082,.032 if skel else .057,skin if skel else M["leather"] if type=="ranger" else shirt)
        if armored:
            ellipsoid(shoulder,(.17,.17,.117),M["steel"])
            limb(Vector(elbow).lerp(Vector(hand),.2),Vector(elbow).lerp(Vector(hand),.85),.094,.072,M["steel"])
            for i in range(3):ellipsoid((shoulder[0],shoulder[1]-.145,shoulder[2]-.028+i*.03),(.025,.02,.022),M["brass"],6,10)
        elif gob and side==1:ellipsoid(shoulder,(.17,.16,.115),M["rust"])
        ellipsoid(hand,(.071 if not skel else .045,.056,.085 if not skel else .065),skin)
        for i in range(3):
            x=hand[0]-.038+i*.038
            g.rod((x,hand[1]-.045,hand[2]+.005),(x,hand[1]-.044,hand[2]-.064),.014 if not skel else .009,skin,6)
    group("Head and neck")
    limb((0,0,1.64+bob),(0,0,1.82+bob),.092,.09,skin)
    head=(0,-.015,1.945+bob)
    face(head,skin,"skeleton" if skel else "goblin" if gob else "human")
    if armored:helmet(*head,guard=type=="guard")
    elif type=="ranger":
        group("Hood, cowl and quiver")
        # Hood sides and a pointed crown frame the exposed face.
        for side in (-1,1):
            ellipsoid((side*.178,.032,1.99+bob),(.063,.179,.232),M["oliveDark"])
        loft([(0,.025,2.09+bob,.215,.198),(0,.06,2.26+bob,.147,.15),(0,.12,2.40+bob,.025,.025)],M["olive"])
        loft([(0,.018,1.65+bob,.235,.18),(0,.018,1.78+bob,.135,.13)],M["oliveDark"])
        limb((.19,.23,1.13+bob),(.26,.25,1.76+bob),.088,.096,M["leather"])
        for i in range(5):
            x=.21+(i%3)*.031;y=.25+(i//3)*.039
            g.rod((x,y,1.58+bob),(x+.04,y,2.01+bob),.012,M["wood"],6)
            g.poly([(x+.022,y,1.88+bob),(x+.063,y,1.95+bob),(x+.04,y,2.02+bob)],M["ivory"])
    elif type=="thief":
        group("Charcoal hood and masked face")
        for side in (-1,1):
            ellipsoid((side*.176,.033,1.99+bob),(.061,.177,.22),M["charcoal"])
        loft([(0,.025,2.09+bob,.21,.195),(0,.05,2.25+bob,.13,.14),(0,.11,2.34+bob,.025,.025)],M["charcoal"])
        loft([(0,.018,1.65+bob,.23,.18),(0,.018,1.78+bob,.135,.13)],M["charcoal"])
        g.poly([(-.14,-.145,1.93+bob),(.14,-.145,1.93+bob),(.12,-.15,1.81+bob),(0,-.19,1.76+bob),(-.12,-.15,1.81+bob)],M["charcoal"])
    elif wizard:
        group("Pointed hat and silver beard")
        loft([(0,0,2.09+bob,.30,.25),(0,0,2.15+bob,.30,.25)],M["violetDark"])
        loft([(0,0,2.14+bob,.18,.17),(.0,.03,2.51+bob,.13,.11),(.045,.11,2.83+bob,.018,.02)],M["violet"])
        loft([(0,0,2.165+bob,.181,.17),(0,.003,2.21+bob,.175,.165)],M["brass"])
        for side in (-1,1):ellipsoid((side*.165,.025,1.94+bob),(.044,.16,.22),M["silverHair"])
        loft([(0,-.153,1.85+bob,.125,.057),(0,-.18,1.68+bob,.105,.064),(.013,-.22,1.46+bob,.011,.015)],M["silverHair"])
        for dx in (-.054,0,.054):line([(dx,-.216,1.8+bob),(dx*.6,-.245,1.62+bob),(.013,-.235,1.48+bob)],.007,M["ivory"])
    elif type in ("peasant","collector"):
        ellipsoid((0,.01,2.13+bob),(.186,.17,.08),M["hair"])
        group("Brimmed hat")
        hat=M["straw"] if type=="peasant" else M["leatherDark"]
        loft([(0,0,2.12+bob,.29,.25),(0,0,2.16+bob,.29,.25)],hat)
        loft([(0,0,2.15+bob,.175,.155),(0,.025,2.34+bob,.124,.114)],hat)
        loft([(0,0,2.18+bob,.174,.155),(0,.005,2.22+bob,.165,.15)],M["leather"] if type=="peasant" else M["red"])
        if type=="collector":
            line([(.12,.04,2.19+bob),(.23,.12,2.58+bob)],.013,M["brass"])
            g.poly([(.18,.085,2.35+bob),(.21,.12,2.59+bob),(.31,.16,2.5+bob)],M["ivory"])
    elif skel:
        loft([(0,.03,2.06+bob,.19,.172),(0,.03,2.21+bob,.10,.092),(0,.03,2.25+bob,.01,.01)],M["rust"])
    elif gob:
        loft([(0,.055,2.12+bob,.22,.17),(0,.08,2.24+bob,.06,.05)],M["leatherDark"])
    if type=="warrior":
        sword(right,weapon)
        shield((left[0],left[1],left[2]+.12),.97)
    elif type=="thief":
        group("Twin steel daggers")
        sword(right,weapon,.56)
        sword(left,(0,-.5,.6),.43)
    elif type=="guard":
        group("Royal halberd")
        h=Vector(right);v=Vector(weapon).normalized();t=Vector((1,0,0));n=v.cross(t).normalized()
        g.rod(h-v*.68,h+v*1.05,.032,M["wood"],10)
        tip=h+v*.98
        g.poly([tuple(tip-t*.065),tuple(tip+t*.065),tuple(tip+v*.31)],M["steelLight"])
        g.poly([tuple(tip-v*.03),tuple(tip+t*.25-v*.06),tuple(tip+t*.28-v*.31),tuple(tip-v*.28)],M["steel"])
        shield((left[0],left[1],left[2]+.12),.82,round_shield=True)
    elif type=="ranger":
        group("Recurve bow, bowstring and arrow")
        h=Vector(left);top=h+Vector((0,.10,.56));bottom=h+Vector((0,.10,-.56))
        pts=[h+Vector((0,.10-.15*math.cos(a),.56*math.sin(a))) for a in [-math.pi/2+i*math.pi/20 for i in range(21)]]
        line(pts,.022,M["wood"])
        nock=Vector(right) if stage>=0 else h+Vector((0,.08,0))
        line([top,nock,bottom],.006,M["ivory"])
        if stage!=1:
            tip=nock+Vector((0,-.96,0))
            g.rod(nock,tip,.011,M["wood"],6)
            g.poly([tuple(tip+Vector((-.027,.07,0))),tuple(tip+Vector((.027,.07,0))),tuple(tip-Vector((0,.08,0)))],M["steel"])
    elif wizard:
        group("Carved staff, crystal and spellbook")
        x,y=right[0],right[1]
        line([(x,y,.17),(x-.035,y,1.42),(x+.04,y,2.45)],.036,M["wood"])
        for side in (-1,1):line([(x+.015,y,2.26),(x+side*.135,y,2.47),(x+side*.075,y,2.68)],.024,M["brass"])
        loft([(x,y,2.38,.07,.07),(x,y,2.51,.13,.11),(x,y,2.69,.012,.012)],M["crystal"],6)
        g.box((-.25,-.05,1.02+bob),(.18,.15,.27),M["violetDark"])
        g.box((-.255,-.13,1.02+bob),(.15,.025,.235),M["brass"])
        if stage>=0:
            radius=[.08,.14,.065][stage]
            ellipsoid((left[0],left[1]-.11,left[2]+.14),(radius,radius,radius*1.2),M["magic"],10,16)
    elif type=="peasant":
        group("Carpenter's mallet and tool belt")
        h=Vector(right);v=Vector(weapon).normalized()
        g.rod(h-v*.08,h+v*.40,.031,M["wood"],10)
        end=h+v*.4
        g.box(end,(.31,.15,.16),M["woodLight"])
        for side in (-1,1):g.box(end+Vector((side*.145,0,0)),(.027,.16,.17),M["steel"])
        g.rod((-.20,-.12,.78+bob),(-.20,-.12,1.07+bob),.015,M["steel"])
    elif type=="collector":
        group("Ledger, coin purse and shoulder strap")
        g.box((right[0],right[1]-.05,right[2]),(.20,.10,.28),M["leatherDark"])
        g.box((right[0]+.009,right[1]-.108,right[2]),(.17,.025,.23),M["linen"])
        pouch(left[0],left[1],left[2]-.06,.205)
        line([(-.20,.025,1.59+bob),(.23,-.192,1.1+bob),(.29,-.03,.98+bob)],.036,M["leather"])
        for i in range(3):ellipsoid((left[0]-.05+i*.045,left[1]-.03,left[2]+.14),(.027,.02,.014),M["brass"],7,12)
    elif gob or skel:
        sword(right,weapon,.68 if gob else .92,True)
        shield((left[0],left[1],left[2]+.05),.64,wood=True,round_shield=True)
    # Goblins remain small and wiry beside human units, including their equipment.
    if gob:
        for vertices,_ in g.parts.values():
            for i,(x,y,z) in enumerate(vertices):vertices[i]=(x*.78,y*.80,z*.76)


def rat(pose):
    walk=pose.startswith("walk");phase=int(pose[-1])*math.pi/2 if walk else 0
    stage=int(pose[-1]) if pose.startswith("attack") else -1
    lunge=[.08,-.16,-.04][stage] if stage>=0 else 0
    group("Rat haunches, body and narrow muzzle")
    ellipsoid((0,.14+lunge,.35),(.29,.54,.27),M["fur"])
    ellipsoid((0,-.28+lunge,.36),(.235,.40,.23),M["furLight"])
    ellipsoid((0,-.57+lunge,.37),(.21,.29,.20),M["furLight"])
    ellipsoid((0,-.80+lunge,.29),(.125,.22,.11),M["furLight"])
    ellipsoid((0,-1.0+lunge,.31),(.07,.04,.044),M["pink"])
    for side in (-1,1):
        ellipsoid((side*.2,-.46+lunge,.57),(.132,.056,.17),M["furLight"])
        ellipsoid((side*.2,-.501+lunge,.582),(.087,.015,.116),M["pink"])
        ellipsoid((side*.168,-.651+lunge,.48),(.026,.023,.028),M["dark"],10,16)
        ellipsoid((side*.18,-.666+lunge,.489),(.006,.008,.007),M["ivory"],6,10)
        for yy in (-.41,.37):
            stride=math.cos(phase+(0 if (side>0)==(yy>0) else math.pi))*.10 if walk else 0
            leg=(side*.24,yy,.29)
            foot=(side*.31,yy+stride-.045,.057)
            limb(leg,foot,.07,.035,M["fur"])
            ellipsoid((foot[0],foot[1]-.04,foot[2]),(.065,.11,.035),M["pink"])
            for i in range(3):g.rod((foot[0]-.037+i*.035,foot[1]-.06,.05),(foot[0]-.037+i*.035,foot[1]-.15,.041),.01,M["bone"],6)
        for i in range(3):
            line([(side*.081,-.83+lunge,.32),(side*(.30+i*.08),-.82+lunge+i*.06,.33+i*.019)],.004,M["ivory"])
    for x in (-.024,.024):g.frustum(x,-.934+lunge,.175,.020,.012,.084,M["bone"],8)
    if stage==1:ellipsoid((0,-.85+lunge,.23),(.061,.11,.027),M["mouth"])
    group("Segmented curved tail")
    pts=[]
    for i in range(17):
        t=i/16
        pts.append((.25*math.sin(t*5+phase*.2)*t,.59+t*.99,.18-.10*t+.065*math.sin(t*5)))
    for i,(a,b) in enumerate(zip(pts,pts[1:])):limb(a,b,.047*(1-i/18),.045*(1-(i+1)/18),M["pink"])


def troll(pose):
    phase=int(pose[-1])*math.pi/2 if pose.startswith('walk') else 0
    step=math.cos(phase)*.25 if pose.startswith('walk') else 0
    stage=int(pose[-1]) if pose.startswith('attack') else -1
    bob=.035*math.cos(phase*2) if pose.startswith('walk') else 0
    group("Heavy troll legs and broad feet")
    for side in (-1,1):
        lift=max(0,math.sin(phase+(math.pi if side<0 else 0)))*.12 if pose.startswith('walk') else 0
        foot=(side*.33,side*step,.15+lift)
        knee=(side*.36,side*step*.3,.65)
        limb((side*.28,0,1.24+bob),knee,.24,.22,M['troll'])
        limb(knee,foot,.20,.16,M['troll'])
        ellipsoid((foot[0],foot[1]-.13,.15+lift),(.23,.34,.15),M['troll'])
        for i in range(3):
            ellipsoid((foot[0]-.135+i*.135,foot[1]-.38,.12+lift),(.052,.11,.052),M['bone'])
    group("Stooped muscular torso and belly")
    ellipsoid((0,.08,1.77+bob),(.66,.44,.74),M['troll'])
    ellipsoid((0,-.16,1.58+bob),(.53,.39,.46),M['trollLight'])
    ellipsoid((0,.15,2.36+bob),(.70,.38,.43),M['troll'])
    head=(0,-.20,2.84+bob)
    limb((0,.03,2.32+bob),head,.28,.22,M['troll'])
    face(head,M['trollLight'],'troll')
    group("Coarse hair, shoulder growths and brow")
    for i in range(7):
        xx=-.21+i*.07
        g.frustum(xx,-.04,3.015+bob,.061,0,.20+.05*math.sin(i),M['hair'],7)
    for side in (-1,1):
        ellipsoid((side*.45,.28,2.55+bob),(.22,.12,.11),M['moss'])
        for i in range(3):
            g.frustum(side*(.37+i*.13),.22,2.54+bob,.085,0,.17+abs(i-1)*.08,M['stone'],6)
    left=(-.86,-.32,1.47+bob)
    right=[(.75,.08,2.99),(.8,-.77,2.04),(.82,-.34,1.3)][stage] if stage>=0 else (.88,-.1,1.47+bob)
    group("Long muscular arms and leather bracers")
    for side,hand in ((-1,left),(1,right)):
        shoulder=(side*.61,.04,2.31+bob)
        elbow=(side*.85,hand[1]*.4,(2.15+hand[2])/2)
        limb(shoulder,elbow,.25,.22,M['troll'])
        limb(elbow,hand,.24,.16,M['troll'])
        ellipsoid(hand,(.20,.15,.20),M['trollLight'])
        mid=Vector(elbow).lerp(Vector(hand),.75)
        limb(mid,Vector(elbow).lerp(Vector(hand),.94),.195,.175,M['leatherDark'])
        for i in range(3):ellipsoid((hand[0]-.1+i*.10,hand[1]-.15,hand[2]-.03),(.047,.035,.065),M['trollLight'])
    group("Ragged hide loincloth")
    for i in range(14):
        a=i*TAU/14;b=(i+1)*TAU/14
        g.poly([(math.cos(a)*.49,math.sin(a)*.35,1.36+bob),(math.cos(b)*.49,math.sin(b)*.35,1.36+bob),
                (math.cos(b)*.53,math.sin(b)*.37,.93+.04*math.cos(i*3)),(math.cos(a)*.53,math.sin(a)*.37,.90+.06*math.sin(i*2))],M['leatherDark'] if i%2 else M['leather'])
    loft([(0,0,1.33+bob,.51,.36),(0,0,1.45+bob,.50,.35)],M['leather'])
    group("Iron-bound knotted club")
    hand=Vector(right)
    axis=Vector([(0,.1,1),(0,-.95,.13),(0,-.4,.9)][stage] if stage>=0 else (0,-.25,1)).normalized()
    end=hand+axis*1.03
    limb(hand-axis*.15,end,.077,.155,M['wood'])
    ellipsoid(end,(.24,.20,.28),M['woodLight'])
    for i in range(5):
        a=i*TAU/5
        p=end+Vector((math.cos(a)*.19,math.sin(a)*.15,0))
        ellipsoid(p,(.063,.064,.08),M['rust'],7,10)


def materials():
    colors={"charcoal":"46484b","skin":"d2aa81","leather":"72573d","leatherLight":"957650","leatherDark":"4d4434",
            "linen":"d9ceb1","trousers":"565b4b","olive":"7b8956","oliveDark":"526845",
            "red":"b52e20","redDark":"7d3828","ivory":"ece6cf","brass":"b89c63",
            "steel":"aab5b4","steelLight":"dce0d7","chain":"646f6e","dark":"202c29",
            "wood":"66503a","woodLight":"9a7950","hair":"514d3d","silverHair":"ccc9b9",
            "violet":"898397","violetLight":"bbb0bd","violetDark":"595366","straw":"c2a365",
            "mouth":"80574a","goblin":"84965b","goblinShade":"667543","troll":"768368",
            "trollLight":"959d7c","moss":"5f733a","stone":"90978a","bone":"d7cfb8",
            "rust":"7e654c","fur":"736657","furLight":"978674","pink":"b58d80",
            "ember":"aa783d","haunt":"a1b9a7","crystal":"c4a05d","magic":"e6c38c"}
    for name,color in colors.items():
        if name in ('magic','crystal','haunt'):
            M[name]=art.material(name,color,.35 if name!='magic' else .9)
        elif name in ('dark','ivory','brass','steel','steelLight','bone','pink','skin'):
            M[name]=art.material(name,color)
        else:M[name]=art.weathered_material(name,color,32)
        shader=M[name].node_tree.nodes.get('Principled BSDF')
        if name in ('steel','steelLight','brass'):
            shader.inputs['Metallic'].default_value=.5
            shader.inputs['Roughness'].default_value=.45


def setup(resolution,samples,target_height=1.55):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.device='CPU'
    scene.cycles.samples=samples;scene.cycles.use_denoising=True;scene.cycles.max_bounces=6
    scene.render.threads_mode='FIXED';scene.render.threads=10
    scene.render.resolution_x=scene.render.resolution_y=resolution;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    world=bpy.data.worlds.new('Palace daylight');world.use_nodes=True;scene.world=world
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.52,.62,.76,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4
    light_data=bpy.data.lights.new('Warm afternoon key','AREA')
    light_data.energy=2600;light_data.shape='DISK';light_data.size=6;light_data.color=(1,.93,.82)
    light=bpy.data.objects.new('Warm afternoon key',light_data);scene.collection.objects.link(light)
    light.location=(-7,-10,16);light.rotation_euler=(Vector((0,0,2))-light.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.cameras.new('Shared isometric camera');camera=bpy.data.objects.new('Shared isometric camera',cam)
    scene.collection.objects.link(camera);target=Vector((0,0,target_height))
    camera.location=target+Vector((18,-18,math.sqrt(18**2+18**2)*math.tan(math.radians(30))))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    cam.type='ORTHO';cam.ortho_scale=5.4;scene.camera=camera
    bpy.context.view_layer.update()
    def project(point):
        p=world_to_camera_view(scene,camera,Vector(point));return [p.x,1-p.y]
    return scene,project


def main():
    global g
    parser=argparse.ArgumentParser()
    parser.add_argument('--resolution',type=int,default=960)
    parser.add_argument('--samples',type=int,default=48)
    parser.add_argument('--only',nargs='*',choices=list(TYPES))
    parser.add_argument('--poses',nargs='*',choices=POSES)
    parser.add_argument('--output',type=Path,default=ROOT/'assets/art/units/source')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output.mkdir(parents=True,exist_ok=True)
    poses=args.poses or POSES
    for type in args.only or TYPES:
        bpy.ops.wm.read_factory_settings(use_empty=True);M.clear();materials()
        scene,project=setup(args.resolution,args.samples,2.15 if type=='troll' else 1.55);pose_objects=[]
        for pose in poses:
            for objs in pose_objects:
                for obj in objs:obj.hide_render=True;obj.hide_viewport=True
            g=art.Geometry();before=set(bpy.data.objects)
            if type=='rat':rat(pose)
            elif type=='troll':troll(pose)
            else:humanoid(type,pose)
            g.finish()
            objects=[o for o in bpy.data.objects if o not in before]
            collection=bpy.data.collections.new(type+' / '+pose);scene.collection.children.link(collection)
            for obj in objects:
                obj.rotation_euler.z=math.pi/2
                for poly in obj.data.polygons:poly.use_smooth=True
                for old in list(obj.users_collection):old.objects.unlink(obj)
                collection.objects.link(obj)
            pose_objects.append(objects)
            scene.render.filepath=str(args.output/f'{type}-{pose}.png')
            bpy.ops.render.render(write_still=True)
            print('Rendered',type,pose,flush=True)
        # Baked pose visibility makes the Blender timeline useful without external files.
        scene.render.fps=7;scene.frame_start=1;scene.frame_end=len(poses)
        for frame in range(len(poses)):
            for i,objects in enumerate(pose_objects):
                for obj in objects:
                    obj.hide_render=obj.hide_viewport=(frame!=i)
                    obj.keyframe_insert(data_path='hide_render',frame=frame+1)
                    obj.keyframe_insert(data_path='hide_viewport',frame=frame+1)
        scene.frame_set(1)
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(args.output/f'{type}.blend'))
        metadata={'name':TYPES[type],'type':type,'poses':poses,'render_size':[args.resolution,args.resolution],
                  'logical_size':[96,96],'anchor_normalized':project((0,0,0)),
                  'selection_normalized':project((0,0,.3 if type=='rat' else 1.55 if type=='troll' else 1.02 if type!='goblin' else .78)),
                  'selection_radius':14 if type=='rat' else 29 if type=='troll' else 20,
                  'facing':'right; mirrored by the game for left-facing units',
                  'animation_fps':7,'camera_elevation_degrees':30,'ortho_scale':5.4}
        (args.output/f'{type}.json').write_text(json.dumps(metadata,indent=2)+'\n')
        print('Completed',type,flush=True)


if __name__=='__main__':main()
