"""Create compact 3× logical-resolution textures from the existing original art."""
import json
from pathlib import Path
from shutil import copyfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / 'godot'
assets = json.loads((PROJECT / 'data/assets.json').read_text())
for key, data in assets.items():
    if 'directions' in data:
        copyfile(ROOT / data['source'], PROJECT/'assets'/f'{key}.png')
        continue
    image = Image.open(ROOT / data['source']).convert('RGBA')
    density = image.width / data['w'] / (4 if 'frames' in data else 1)
    ratio = min(1, 3 / density)
    # Keep atlas frames on exact pixel boundaries after downsampling.
    if 'frames' in data:
        width, height = round(data['w'] * 3), round(data['h'] * 3)
        atlas = Image.new('RGBA', (width * 4, height * 2))
        for i, frame in enumerate(data['frames']):
            x,y,w,h = frame['frame']
            tile = image.crop((x,y,x+w,y+h)).resize((width,height), Image.Resampling.LANCZOS)
            atlas.paste(tile, (i%4*width,i//4*height))
            frame['frame'] = [i%4*width,i//4*height,width,height]
        image = atlas
    else:
        image = image.resize((round(image.width*ratio),round(image.height*ratio)),Image.Resampling.LANCZOS)
    image.save(PROJECT/'assets'/f'{key}.png',optimize=True)
for name in ['alegreya.ttf','cinzel.ttf','Alegreya-OFL.txt','Cinzel-OFL.txt']:
    copyfile(ROOT/'assets/fonts'/name, PROJECT/'assets'/name)
(PROJECT/'data/assets.json').write_text(json.dumps(assets,separators=(',',':')))
print(f'Prepared {len(assets)} sprite/terrain textures and local fonts.')
