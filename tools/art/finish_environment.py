"""Export scenery sprites and original seamless, high-resolution ground materials."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFilter, ImageOps
from finish_palace import font, version_runtime_scripts

ROOT=Path(__file__).resolve().parents[2]
KEYS=([f'pine{i}' for i in range(6)]+[f'oak{i}' for i in range(6)]+[f'rock{i}' for i in range(4)]+
      [f'shrub{i}' for i in range(3)]+[f'flowers{i}' for i in range(2)]+[f'grass{i}' for i in range(2)]+
      [f'reeds{i}' for i in range(2)]+['stump','log','bridge-rail'])
W,H=1536,768


def noise(width,height,grid,seed):
    r=random.Random(seed)
    nx,ny=max(3,width//grid),max(3,height//grid)
    small=Image.frombytes('L',(nx,ny),r.randbytes(nx*ny))
    repeat=Image.new('L',(nx*3,ny*3))
    for y in range(3):
        for x in range(3):repeat.paste(small,(x*nx,y*ny))
    # Filter with wrapped neighbours so texture boundaries have no dark seams.
    return repeat.resize((width*3,height*3),Image.Resampling.BICUBIC).crop((width,height,width*2,height*2))


def base_texture(low,high,seed):
    grain=Image.blend(noise(W,H,185,seed),noise(W,H,31,seed+1),.4)
    grain=Image.blend(grain,noise(W,H,3,seed+2),.21)
    return ImageOps.colorize(grain,low,high).convert('RGBA')


def wrapped_line(draw,points,fill,width=1):
    xs=[p[0] for p in points];ys=[p[1] for p in points]
    xoffset=[0]+([W] if min(xs)<0 else [])+([-W] if max(xs)>=W else [])
    yoffset=[0]+([H] if min(ys)<0 else [])+([-H] if max(ys)>=H else [])
    for dx in xoffset:
        for dy in yoffset:draw.line([(x+dx,y+dy) for x,y in points],fill=fill,width=width)


def ground_material(kind):
    r=random.Random(61001+sum(ord(c) for c in kind))
    colors={'grass':('#65763f','#99a367'),'dirt':('#625a40','#a39369'),
            'road':('#96845e','#c0ae7c'),'paving':('#797c69','#aaac94'),
            'water':('#326776','#6c9b9d')}
    im=base_texture(*colors[kind],r.randrange(99999))
    d=ImageDraw.Draw(im)
    if kind=='grass':
        palette=['#74834a','#899653','#a3ab67','#6c7a41','#94a15d','#b0b47a']
        for i in range(16000):
            x,y=r.randrange(W),r.randrange(H)
            dx,dy=r.uniform(-3,3),r.uniform(2,8)
            wrapped_line(d,[(x,y),(x+dx,y-dy)],r.choice(palette),r.choice([1,1,2]))
        for _ in range(900):
            x,y=r.randrange(W),r.randrange(H)
            wrapped_line(d,[(x,y),(x+2,y+.3)],'#aea976',2)
    elif kind in ('dirt','road'):
        palette=['#b0a382','#827959','#9b9471','#c5b99a','#7c7759']
        for i in range(9000):
            x,y=r.randrange(W),r.randrange(H);size=r.uniform(1,5 if kind=='road' else 3)
            wrapped_line(d,[(x,y),(x+size,y+.45*size)],r.choice(palette),max(1,round(size*.55)))
        if kind=='dirt':
            for _ in range(1600):
                x,y=r.randrange(W),r.randrange(H);a=r.uniform(0,math.tau)
                wrapped_line(d,[(x,y),(x+math.cos(a)*6,y+math.sin(a)*3)],r.choice(['#8b783e','#9c8649','#716e40']),2)
    elif kind=='paving':
        palette=['#b0ae98','#bab5a0','#a6ab97','#c0b9a3','#abb19e','#a1a591']
        for row in range(-1,33):
            for col in range(-1,33):
                x=col*48+(row%2)*24;y=row*24
                w,h=45+r.uniform(-4,1),20+r.uniform(-2,1)
                pts=[(x+5,y+1),(x+w-5,y),(x+w,y+4),(x+w-1,y+h-3),(x+w-6,y+h),(x+4,y+h-1),(x,y+h-5),(x+1,y+5)]
                d.polygon([(a+1,b+2) for a,b in pts],fill='#656e60')
                fill=r.choice(palette);d.polygon(pts,fill=fill)
                d.line(pts[:3],fill='#d0c8ae',width=1)
                for _ in range(5):
                    xx,yy=x+r.uniform(5,w-5),y+r.uniform(4,h-3)
                    d.line([(xx,yy),(xx+r.uniform(1,4),yy)],fill='#929781',width=1)
        # Project wrapped paving into the same 2:1 ground plane as the buildings.
        square=im.crop((0,0,H,H));repeat=Image.new('RGBA',(H*5,H*5))
        for yy in range(5):
            for xx in range(5):repeat.paste(square,(xx*H,yy*H))
        im=repeat.transform((W,H),Image.Transform.AFFINE,(H/W,1,H*2,-H/W,1,H*2),Image.Resampling.BICUBIC)
    elif kind=='water':
        for _ in range(4200):
            x,y=r.randrange(W),r.randrange(H);length=r.uniform(3,32)
            pts=[(x+t*length/5,y+math.sin(t*.8)*1.4) for t in range(6)]
            wrapped_line(d,pts,r.choice(['#639b9f','#5b939b','#447e8b','#79a8a6','#3d7788']),1)
    return im


def water_glints():
    r=random.Random(4129);im=Image.new('RGBA',(W,H));d=ImageDraw.Draw(im)
    for i in range(1600):
        x,y=r.randrange(W),r.randrange(H);length=r.uniform(4,39)
        pts=[(x+t*length/5,y+math.sin(t*.9)*1.2) for t in range(6)]
        wrapped_line(d,pts,(193,218,205,r.randint(24,105)),r.choice([1,1,2]))
    return im


def bridge_deck():
    size=768;r=random.Random(3988)
    im=Image.new('RGBA',(size,size),'#5d513b');d=ImageDraw.Draw(im)
    colors=['#97835b','#a18b60','#a58d61','#948058','#b0996c','#9d875e']
    for col in range(6):
        x=col*128
        d.rectangle((x+3,0,x+125,size),fill=colors[col])
        d.line((x+4,0,x+4,size),fill='#c1aa7c',width=2)
        for i in range(65):
            xx=x+r.uniform(8,120);y=r.uniform(0,size);length=r.uniform(30,190)
            d.line([(xx,y),(xx+r.uniform(-2,2),y+length)],fill=r.choice(['#8c7751','#b09b71','#796747']),width=1)
        for y in (19,size-19):
            for xx in (x+23,x+106):
                d.ellipse((xx-4,y-4,xx+4,y+4),fill='#494f43')
                d.line((xx-2,y-2,xx+1,y-2),fill='#a6a891',width=1)
    return im.transform((384,192),Image.Transform.AFFINE,(size/384,size/192,-size/2,-size/384,size/192,size/2),Image.Resampling.BICUBIC)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--source',type=Path,default=ROOT/'assets/art/environment/source')
    parser.add_argument('--output',type=Path,default=ROOT/'assets/art/environment')
    parser.add_argument('--no-integrate',action='store_true')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    assets,info,previews={},{},[]
    def save(key,im,meta):
        path=args.output/f'{key}.png';im.save(path,optimize=True)
        digest=hashlib.sha256(path.read_bytes()).hexdigest()[:12]
        assets[key]={**meta,'src':f'{key}.png?v={digest}','sourceSize':list(im.size),'pixelArt':False}
        info[key]=dict(assets[key])
        previews.append((key,im))
    for key in KEYS:
        meta=json.loads((args.source/f'{key}.json').read_text())
        source=Image.open(args.source/f'{key}-render.png').convert('RGBA')
        bb=source.getbbox();assert bb and all(0<v<source.width for v in bb),f'{key}: clipped {bb}'
        density=source.width/meta['logical_size'][0]
        anchor=[v*source.width for v in meta['ground_anchor_normalized']]
        shadow=Image.new('RGBA',source.size);d=ImageDraw.Draw(shadow)
        radius=meta['shadow_radius']*density
        if key!='bridge-rail':
            d.ellipse((anchor[0]-radius,anchor[1]-radius*.37,anchor[0]+radius,anchor[1]+radius*.37),fill=(33,43,27,58))
            shadow=shadow.filter(ImageFilter.GaussianBlur(density*1.8))
        combined=Image.alpha_composite(shadow,source);box=combined.getbbox();step=round(density);pad=step*2
        crop=(max(0,math.floor((box[0]-pad)/step)*step),max(0,math.floor((box[1]-pad)/step)*step),
              min(source.width,math.ceil((box[2]+pad)/step)*step),min(source.height,math.ceil((box[3]+pad)/step)*step))
        sprite=combined.crop(crop)
        bounds=source.crop(crop).getchannel('A').point(lambda a:255 if a>=96 else 0).getbbox()
        runtime={'w':sprite.width/density,'h':sprite.height/density,
                 'anchor':[(anchor[0]-crop[0])/density,(anchor[1]-crop[1])/density],
                 'bounds':[v/density for v in bounds],'category':'tree' if key.startswith(('oak','pine')) else 'scenery'}
        save(key,sprite,runtime)
        info[key]={**assets[key],'scene':f'source/{key}.blend','crop':crop,'master_render_size':list(source.size)}
        print(f'{key}: {source.width}² → {sprite.width}×{sprite.height}')
    for kind in ['grass','dirt','road','paving','water','water-glints']:
        im=water_glints() if kind=='water-glints' else ground_material(kind)
        save('terrain-'+kind,im,{'w':256,'h':128,'anchor':[0,0],'bounds':[0,0,256,128],'category':'terrain'})
    save('bridge-deck',bridge_deck(),{'w':64,'h':32,'anchor':[32,0],'bounds':[0,0,64,32],'category':'terrain'})
    manifest='// Generated by tools/art/finish_environment.py.\n(function () {\n'
    manifest+='  const assets = '+json.dumps(assets,separators=(',',':'))+';\n'
    manifest+='  G.environmentAssets = assets;\n  G.spriteAssets = G.spriteAssets || {};\n'
    manifest+='  for (const [key,asset] of Object.entries(assets)) {\n'
    manifest+='    asset.src = new URL(asset.src, document.currentScript.src).href;\n'
    manifest+='    G.spriteAssets[key] = asset;\n  }\n})();\n'
    (args.output/'environment-sprites.js').write_text(manifest)
    (args.output/'environment.json').write_text(json.dumps(info,indent=2)+'\n')
    cols=6;cw,ch=300,310;rows=math.ceil(len(previews)/cols)
    board=Image.new('RGBA',(cols*cw,rows*ch+110),'#22332b');d=ImageDraw.Draw(board)
    d.text((board.width//2,40),'S O V E R E I G N   /   T H E   L I V I N G   L A N D',font=font(26,True),fill='#e8dbc0',anchor='mm')
    d.text((board.width//2,78),'WOODLAND / MEADOWS / ROADS / RIVERS / WEATHERED SCENERY',font=font(13),fill='#aebba0',anchor='mm')
    for i,(name,im) in enumerate(previews):
        x,y=i%cols*cw,i//cols*ch+105
        d.rounded_rectangle((x+8,y,x+cw-8,y+ch-12),radius=4,fill='#2d4338',outline='#697253')
        image=im.copy();image.thumbnail((cw-34,ch-62),Image.Resampling.LANCZOS)
        board.alpha_composite(image,(x+(cw-image.width)//2,y+15+(ch-70-image.height)//2))
        d.text((x+cw//2,y+ch-35),name.replace('terrain-','').replace('-',' ').title(),font=font(16,True),fill='#e3d7bc',anchor='mm')
    board.convert('RGB').save(args.output/'environment-preview.png')
    if not args.no_integrate:version_runtime_scripts()


if __name__=='__main__':main()
