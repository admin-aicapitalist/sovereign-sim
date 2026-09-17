"""Finish the Inn/Brothel renders made by tools/art/render_buildings.py.
Usage: .venv/bin/python godot/tools/finish_leisure.py /tmp/sovereign-leisure-art
"""
import json
import math
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

root = Path(__file__).resolve().parents[2]
source_dir = Path(sys.argv[1])
manifest_path = root / 'godot/data/assets.json'
manifest = json.loads(manifest_path.read_text())
for key in ('inn', 'brothel'):
    meta = json.loads((source_dir / f'{key}.json').read_text())
    source = Image.open(source_dir / f'{key}-render.png').convert('RGBA')
    ratio = source.width / 240
    anchor = [v * source.width for v in meta['ground_anchor_normalized']]
    shadow = Image.new('RGBA', source.size)
    draw = ImageDraw.Draw(shadow)
    radius = 6.2 * .7071 / 14.3 * source.width
    for factor, alpha in ((1.06, 18), (.93, 26)):
        rx, ry = radius * factor, radius * factor * .5
        draw.ellipse((anchor[0]-rx, anchor[1]-ry, anchor[0]+rx, anchor[1]+ry), fill=(25, 39, 32, alpha))
    combined = Image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(source.width*.0035)), source)
    bb = combined.getbbox()
    pad = math.ceil(ratio * 2)
    crop = (max(0, bb[0]-pad), max(0, bb[1]-pad), min(source.width, bb[2]+pad), min(source.height, bb[3]+pad))
    sprite = combined.crop(crop)
    sprite = ImageEnhance.Color(sprite).enhance(1.05)
    sprite.save(root / f'godot/assets/{key}.png', optimize=True)
    solid = source.crop(crop).getchannel('A').point(lambda x: 255 if x >= 96 else 0)
    manifest[key] = {
        'w': sprite.width / ratio, 'h': sprite.height / ratio,
        'anchor': [(anchor[0]-crop[0])/ratio, (anchor[1]-crop[1])/ratio],
        'bounds': [v/ratio for v in solid.getbbox()], 'pixelArt': False,
        'sourceSize': list(sprite.size), 'src': f'res://assets/{key}.png',
        'source': f'godot/assets/{key}.png',
        'visitors': [dict(actor=v['actor'], phase=v['phase'], at=[(v['at_normalized'][0]*source.width-crop[0])/ratio,(v['at_normalized'][1]*source.height-crop[1])/ratio]) for v in meta.get('visitors',[])],
        'lanterns': [dict(color=v['color'],at=[(v['at_normalized'][0]*source.width-crop[0])/ratio,(v['at_normalized'][1]*source.height-crop[1])/ratio]) for v in meta.get('lanterns',[])],
        'effects': [{'type': e['type'], 'at': [(e['at_normalized'][0]*source.width-crop[0])/ratio, (e['at_normalized'][1]*source.height-crop[1])/ratio]} for e in meta['effects']],
    }
    print(key, sprite.size)
manifest_path.write_text(json.dumps(manifest, separators=(',', ':')))
