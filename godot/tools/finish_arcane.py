"""Trim original Blender effect renders and author soft turbulent smoke tiles."""
import json, math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'godot/assets/arcane'; SOURCE=ROOT/'assets/art/magic'
meta=json.loads((SOURCE/'projection.json').read_text()); entries={}
for key,info in meta.items():
    path=OUT/f'{key}.png'; image=Image.open(SOURCE/f'{key}.png').convert('RGBA')
    box=image.getbbox(); image=image.crop(box)
    image.save(path,optimize=True)
    entries[key]={'src':f'res://assets/arcane/{key}.png','size':[image.width/4,image.height/4],
                  'anchor':[(info['origin'][0]*384-box[0])/4,(info['origin'][1]*384-box[1])/4]}
for index in range(4):
    rng=random.Random(814+index); size=192
    billow=Image.new('L',(size,size)); draw=ImageDraw.Draw(billow)
    for i in range(20):
        a=rng.random()*math.tau; r=rng.random()*39; x=96+math.cos(a)*r; y=96+math.sin(a)*r
        radius=rng.uniform(19,37); draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=rng.randrange(165,245))
    billow=billow.filter(ImageFilter.GaussianBlur(10))
    fractal=Image.new('L',(size,size))
    for side,weight in [(5,.43),(13,.28),(29,.19),(61,.10)]:
        noise=Image.new('L',(side,side)); noise.putdata([rng.randrange(256) for _ in range(side*side)])
        noise=noise.resize((size,size),Image.Resampling.BICUBIC)
        fractal=ImageChops.add(fractal,noise.point(lambda v:int(v*weight)))
    mask=ImageChops.multiply(billow,fractal.point(lambda v:min(255,max(0,(v-50)*2))))
    image=Image.new('RGBA',(size,size))
    pixels=[]
    for i,(density,opacity) in enumerate(zip(fractal.get_flattened_data(),mask.get_flattened_data())):
        y=i//size; light=int(62+density*.62+(size-y)*.13)
        pixels.append((min(255,light+15),min(255,light+7),light,int(opacity*.8)))
    image.putdata(pixels); image.save(OUT/f'smoke-{index}.png',optimize=True)
    entries[f'smoke-{index}']={'src':f'res://assets/arcane/smoke-{index}.png','size':[96,96],'anchor':[48,48]}
(ROOT/'godot/data/arcane_art.json').write_text(json.dumps(entries,indent=2)+'\n')
print(f'Prepared {len(entries)} detailed effect textures.')
