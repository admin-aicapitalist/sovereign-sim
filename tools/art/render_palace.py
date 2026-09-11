"""Build and render Sovereign's original palace with Blender's Python API.

blender --background --factory-startup --python-exit-code 1 \
  --python tools/art/render_palace.py -- --resolution 1920 --samples 128
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


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/palace"
RNG = random.Random(7331)
TAU = math.tau


def linear(v):
    return v / 12.92 if v < 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def material(name, color, emission=0):
    rgb = tuple(linear(int(color[i:i + 2], 16) / 255) for i in (0, 2, 4))
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = 0.86
    if emission:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return m


def weathered_material(name,color,scale=19):
    m=material(name,color)
    nodes=m.node_tree.nodes
    links=m.node_tree.links
    shader=nodes.get("Principled BSDF")
    base=tuple(shader.inputs["Base Color"].default_value)
    coordinates=nodes.new("ShaderNodeNewGeometry")
    noise=nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value=scale
    noise.inputs["Detail"].default_value=2.4
    noise.inputs["Roughness"].default_value=.72
    links.new(coordinates.outputs["Position"],noise.inputs["Vector"])
    ramp=nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position=.2
    ramp.color_ramp.elements[0].color=(.63,.66,.64,1)
    ramp.color_ramp.elements[1].position=.81
    ramp.color_ramp.elements[1].color=(1.11,1.09,1.04,1)
    links.new(noise.outputs["Fac"],ramp.inputs["Fac"])
    tint=nodes.new("ShaderNodeMixRGB")
    tint.blend_type="MULTIPLY"
    tint.inputs[0].default_value=1
    tint.inputs[1].default_value=base
    links.new(ramp.outputs["Color"],tint.inputs[2])
    links.new(tint.outputs["Color"],shader.inputs["Base Color"])
    bump=nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value=.17
    bump.inputs["Distance"].default_value=.023
    links.new(noise.outputs["Fac"],bump.inputs["Height"])
    links.new(bump.outputs["Normal"],shader.inputs["Normal"])
    return m


class Geometry:
    """Batch geometry by architectural component and material for an editable scene."""

    def __init__(self):
        self.parts = {}
        self.group = "Palace"

    def poly(self, vertices, mat):
        verts, faces = self.parts.setdefault((self.group, mat.name), ([], []))
        faces.append(tuple(range(len(verts), len(verts) + len(vertices))))
        verts.extend(vertices)

    def box(self, center, size, mat):
        x, y, z = center
        w, d, h = (v / 2 for v in size)
        p = [(x-w,y-d,z-h), (x+w,y-d,z-h), (x+w,y+d,z-h), (x-w,y+d,z-h),
             (x-w,y-d,z+h), (x+w,y-d,z+h), (x+w,y+d,z+h), (x-w,y+d,z+h)]
        for f in ((0,3,2,1), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)):
            self.poly([p[i] for i in f], mat)

    def frustum(self, x, y, z, r0, r1, height, mat, sides=12, offset=0):
        lower = [(x+r0*math.cos(i*TAU/sides+offset), y+r0*math.sin(i*TAU/sides+offset), z) for i in range(sides)]
        upper = [(x+r1*math.cos(i*TAU/sides+offset), y+r1*math.sin(i*TAU/sides+offset), z+height) for i in range(sides)]
        for i in range(sides):
            j = (i+1) % sides
            self.poly([lower[i],lower[j],upper[j],upper[i]], mat)
        self.poly(list(reversed(lower)), mat)
        self.poly(upper, mat)

    def chipped_box(self, center, size, mat):
        x,y,z=center
        w,d,h=(v/2 for v in size)
        profile=[(-w,-h),(w,-h),(w,h*.34),(w*.32,h*.46),(-w*.17,h),(-w,h)]
        front=[(x+u,y-d,z+v) for u,v in profile]
        back=[(x+u,y+d,z+v) for u,v in profile]
        self.poly(front,mat)
        self.poly(list(reversed(back)),mat)
        for i in range(len(profile)):
            j=(i+1)%len(profile)
            self.poly([front[i],back[i],back[j],front[j]],
                      exposed_stone if i in (2,3) else mat)

    def rod(self, start, end, radius, mat, sides=6):
        a, b = Vector(start), Vector(end)
        direction = (b-a).normalized()
        tangent = direction.cross(Vector((0, 0, 1)))
        if tangent.length < 0.001:
            tangent = Vector((1, 0, 0))
        tangent.normalize()
        other = direction.cross(tangent)
        p, q = [], []
        for i in range(sides):
            shift = radius * (math.cos(i*TAU/sides)*tangent + math.sin(i*TAU/sides)*other)
            p.append(tuple(a+shift))
            q.append(tuple(b+shift))
        for i in range(sides):
            j = (i+1) % sides
            self.poly([p[i],p[j],q[j],q[i]], mat)
        self.poly(q, mat)

    def finish(self):
        for (group, mat), (vertices, faces) in self.parts.items():
            mesh = bpy.data.meshes.new(group + " mesh")
            mesh.from_pydata(vertices, [], faces)
            mesh.update()
            obj = bpy.data.objects.new(group + " · " + mat, mesh)
            bpy.context.collection.objects.link(obj)
            obj.data.materials.append(bpy.data.materials[mat])


def point_on_face(u, depth, z, center, angle):
    """Local u is across a wall; negative local depth is outside the front face."""
    x, y = center
    return (x + u*math.cos(angle)-depth*math.sin(angle),
            y + u*math.sin(angle)+depth*math.cos(angle), z)


def arch(center, angle, bottom, width, height, fill, trim, thickness=0.09):
    radius = width / 2
    spring = bottom + height - radius
    inner = [(-radius,bottom),(radius,bottom)]
    inner += [(radius*math.cos(i*math.pi/12),spring+radius*math.sin(i*math.pi/12)) for i in range(13)]
    geo.poly([point_on_face(u,-0.023,z,center,angle) for u,z in inner], fill)
    # Cut stone voussoirs around the arch, plus alternating jamb stones.
    for i in range(9):
        a0, a1 = i*math.pi/9+0.012, (i+1)*math.pi/9-0.012
        geo.poly([point_on_face(r*math.cos(a),-0.046,spring+r*math.sin(a),center,angle)
                  for r,a in ((radius,a0),(radius,a1),(radius+thickness,a1),(radius+thickness,a0))],
                 trim if i % 3 else stone_light)
    rows = max(2, round((height-radius)/0.25))
    for side in (-1,1):
        for i in range(rows):
            z0 = bottom+(spring-bottom)*i/rows
            z1 = bottom+(spring-bottom)*(i+1)/rows-0.014
            geo.poly([point_on_face(u,-0.043,z,center,angle) for u,z in
                      ((side*radius,z0),(side*(radius+thickness),z0),(side*(radius+thickness),z1),(side*radius,z1))],trim)


def window(center, angle, bottom, width=0.38, height=0.78, lit=False):
    arch(center,angle,bottom,width,height,glass if not lit else amber,stone_light,0.085)
    r = width/2
    geo.rod(point_on_face(0,-0.058,bottom+0.06,center,angle),
            point_on_face(0,-0.058,bottom+height-0.1,center,angle),0.022,stone_trim)
    geo.rod(point_on_face(-r+0.04,-0.06,bottom+height*0.44,center,angle),
            point_on_face(r-0.04,-0.06,bottom+height*0.44,center,angle),0.021,stone_trim)
    a = point_on_face(-r-0.1,-0.06,bottom-0.025,center,angle)
    b = point_on_face(r+0.1,-0.06,bottom-0.025,center,angle)
    geo.rod(a,b,0.056,stone_light,4)


def masonry_box(center, size, courses=True):
    x,y,z = center
    w,d,h = size
    geo.box(center,size,stone_mortar)
    if not courses:
        return
    count = max(1,round(h/0.28))
    ch = h/count
    for row in range(count):
        zz = z-h/2+(row+0.5)*ch
        for front in (True,False):
            extent = w if front else d
            starts = [-extent/2]
            cursor = -extent/2+ (0.33 if row%2 else 0.58)
            while cursor < extent/2-0.08:
                starts.append(cursor)
                cursor += RNG.uniform(0.48,0.75)
            starts.append(extent/2)
            for left,right in zip(starts,starts[1:]):
                mid = (left+right)/2
                mat = RNG.choice(stones)
                if front:
                    geo.box((x+mid,y-d/2-0.008,zz),(right-left-0.018,0.026,ch-0.018),mat)
                else:
                    geo.box((x+w/2+0.008,y+mid,zz),(0.026,right-left-0.018,ch-0.018),mat)
    # Reinforced corner quoins are deliberately larger and lighter.
    for row in range(max(1,round(h/0.42))):
        zz = z-h/2+row*0.42+0.2
        for xx in (x-w/2,x+w/2):
            geo.box((xx,y-d/2-0.024,zz),(0.24 if row%2 else 0.37,0.07,0.38),stone_trim)


def hip_roof(x,y,z,half_x,half_y,height,rows=10):
    geo.box((x,y,z-0.04),(half_x*2+0.1,half_y*2+0.1,0.11),roof_dark)
    def rectangle(t, extra=0):
        a = half_x*(1-t)+0.17*t+extra
        b = half_y*(1-t)+0.58*t+extra
        return [(x-a,y-b,z+height*t),(x+a,y-b,z+height*t),
                (x+a,y+b,z+height*t),(x-a,y+b,z+height*t)]
    for row in range(rows):
        lo,hi = rectangle(row/rows,0.035),rectangle((row+1)/rows)
        for face in range(4):
            j=(face+1)%4
            num=max(2,round((Vector(lo[j])-Vector(lo[face])).length/0.18))
            for col in range(num):
                s0,s1=col/num+0.008/num,(col+1)/num-0.008/num
                verts=[Vector(a).lerp(Vector(b),t) for a,b,t in
                       ((lo[face],lo[j],s0),(lo[face],lo[j],s1),(hi[face],hi[j],s1),(hi[face],hi[j],s0))]
                geo.poly([tuple(v) for v in verts],RNG.choice(roofs))
                # Small losses of the glazed tile surface expose pale clay.
                if RNG.random()<.095:
                    a,b,c,d=verts
                    geo.poly([tuple(a+Vector((0,0,.009))),
                              tuple(a.lerp(b,.25)+Vector((0,0,.009))),
                              tuple(a.lerp(d,.20)+Vector((0,0,.009)))],roof_chip)
    geo.box((x,y,z+height+0.025),(0.39,1.24,0.075),roof_ridge)


def banner(center, angle, bottom, width, height):
    r=width/2
    shape=[(-r,bottom+height),(r,bottom+height),(r,bottom+.18),
           (r*.62,bottom+.22),(r*.52,bottom+.07),(r*.28,bottom+.12),
           (0,bottom),(-r*.45,bottom+.17),(-r*.7,bottom+.13),(-r,bottom+.2)]
    geo.poly([point_on_face(u,-0.075,z,center,angle) for u,z in shape],cloth)
    for side in (-1,1):
        geo.rod(point_on_face(side*(r-0.04),-0.086,bottom+0.19,center,angle),
                point_on_face(side*(r-0.04),-0.086,bottom+height-0.04,center,angle),0.018,gold)
    # Ivory crown on crimson, echoing the reference's faction accents.
    z=bottom+height*0.63
    crown=[(-r*.57,z),(-r*.7,z+width*.27),(-r*.26,z+width*.17),(0,z+width*.4),
           (r*.26,z+width*.17),(r*.7,z+width*.27),(r*.57,z)]
    geo.poly([point_on_face(u,-0.095,zz,center,angle) for u,zz in crown],gold_light)
    geo.rod(point_on_face(-r*.5,-0.1,z-.06,center,angle),point_on_face(r*.5,-0.1,z-.06,center,angle),0.021,gold)
    geo.rod(point_on_face(-r-.09,-0.1,bottom+height+.04,center,angle),
            point_on_face(r+.09,-0.1,bottom+height+.04,center,angle),0.034,gold)


def flag(x,y,z,size=1):
    geo.rod((x,y,z),(x,y,z+1.48*size),0.028*size,gold)
    geo.frustum(x,y,z+1.48*size,0.065*size,0,0.14*size,gold_light,6)
    # Flag runs along world X: a broad readable shape under this camera.
    for i in range(12):
        def p(t,lower=False):
            return (x+t*1.13*size,y+math.sin(t*7)*0.12*size,
                    z+(1.36-0.06*t-(0.46-0.17*max(0,(t-.7)/.3) if lower else 0))*size)
        a,b=i/12,(i+1)/12
        geo.poly([p(a),p(b),p(b,True),p(a,True)],cloth if i<2 else flag_gold)
    # A crimson lozenge sits on the ivory field.
    middle_z=z+1.09*size
    def mark(t,dz):
        return (x+t*1.13*size,y+math.sin(t*7)*.12*size-.008,middle_z+dz*size)
    geo.poly([mark(.49,0),mark(.61,.16),mark(.74,0),mark(.61,-.16)],cloth)


def tower(name,x,y,height,radius=0.82,roof_height=1.72,standard=True):
    geo.group=name
    geo.frustum(x,y,0.27,radius+0.19,radius+0.1,0.33,stone_trim)
    count=round((height-0.55)/0.3)
    for row in range(count):
        zz=0.55+row*(height-0.55)/count
        hh=(height-0.55)/count
        n=12
        for i in range(n):
            a0=i*TAU/n+0.003
            a1=(i+1)*TAU/n-0.003
            pts=[(x+radius*math.cos(a),y+radius*math.sin(a),z)
                 for a,z in ((a0,zz),(a1,zz),(a1,zz+hh-.016),(a0,zz+hh-.016))]
            geo.poly(pts,RNG.choice(stones))
    geo.frustum(x,y,0.49,radius*.992,radius*.992,height-.46,stone_mortar)
    for zz in (1.0,height-1.08,height-.24):
        geo.frustum(x,y,zz,radius+.045,radius+.045,.12,
                    cloth if abs(zz-(height-.24))<.01 else stone_trim)
    for a in (-math.pi/2,0,math.pi/2):
        center=(x+(radius*.968+.014)*math.cos(a),y+(radius*.968+.014)*math.sin(a))
        window(center,a+math.pi/2,height-1.08,.31,.66,lit=(a==0))
        if height>4.5:
            window(center,a+math.pi/2,height-2.7,.25,.58)
    geo.frustum(x,y,height-.06,radius+.09,radius+.16,.2,stone_light)
    for i in range(12):
        a=i*TAU/12
        geo.box((x+(radius+.035)*math.cos(a),y+(radius+.035)*math.sin(a),height-.31),(.16,.16,.22),stone_trim)
    # Dense, overlapping clay tiles on faceted conical roofs.
    geo.group=name+" roof"
    roof_rows,roof_sides=14,24
    for row in range(roof_rows):
        lo=row/roof_rows
        hi=(row+1)/roof_rows
        r0=(radius+.3)*(1-lo)+.035
        r1=(radius+.3)*(1-hi)+.035
        for i in range(roof_sides):
            a0,a1=i*TAU/roof_sides,(i+1)*TAU/roof_sides
            geo.poly([(x+r0*math.cos(a0),y+r0*math.sin(a0),height+.13+lo*roof_height),
                      (x+r0*math.cos(a1),y+r0*math.sin(a1),height+.13+lo*roof_height),
                      (x+r1*math.cos(a1),y+r1*math.sin(a1),height+.13+hi*roof_height),
                      (x+r1*math.cos(a0),y+r1*math.sin(a0),height+.13+hi*roof_height)],RNG.choice(roofs))
    geo.frustum(x,y,height+.13+roof_height,.1,.035,.24,gold,8)
    if standard:
        flag(x,y,height+.32+roof_height,.76)


def shrub(x,y,z,radius):
    # Faceted foliage, not a smooth sphere.
    for i in range(3):
        xx=x+RNG.uniform(-.14,.14)
        yy=y+RNG.uniform(-.12,.12)
        r=radius*RNG.uniform(.7,1.1)
        geo.frustum(xx,yy,z,r*.6,r,r*.45,RNG.choice(leaves),7)
        geo.frustum(xx,yy,z+r*.45,r,.05,r*.85,RNG.choice(leaves),7)


def build():
    # A broad, irregular-cut stone platform provides a grounded silhouette.
    geo.group="Terrace and dressed foundations"
    geo.box((0,0,0.11),(8.7,7.5,.22),stone_mortar)
    geo.box((0,0,.25),(8.94,7.7,.12),foundation)
    for row in range(16):
        y=-3.64+row*.465
        for col in range(17):
            x=-4.12+col*.51+(row%2)*.12
            if x>4.25:
                continue
            geo.box((x,y,.323),(.478,.428,RNG.uniform(.027,.049)),RNG.choice(pavers))
    # Rear towers and the rising central keep establish the silhouette.
    tower("Northwest watchtower",-3.25,2.55,5.2,.78,1.75)
    tower("Northeast watchtower",3.25,2.55,5.2,.78,1.75)
    geo.group="Royal keep masonry"
    masonry_box((0,.9,2.87),(4.7,3.7,5.08))
    for z in (.66,2.08,3.74,5.4):
        geo.box((0,.9,z),(4.84,3.84,.13),cloth if z==5.4 else stone_trim)
    for x in (-2.31,2.31):
        for y in (-.96,2.76):
            geo.box((x,y,2.81),(.28,.28,4.96),stone_trim)
    for x in (-1.55,-.53,.53,1.55):
        window((x,-.97),0,2.48,.4,.95,lit=x>.1)
        window((x,-.97),0,4.08,.46,.95)
    for y in (-.24,.98,2.18):
        window((2.37,y),math.pi/2,2.48,.45,.97,lit=True)
        window((2.37,y),math.pi/2,4.08,.45,.97)
    geo.group="Great terracotta roof"
    hip_roof(0,.9,5.48,2.62,2.14,2.0,18)
    # Paired dormers break up the roof planes.
    for x in (-1.3,1.3):
        geo.group="Roof dormer " + str(x)
        masonry_box((x,-.65,6.03),(.58,.44,.63),False)
        window((x,-.889),0,5.83,.28,.45,lit=True)
        hip_roof(x,-.65,6.39,.41,.36,.54,6)
    # Central royal lantern, with a steep roof and the largest banner.
    geo.group="Crown lantern"
    geo.frustum(0,1.02,6.9,.52,.52,1.36,stone_trim,8,math.pi/8)
    for a in (-math.pi/2,0):
        window((.49*math.cos(a),1.02+.49*math.sin(a)),a+math.pi/2,7.41,.26,.62,lit=True)
    for row in range(7):
        lo,hi=row/7,(row+1)/7
        geo.frustum(0,1.02,8.2+lo*1.0,.68*(1-lo)+.04,.68*(1-hi)+.04,1/7,RNG.choice(roofs),8,math.pi/8)
    flag(0,1.02,9.24,1.12)
    # Lower wings connect the keep to the outer towers.
    for x in (-2.7,2.7):
        geo.group="Side gallery " + str(x)
        masonry_box((x,.75,1.58),(1.05,4.3,2.5))
        hip_roof(x,.75,2.9,.74,2.37,1.04,9)
        if x>0:
            for y in (-.75,.38,1.48):
                window((3.24,y),math.pi/2,1.23,.31,.86)
    # Front gate curtain: short stretches leave the doorway visually dominant.
    for x in (-2.1,2.1):
        geo.group="Front curtain " + str(x)
        masonry_box((x,-2.69,1.54),(1.62,.6,2.4))
        geo.box((x,-2.69,2.8),(1.78,.77,.17),stone_light)
        for i in range(4):
            draw_block=geo.chipped_box if (i==0 and x<0) or (i==2 and x>0) else geo.box
            draw_block((x-.67+i*.445,-2.69,3.02),(.26,.65,.34),stone_trim)
        banner((x,-3.015),0,1.06,.51,1.13)
    geo.group="Gatehouse"
    masonry_box((0,-2.56,1.96),(2.4,1.7,3.26))
    geo.box((0,-2.56,3.66),(2.68,1.93,.2),cloth)
    geo.box((0,-2.56,3.81),(2.82,2.04,.12),stone_light)
    for i,x in enumerate((-1.22,-.73,-.24,.25,.74,1.23)):
        for y in (-3.36,-1.76):
            draw_block=geo.chipped_box if y==-3.36 and i in (0,3,5) else geo.box
            draw_block((x,y,4.02),(.31,.36,.35),stone_trim)
    for y in (-2.88,-2.36):
        for x in (-1.22,1.22):
            geo.box((x,y,4.02),(.35,.31,.35),stone_trim)
    arch((0,-3.43),0,.42,1.32,2.58,door_dark,stone_trim,.22)
    # Oak planks, straps and the grille in the upper arch.
    for i in range(8):
        x=-.575+i*.164
        top=2.34+math.sqrt(max(0,.59**2-x*x))
        geo.box((x,-3.469,(top+.49)/2),(.153,.035,top-.49),woods[i%len(woods)])
    for z in (.85,1.67,2.2):
        geo.box((0,-3.5,z),(1.23,.025,.072),iron)
        for x in (-.51,-.24,.24,.51):
            geo.frustum(x,-3.52,z,.025,.025,.015,gold,5)
    for i in range(7):
        x=-.53+i*.176
        top=2.34+math.sqrt(max(0,.59**2-x*x))
        geo.rod((x,-3.515,2.22),(x,-3.515,top),.018,iron)
    geo.rod((-.61,-3.515,2.42),(.61,-3.515,2.42),.023,iron)
    # Crown plaque above the gate.
    geo.box((0,-3.44,3.24),(.8,.12,.28),stone_light)
    banner((0,-3.54),0,3.1,.5,.29)
    # Broad stairway with readable contrasting risers and paving lip.
    geo.group="Gate stairs"
    for i in range(4):
        y=-4.65+i*.31
        h=.09+i*.083
        geo.box((0,y,h/2),(2.18-i*.08,.34,h),stone_trim if i%2 else stone_light)
    for x in (-1.22,1.22):
        geo.box((x,-3.87,.32),(.25,1.06,.6),foundation)
        geo.box((x,-3.87,.64),(.32,1.12,.1),stone_light)
    # Two front turrets frame the entrance at a lower tier.
    tower("Southwest gate tower",-3.25,-2.64,3.77,.89,1.68,False)
    tower("Southeast gate tower",3.25,-2.64,3.77,.89,1.68,False)
    geo.group="Gatehouse braziers"
    for x in (-.96,.96):
        geo.rod((x,-3.51,1.82),(x,-3.8,2.12),.036,iron)
        geo.frustum(x,-3.8,2.08,.07,.15,.18,iron,6)
        geo.frustum(x,-3.8,2.26,.105,.024,.32,flame,5)
        geo.frustum(x-.025,-3.82,2.27,.058,.01,.21,flame_core,5)
    geo.group="Heraldry and courtyard details"
    banner((2.392,.89),math.pi/2,3.03,.66,1.43)
    # Small stacked barrels visible on the right side of the courtyard.
    for x,y in ((3.55,.15),(3.87,.35)):
        geo.frustum(x,y,.36,.18,.22,.23,woods[1],10)
        geo.frustum(x,y,.59,.22,.18,.23,woods[0],10)
        for z in (.43,.71):
            geo.frustum(x,y,z,.211,.211,.035,iron,10)
    geo.group="Terrace shrubs and scattered stones"
    for x,y,r in ((-3.87,-3.45,.32),(3.93,-3.34,.31),(4.11,-1.45,.24),
                  (4.07,1.73,.3),(-4.04,.16,.29),(-3.9,3.23,.35),(3.86,3.35,.31)):
        shrub(x,y,.36,r)
    for i in range(23):
        x=RNG.uniform(-4.5,4.5)
        y=RNG.choice((-1,1))*RNG.uniform(3.79,3.97)
        if y<0 and abs(x)<1.6:
            continue
        geo.frustum(x,y,.02,RNG.uniform(.07,.17),.055,.11,RNG.choice(pavers),5)


def weather_castle():
    """Architectural wear placed at exposed edges, damp footings and impact sites."""
    rng=random.Random(90183)

    def flat_patch(center,angle,z,width,height,mat):
        shape=[]
        for i in range(9):
            a=i*TAU/9
            amount=rng.uniform(.64,1)
            shape.append(point_on_face(math.cos(a)*width*.5*amount,-.074,
                                        z+math.sin(a)*height*.5*amount,center,angle))
        geo.poly(shape,mat)

    def flat_crack(center,angle,points):
        for a,b in zip(points,points[1:]):
            geo.rod(point_on_face(a[0],-.078,a[1],center,angle),
                    point_on_face(b[0],-.078,b[1],center,angle),.009,crack_stone,4)

    def tower_point(x,y,radius,angle,u,z,offset=.025):
        a=angle+u/radius
        face_mid=(math.floor(a/(TAU/12))+.5)*TAU/12
        rr=radius*math.cos(math.pi/12)/math.cos(a-face_mid)+offset
        return (x+rr*math.cos(a),y+rr*math.sin(a),z)

    def tower_impact(x,y,radius,angle,z,size):
        geo.group="Battle scars · fractured tower masonry"
        directions=[i*TAU/11 for i in range(11)]
        ragged=[rng.uniform(.68,1.2) for _ in directions]
        inner=[tower_point(x,y,radius,angle,math.cos(a)*size*.52*rr,
                           z+math.sin(a)*size*.49*rr,.029)
               for a,rr in zip(directions,ragged)]
        geo.poly(inner,impact_stone)
        for i in range(11):
            j=(i+1)%11
            a,b=directions[i],directions[j]
            outer_a=tower_point(x,y,radius,angle,math.cos(a)*size*ragged[i],z+math.sin(a)*size*ragged[i],.027)
            outer_b=tower_point(x,y,radius,angle,math.cos(b)*size*ragged[j],z+math.sin(b)*size*ragged[j],.027)
            geo.poly([inner[i],inner[j],outer_b,outer_a],
                     exposed_stone if i in (2,3,4) else old_stone)
        for direction in (-2.3,-.8,.4,1.8):
            path=[(math.cos(direction)*size*.78,z+math.sin(direction)*size*.78)]
            for distance in (1.2,1.7,2.2):
                path.append((math.cos(direction)*size*distance+rng.uniform(-.07,.07),
                             z+math.sin(direction)*size*distance+rng.uniform(-.04,.04)))
            for a,b in zip(path,path[1:]):
                geo.rod(tower_point(x,y,radius,angle,*a,.032),
                        tower_point(x,y,radius,angle,*b,.032),.0075,crack_stone,4)

    # A few substantial impact scars, rather than an even distribution of dots.
    tower_impact(3.25,-2.64,.89,-.48,2.03,.23)
    tower_impact(3.25,-2.64,.89,-1.35,1.37,.105)
    tower_impact(-3.25,-2.64,.89,-1.30,1.95,.19)
    tower_impact(3.25,2.55,.78,.08,3.21,.21)

    geo.group="Weathering · tower water runs and moss"
    for x,y,radius,height in ((-3.25,-2.64,.89,3.77),(3.25,-2.64,.89,3.77),(3.25,2.55,.78,5.2)):
        for angle in (-1.42,-.55,.06):
            for i in range(15):
                u=rng.uniform(-.28,.28)
                z=rng.uniform(.42,1.00)
                width=rng.uniform(.05,.16)
                hh=rng.uniform(.045,.16)
                geo.poly([tower_point(x,y,radius,angle,u-width/2,z),
                          tower_point(x,y,radius,angle,u+width/2,z+.01),
                          tower_point(x,y,radius,angle,u+width*.35,z+hh),
                          tower_point(x,y,radius,angle,u-width*.25,z+hh*.74)],rng.choice(leaves+[lichen,old_stone]))
            # Narrow staining beneath projecting stone bands follows gravity.
            for i in range(4):
                u=rng.uniform(-.38,.38)
                top=height-1.12
                length=rng.uniform(.2,.7)
                geo.poly([tower_point(x,y,radius,angle,u-.018,top),
                          tower_point(x,y,radius,angle,u+.043,top),
                          tower_point(x,y,radius,angle,u+.024,top-length),
                          tower_point(x,y,radius,angle,u-.012,top-length*.73)],old_stone)

    geo.group="Weathering · gatehouse smoke and chipped ashlar"
    for x in (-.97,.97):
        for i in range(26):
            t=rng.random()
            center=(x+rng.uniform(-.16,.16)*(1-t*.5),-3.431)
            flat_patch(center,0,2.28+t*.96,rng.uniform(.025,.13),rng.uniform(.04,.14),
                       soot if t<.43 and rng.random()<.55 else soot_edge)
    for x,z in ((-.81,1.11),(.97,.81),(-1.07,3.02),(.68,3.27)):
        flat_patch((x,-3.433),0,z,.17,.13,old_stone)
        flat_patch((x-.02,-3.446),0,z+.045,.12,.034,exposed_stone)
    flat_crack((-.78,-3.448),0,[(-.18,3.47),(-.14,3.27),(-.02,3.20),(-.07,3.04),(.04,2.95)])
    flat_crack((.91,-3.448),0,[(.04,1.84),(-.06,1.62),(.02,1.5),(-.04,1.22)])

    geo.group="Weathering · patched keep and creeping gallery ivy"
    for y,z in ((-.47,1.1),(.25,.69),(.91,1.01),(1.41,.84),(1.95,.51)):
        for i in range(9):
            flat_patch((3.255,y+rng.uniform(-.22,.22)),math.pi/2,z+rng.uniform(-.32,.3),
                       rng.uniform(.06,.2),rng.uniform(.07,.17),rng.choice(leaves+[lichen]))
    # A short climbing tendril grows from the damp gallery corner.
    for i in range(19):
        z=.5+i*.073
        y=1.64+math.sin(i*.47)*.10
        flat_patch((3.255,y),math.pi/2,z,.10,.13,rng.choice(leaves))
    for y,z in ((-.6,3.79),(1.73,4.86),(2.06,3.66),(.22,2.26)):
        flat_patch((2.385,y),math.pi/2,z,.22,.18,old_stone)
    flat_crack((2.391,1.7),math.pi/2,[(-.2,3.62),(-.06,3.47),(-.08,3.34),(.09,3.23),(.08,3.05)])
    flat_crack((-1.94,-.976),0,[(.05,3.73),(-.05,3.60),(.02,3.39),(-.11,3.25)])

    geo.group="Weathering · courtyard grass and worn threshold"
    for x,y in ((-1.77,-3.43),(1.82,-3.46),(3.98,-1.8),(3.85,.92),(-3.95,-.61)):
        for i in range(7):
            xx,yy=x+rng.uniform(-.14,.14),y+rng.uniform(-.14,.14)
            geo.rod((xx,yy,.35),(xx+rng.uniform(-.035,.035),yy,.35+rng.uniform(.07,.2)),
                    .015,rng.choice(leaves),3)
    for i in range(13):
        x=rng.uniform(-.8,.8)
        y=rng.uniform(-4.4,-3.8)
        step=round((y+4.65)/.31)
        z=.09+step*.083+.006
        geo.poly([(x,y,z),(x+.12,y+.015,z),(x+.095,y+.045,z),(x-.04,y+.025,z)],old_stone)


def setup_scene(resolution,samples):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=samples
    scene.cycles.use_denoising=True
    scene.cycles.max_bounces=6
    scene.render.threads_mode="FIXED"
    scene.render.threads=10
    scene.render.resolution_x=resolution
    scene.render.resolution_y=resolution
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.image_settings.color_depth="8"
    scene.render.filepath=str(OUT/"palace-render.png")
    scene.render.image_settings.compression=30
    scene.view_settings.view_transform="Standard"
    scene.view_settings.look="None"
    scene.view_settings.exposure=0
    scene.world.color=(.24,.29,.34)
    scene.world.use_nodes=True
    world=scene.world.node_tree.nodes.get("Background")
    world.inputs["Color"].default_value=(.52,.62,.76,1)
    world.inputs["Strength"].default_value=.40
    light_data=bpy.data.lights.new("Warm afternoon key","AREA")
    light_data.energy=2600
    light_data.shape="DISK"
    light_data.size=6
    light_data.color=(1.0,.93,.82)
    light=bpy.data.objects.new("Warm afternoon key",light_data)
    scene.collection.objects.link(light)
    light.location=(-7,-10,16)
    light.rotation_euler=(Vector((0,0,2))-light.location).to_track_quat("-Z","Y").to_euler()
    camera_data=bpy.data.cameras.new("2 to 1 isometric camera")
    camera=bpy.data.objects.new("2 to 1 isometric camera",camera_data)
    scene.collection.objects.link(camera)
    # A 30-degree elevation makes world X/Y ground edges have a 1:2 slope.
    target=Vector((0,0,4.4))
    camera.location=target+Vector((18,-18,math.sqrt(18**2+18**2)*math.tan(math.radians(30))))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera_data.type="ORTHO"
    camera_data.ortho_scale=14.3
    camera_data.lens=50
    scene.camera=camera
    # Center the visible silhouette, leaving a measured margin on every side.
    bpy.context.view_layer.update()
    points=[world_to_camera_view(scene,camera,obj.matrix_world@Vector(corner))
            for obj in scene.objects if obj.type=="MESH" for corner in obj.bound_box]
    min_x,max_x=min(p.x for p in points),max(p.x for p in points)
    min_y,max_y=min(p.y for p in points),max(p.y for p in points)
    right=camera.rotation_euler.to_matrix()@Vector((1,0,0))
    up=camera.rotation_euler.to_matrix()@Vector((0,1,0))
    camera.location += right*((min_x+max_x-1)*.5*camera_data.ortho_scale)
    camera.location += up*((min_y+max_y-1)*.5*camera_data.ortho_scale)
    camera_data.ortho_scale *= max(max_x-min_x,max_y-min_y)/.88
    bpy.context.view_layer.update()
    ground=world_to_camera_view(scene,camera,Vector((0,0,0)))
    (OUT/"projection.json").write_text(json.dumps({
        "camera_elevation_degrees":30,"ground_anchor_normalized":[ground.x,1-ground.y],
        "render_resolution":resolution,"design":"Sovereign Royal Palace",
    },indent=2)+"\n")
    scene.render.fps=12


def init_materials(theme_path=None):
    """Shared castle materials for the kingdom building collection."""
    global theme, stones, stone_mortar, stone_trim, stone_light, foundation, roofs, roof_dark, roof_ridge, glass, amber, woods, door_dark, iron, gold, gold_light, flag_gold, cloth, pavers, leaves, wear, old_stone, lichen, exposed_stone, impact_stone, crack_stone, soot, soot_edge, roof_chip, flame, flame_core
    theme=json.loads((theme_path or OUT/"color-theme.json").read_text())["materials"]
    stones=[weathered_material("Weathered grey masonry %02d"%i,c) for i,c in enumerate(theme["stone"])]
    stone_mortar=material("Recessed masonry joints",theme["mortar"])
    stone_trim=weathered_material("Dressed grey stone",theme["trim"],24)
    stone_light=weathered_material("Pale carved edges",theme["carved_edges"],24)
    foundation=material("Foundation stone",theme["foundation"])
    roofs=[weathered_material("Aged terracotta tile %02d"%i,c,27) for i,c in enumerate(theme["roof"])]
    roof_dark=material("Roof eave shadows",theme["eaves"])
    roof_ridge=material("Terracotta ridge caps",theme["ridge"])
    glass=material("Dark window glass",theme["glass"])
    amber=material("Warm window glass",theme["window_light"],.12)
    woods=[material("Weathered oak plank %02d"%i,c) for i,c in enumerate(theme["wood"])]
    door_dark=material("Deep portal shadow",theme["portal_shadow"])
    iron=material("Forged dark iron",theme["iron"])
    gold=material("Aged brass fittings",theme["metal"])
    gold_light=material("Ivory heraldic embroidery",theme["heraldry_ivory"])
    flag_gold=material("Ivory silk standards",theme["flag_cloth"])
    cloth=material("Crimson royal cloth",theme["banner_cloth"])
    pavers=[material("Worn courtyard paver %02d"%i,c) for i,c in enumerate(theme["pavers"])]
    leaves=[material("Garden and wall foliage %02d"%i,c) for i,c in enumerate(theme["leaves"])]
    wear={key:material("Weathering · "+key,color) for key,color in theme["weathering"].items()}
    old_stone,lichen,exposed_stone=wear["old_stone"],wear["lichen"],wear["exposed_stone"]
    impact_stone,crack_stone=wear["impact"],wear["crack"]
    soot,soot_edge,roof_chip=wear["soot"],wear["soot_edge"],wear["roof_chip"]
    flame=material("Amber flame","ed942f",1)
    flame_core=material("Flame heart","ffe29b",1.2)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--resolution",type=int,default=1920)
    parser.add_argument("--samples",type=int,default=128)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    init_materials()
    geo=Geometry()
    build()
    weather_castle()
    geo.finish()
    setup_scene(args.resolution,args.samples)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"sovereign-palace.blend"))
    bpy.ops.render.render(write_still=True)
    print("Sovereign palace rendered:",OUT)
