"""Finish the clean building plates with the established royal crop and palette."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/art/atmosphere'
OUT = ROOT / 'godot/assets/atmosphere'
OUT.mkdir(parents=True, exist_ok=True)
projections = json.loads((ART / 'projection.json').read_text())
buildings = json.loads((ROOT / 'assets/art/buildings/buildings.json').read_text())
manifest = json.loads((ROOT / 'godot/data/assets.json').read_text())
result = {}
for key, source in projections.items():
    src = Image.open(ART / f'{key}-render.png').convert('RGBA')
    shadow = Image.new('RGBA', src.size)
    draw = ImageDraw.Draw(shadow)
    if key == 'palace':
        ratio = src.width / 240
        for bounds, opacity in (((24, 174, 226, 233), 18), ((33, 180, 217, 229), 25), ((43, 185, 209, 225), 34)):
            draw.ellipse(tuple(v*ratio for v in bounds), fill=(25, 39, 32, opacity))
        shadow = shadow.filter(ImageFilter.GaussianBlur(1.6*ratio))
        crop = (0, 0, src.width, src.height)
    else:
        building = buildings[key]
        original = json.loads((ROOT / f'assets/art/buildings/source/{key}.json').read_text())
        anchor = [v*src.width for v in original['ground_anchor_normalized']]
        radius = (3.1 if original['plot_size'] == 1 else 6.2)*.7071/14.3*src.width
        for factor, opacity in ((1.06, 18), (.93, 26)):
            rx, ry = radius*factor, radius*factor*.5
            draw.ellipse((anchor[0]-rx, anchor[1]-ry, anchor[0]+rx, anchor[1]+ry), fill=(25, 39, 32, opacity))
        shadow = shadow.filter(ImageFilter.GaussianBlur(src.width*.0035))
        crop = tuple(round(v*src.width/building['master_render_size'][0]) for v in building['crop'])
    def logical(point):
        return [(point[i]*1440-crop[i])/(crop[i+2]-crop[i])*manifest[key][('w', 'h')[i]] for i in (0, 1)]
    flags = []
    for flag in source['flags']:
        at, end, bottom = [logical(flag[k]) for k in ('at', 'end', 'bottom')]
        flags.append({'at': at, 'span': [end[i]-at[i] for i in (0, 1)], 'height': bottom[1]-at[1]})
    target = Image.open(ROOT / f'godot/assets/{key}.png').size
    src = Image.alpha_composite(shadow, src).crop(crop).resize(target, Image.Resampling.LANCZOS)
    alpha = src.getchannel('A')
    rgb = ImageEnhance.Contrast(src.convert('RGB')).enhance(1.07)
    rgb = ImageEnhance.Color(rgb).enhance(.94)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.07)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=.7, percent=45, threshold=3))
    rgb.putalpha(alpha)
    rgb.save(OUT / f'{key}.png', optimize=True)
    result[key] = {'src': f'res://assets/atmosphere/{key}.png', 'flags': flags}
(ROOT / 'godot/data/atmosphere.json').write_text(json.dumps(result, indent=2) + '\n')
print('Finished clean building plates and', sum(len(v['flags']) for v in result.values()), 'projected flags')
