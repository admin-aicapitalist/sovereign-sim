"""Pack shared-origin scenery loops. Run with .venv/bin/python and the render directory."""
import json
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[2]
source=Path(sys.argv[1]); catalog={}; previews={}; counts={}
for kind in ('courtesan_red','courtesan_black','drinker','brawl'):
    meta=json.loads((source/f'{kind}.json').read_text()); ratio=meta['render_size']/meta['logical_size']
    anchor=[x*meta['render_size'] for x in meta['anchor']]
    shadow=Image.new('RGBA',(meta['render_size'],)*2); d=ImageDraw.Draw(shadow)
    radius=21 if kind=='brawl' else 9
    d.ellipse((anchor[0]-radius*ratio,anchor[1]-4*ratio,anchor[0]+radius*ratio,anchor[1]+4*ratio),fill=(15,12,20,65))
    shadow=shadow.filter(ImageFilter.GaussianBlur(ratio*.75))
    images=[]
    for i in range(meta['frames']):
        im=Image.open(source/f'{kind}-{i:02d}.png').convert('RGBA')
        bounds=im.getbbox(); assert bounds and min(bounds[:2])>1 and max(bounds[2:])<im.width-1,(kind,i,'clipped geometry')
        images.append(Image.alpha_composite(shadow,im))
    bounds=[im.getbbox() for im in images]
    crop=(min(b[0] for b in bounds)-3,min(b[1] for b in bounds)-3,max(b[2] for b in bounds)+3,max(b[3] for b in bounds)+3)
    images=[im.crop(crop) for im in images]; w,h=images[0].size
    atlas=Image.new('RGBA',(w*4,h*4)); frames=[]
    for i,im in enumerate(images):
        x,y=i%4*w,i//4*h; atlas.paste(im,(x,y));frames.append([x,y,w,h])
    out=ROOT/f'godot/assets/leisure_{kind}.png';atlas.save(out,optimize=True)
    catalog[kind]={'src':f'res://assets/leisure_{kind}.png','size':[w/ratio,h/ratio],
        'anchor':[(anchor[0]-crop[0])/ratio,(anchor[1]-crop[1])/ratio], 'frames':frames,'fps':meta['fps']}
    counts[kind]={'frames':len(frames),'texture_size':list(atlas.size),'png_bytes':out.stat().st_size,'clipped':False}
    previews[kind]=images
(ROOT/'godot/data/leisure_cast.json').write_text(json.dumps(catalog,indent=2)+'\n')
boards=[]
for frame in range(16):
    board=Image.new('RGB',(1100,340),'#211922');draw=ImageDraw.Draw(board)
    for i,(kind,images) in enumerate(previews.items()):
        im=images[frame].copy(); im.thumbnail((255,285),Image.Resampling.LANCZOS)
        board.paste(im,(i*275+(275-im.width)//2,290-im.height),im)
        draw.text((i*275+25,310),kind.replace('_',' ').title(),fill='#efd3b9')
    boards.append(board)
boards[0].save(ROOT/'godot/reports/leisure-cast.png')
boards[0].save(ROOT/'godot/reports/leisure-cast.webp',save_all=True,append_images=boards[1:],duration=250,loop=0,quality=90)
(ROOT/'godot/reports/leisure-art.json').write_text(json.dumps(counts,indent=2)+'\n')
print(json.dumps(counts))
