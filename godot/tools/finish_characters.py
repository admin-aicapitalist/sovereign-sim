"""Pack directional Blender renders into trimmed, grounded Godot atlases.

Run after render_characters.py with the project's Pillow Python. All frames share
the projected world origin; individual crops reduce GPU memory without foot jitter.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT=Path(__file__).resolve().parents[2]
TYPES=['warrior','ranger','wizard','guard','peasant','collector','rat','goblin','skeleton','troll','thief','warlord']


def pack(kind,source,asset_name=None):
    asset_name=asset_name or kind
    meta=json.loads((source/f'{kind}.json').read_text())
    density=meta['render_size']/meta['logical_size']
    origin=[v*meta['render_size'] for v in meta['anchor']]
    shadow=Image.new('RGBA',(meta['render_size'],)*2)
    radius=(15 if kind in ('troll','warlord') else 12 if kind=='rat' else 7.5)*density
    ImageDraw.Draw(shadow).ellipse((origin[0]-radius,origin[1]-radius*.44,
        origin[0]+radius,origin[1]+radius*.44),fill=(19,25,20,75))
    shadow=shadow.filter(ImageFilter.GaussianBlur(density*.85))
    frames=[]; images=[]; clips=[]; animations={}
    for animation,count in meta['animations'].items():
        animations[animation]=[]
        for pose in range(count):
            animations[animation].append(len(frames))
            for direction in range(8):
                path=source/f'{kind}-{animation}-{pose}-{direction}.png'
                im=Image.open(path).convert('RGBA')
                assert im.size==(meta['render_size'],)*2, f'Render dimensions changed: {path}'
                opaque=im.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
                assert opaque, f'Empty render: {path}'
                if min(opaque[:2])<2 or max(opaque[2:])>im.width-2: clips.append(path.name)
                alpha=im.getchannel('A')
                rgb=ImageEnhance.Contrast(im.convert('RGB')).enhance(1.07)
                rgb=ImageEnhance.Color(rgb).enhance(.96)
                rgb=rgb.filter(ImageFilter.UnsharpMask(.55,40,3)); rgb.putalpha(alpha)
                im=Image.alpha_composite(shadow,rgb)
                bounds=im.getbbox(); pad=4
                crop=(max(0,bounds[0]-pad),max(0,bounds[1]-pad),
                      min(im.width,bounds[2]+pad),min(im.height,bounds[3]+pad))
                tile=im.crop(crop); images.append(tile)
                frames.append({'pose':f'{animation}-{pose}','direction':direction,
                    'size':[tile.width/density,tile.height/density],
                    'anchor':[(origin[0]-crop[0])/density,(origin[1]-crop[1])/density],
                    'bounds':[(opaque[i]-crop[i%2])/density for i in range(4)]})
                sockets=meta.get('sockets',{}).get(f'{animation}-{pose}-{direction}',{})
                if sockets:
                    frames[-1]['sockets']={key:[(p[i]-meta['anchor'][i])*meta['logical_size'] for i in range(2)] for key,p in sockets.items()}
    assert not clips, f'Clipped geometry: {clips}'
    # Shelf packing keeps every character in one texture. 4px transparent gutters
    # and per-frame source regions prevent neighboring poses from bleeding.
    width=1536; x=y=row=0
    for index in sorted(range(len(images)),key=lambda i:(-images[i].height,-images[i].width)):
        tile=images[index]; frame=frames[index]
        if x+tile.width>width: x=0; y+=row; row=0
        frame['frame']=[x,y,tile.width,tile.height]
        x+=tile.width; row=max(row,tile.height)
    height=y+row
    assert height<=4096, f'Atlas exceeds conservative WebGL texture limit: {kind}'
    atlas=Image.new('RGBA',(width,height))
    for tile,frame in zip(images,frames): atlas.paste(tile,tuple(frame['frame'][:2]))
    out=ROOT/'assets/art/units/directional'
    out.mkdir(parents=True,exist_ok=True)
    atlas.save(out/f'{asset_name}.png',optimize=True)
    atlas.save(ROOT/f'godot/assets/unit_{asset_name}.png',optimize=True)
    first=frames[0]
    entry={'src':f'res://assets/unit_{asset_name}.png','source':f'assets/art/units/directional/{asset_name}.png',
        'sourceSize':list(atlas.size),'w':first['size'][0],'h':first['size'][1],'anchor':first['anchor'],
        'frames':frames,'animations':animations,'directions':meta['directions'],
        'selection':[(meta['selection'][i]-meta['anchor'][i])*meta['logical_size'] for i in range(2)],
        'selectionRadius':meta['selection_radius'],
        'healthOffset':first['bounds'][1]-first['anchor'][1]-7,
        'density':density,'animation_fps':{'idle':3,'walk':12,'attack':12}}
    return entry,images,{'frames':len(frames),'size':list(atlas.size),
        'png_bytes':(out/f'{asset_name}.png').stat().st_size,'rgba_bytes':width*height*4,'clipped_frames':clips}


def showcase(all_images,entries):
    out=ROOT/'godot/reports'; out.mkdir(exist_ok=True)
    labels={'warrior':'Royal swordsman','ranger':'Woodland ranger','wizard':'Court arcanist',
        'guard':'Palace halberdier','peasant':'Village carpenter','collector':'Treasury collector',
        'rat':'Giant rat','goblin':'Goblin raider','skeleton':'Restless infantry','troll':'Hill troll',
        'thief':'Guild shadow','warlord':'Ember Warlord'}
    font=ImageFont.truetype(str(ROOT/'godot/assets/alegreya.ttf'),23)
    title=ImageFont.truetype(str(ROOT/'godot/assets/cinzel.ttf'),33)
    small=ImageFont.truetype(str(ROOT/'godot/assets/alegreya.ttf'),17)
    order=['warrior','guard','ranger','wizard','peasant','collector','thief','goblin','skeleton','rat','troll','warlord']
    def sheet(frame,heading=False):
        board=Image.new('RGB',(1440,880),'#202925'); d=ImageDraw.Draw(board)
        d.text((40,22),'SOVEREIGN  /  THE PEOPLE OF THE KINGDOM',font=title,fill='#ddc58e')
        d.text((42,70),'Original medieval miniatures  •  Eight directions  •  Idle, march and combat',font=small,fill='#a7b19a')
        d.line((40,108,1400,108),fill='#76663f')
        for i,kind in enumerate(order):
            info=entries[kind]; index=frame if heading else info['animations']['walk'][frame%8]
            tile=all_images[kind][index]; anchor=info['frames'][index]['anchor']; density=info['density']
            # Constant ground scale preserves relative sizes, rather than enlarging rats to troll size.
            scale=3.25/density
            tile=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
            x=i%6*240+120-round(anchor[0]*3.25); y=i//6*365+400-round(anchor[1]*3.25)
            board.paste(tile,(x,y),tile)
            d.text((i%6*240+120,i//6*365+456),labels[kind],font=font,fill='#dfceb0',anchor='mm')
        return board
    sheet(0,True).save(out/'characters-lineup.png')
    sheet(0,True).save(ROOT/'assets/art/units/directional/lineup.png')
    walk=[sheet(i) for i in range(8)]
    walk[0].save(out/'characters-marching.webp',save_all=True,append_images=walk[1:],duration=100,loop=0,quality=90,method=6)
    turns=[sheet(i,True) for i in range(8)]
    turns[0].save(out/'characters-directions.webp',save_all=True,append_images=turns[1:],duration=300,loop=0,quality=90,method=6)


def portraits(source,manifest):
    out=ROOT/'godot/assets/portraits'; out.mkdir(exist_ok=True)
    for kind in TYPES:
        file=source/f'{kind}-portrait.png'
        if not file.exists(): raise FileNotFoundError(f'Render --portraits before finishing: {file}')
        color=(63,67,53) if kind in ('ranger','peasant','rat','goblin','troll') else (50,62,69) if kind in ('wizard','thief','guard') else (70,48,39)
        panel=Image.new('RGBA',(256,256)); pixels=[]
        for y in range(256):
            for x in range(256):
                light=max(0,1-math.hypot((x-95)/190,(y-88)/210))
                pixels.append(tuple(round(v*(.55+light*.55)) for v in color)+(255,))
        panel.putdata(pixels)
        d=ImageDraw.Draw(panel)
        d.ellipse((25,10,231,221),outline=(154,125,72,90),width=1)
        for a in range(0,360,30):
            angle=math.radians(a); x=128+98*math.cos(angle); y=116+98*math.sin(angle)
            d.ellipse((x-1,y-1,x+1,y+1),fill='#887344')
        art=Image.open(file).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
        panel=Image.alpha_composite(panel,art)
        mask=Image.new('L',(256,256)); ImageDraw.Draw(mask).rounded_rectangle((4,4,251,251),radius=24,fill=255)
        panel.putalpha(mask); d=ImageDraw.Draw(panel)
        d.rounded_rectangle((5,5,250,250),radius=23,outline='#342c20',width=5)
        d.rounded_rectangle((7,7,248,248),radius=22,outline='#c3a162',width=2)
        d.rounded_rectangle((11,11,244,244),radius=19,outline='#6e5d3d',width=1)
        for x,y in ((18,18),(237,18),(18,237),(237,237)):
            d.ellipse((x-2,y-2,x+2,y+2),fill='#d6b977')
        panel.save(out/f'{kind}.png',optimize=True)
        manifest['unit_'+kind]['portrait']=f'res://assets/portraits/{kind}.png'


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--source',type=Path,default=Path('/tmp/sovereign-unit-renders'))
    parser.add_argument('--portraits-only',action='store_true')
    parser.add_argument('--only',nargs='+',choices=TYPES,default=TYPES); args=parser.parse_args()
    path=ROOT/'godot/data/assets.json'; manifest=json.loads(path.read_text())
    if args.portraits_only:
        portraits(args.source,manifest)
        path.write_text(json.dumps(manifest,separators=(',',':')))
        (ROOT/'assets/art/units/directional/manifest.json').write_text(json.dumps({k:v for k,v in manifest.items() if k.startswith('unit_')},separators=(',',':')))
        return
    all_images={}; entries={}; report={}
    for kind in args.only:
        entry,images,metrics=pack(kind,args.source)
        if 'portrait' in manifest.get('unit_'+kind,{}): entry['portrait']=manifest['unit_'+kind]['portrait']
        entries[kind]=entry; all_images[kind]=images; report[kind]=metrics
        manifest['unit_'+kind]=entry
        print(kind,metrics,flush=True)
    path.write_text(json.dumps(manifest,separators=(',',':')))
    (ROOT/'assets/art/units/directional/manifest.json').write_text(json.dumps({k:v for k,v in manifest.items() if k.startswith('unit_')},separators=(',',':')))
    (ROOT/'godot/reports/characters-assets.json').write_text(json.dumps(report,indent=2)+'\n')
    if len(entries)==len(TYPES): showcase(all_images,entries)


if __name__=='__main__': main()
