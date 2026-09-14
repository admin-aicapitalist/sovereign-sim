"""Bake the fixture's static ground; no gameplay or trees are baked into it."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[1]
world=json.loads((ROOT/'data/world.json').read_text())
n=world['size']; w=n*64; h=n*32+32
def iso(x,y): return (round((x-y)*32+w/2),round((x+y)*16))
def mask_for(kinds):
    mask=Image.new('L',(w,h)); draw=ImageDraw.Draw(mask)
    for i,t in enumerate(world['tiles']):
        if t['kind'] in kinds:
            x,y=i%n,i//n
            draw.polygon([iso(x,y),iso(x+1,y),iso(x+1,y+1),iso(x,y+1)],fill=255)
    return mask
def material(name):
    source=Image.open(ROOT/'assets'/f'terrain-{name}.png').convert('RGB').resize((256,128),Image.Resampling.LANCZOS)
    out=Image.new('RGB',(w,h))
    for y in range(0,h,128):
        for x in range(0,w,256): out.paste(source,(x,y))
    return out
ground=material('grass')
road=mask_for({'path'}).filter(ImageFilter.GaussianBlur(3))
ground.paste(material('road'),(0,0),road)
water=mask_for({'water','bridge'}).filter(ImageFilter.GaussianBlur(2))
shore=water.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(4))
ground.paste(material('dirt'),(0,0),shore)
ground.paste(material('water'),(0,0),water)
court=Image.new('L',(w,h)); d=ImageDraw.Draw(court)
palace=world['buildings'][0]; x,y=iso(palace['x']+1.5,palace['y']+1.5)
d.ellipse((x-123,y-62,x+123,y+62),fill=255)
ground.paste(material('paving'),(0,0),court.filter(ImageFilter.GaussianBlur(4)))
deck=Image.open(ROOT/'assets/bridge-deck.png').convert('RGBA').resize((64,32),Image.Resampling.LANCZOS)
for i,t in enumerate(world['tiles']):
    if t['kind']=='bridge':
        x,y=iso(i%n,i//n);ground.paste(deck,(x-32,y),deck)
assets=json.loads((ROOT/'data/assets.json').read_text())
for i,p in enumerate(world['decor']):
    key=f'rock{i%4}' if p['type']=='rock' else f'flowers{i%2}'
    a=assets[key]; scale=.65
    image=Image.open(ROOT/'assets'/f'{key}.png').convert('RGBA').resize((round(a['w']*scale),round(a['h']*scale)),Image.Resampling.LANCZOS)
    x,y=iso(p['x'],p['y']);ground.paste(image,(round(x-a['anchor'][0]*scale),round(y-a['anchor'][1]*scale)),image)
ground=ground.convert('RGBA'); ground.putalpha(mask_for({'grass','path','water','bridge'}))
ground.save(ROOT/'assets/ground.png',optimize=True)
print(f'Baked {w}×{h} static ground texture.')
