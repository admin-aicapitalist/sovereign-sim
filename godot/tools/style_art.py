"""Reproducible medieval presentation assets. Run with the project's Pillow Python.

Rebuilds from original masters, never from its own output. Logical bounds, atlas
cells and alpha are retained, so animation, picking and saved games are unchanged.
"""
import colorsys
import json
import math
from pathlib import Path
import random
from shutil import copyfile

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets'
UI = OUT / 'ui'
UI.mkdir(exist_ok=True)
RNG = random.Random(771)


def surface(name, base, edge, paper=False):
    """Nine-slice material with engraved brass corners; center tiles at native size."""
    size = 128
    im = Image.new('RGB', (size, size))
    data = []
    for y in range(size):
        for x in range(size):
            grain = RNG.gauss(0, 1.1 if paper else .6)
            grain += math.sin(y * 1.8 + math.sin(x / 29)) * (.4 if paper else 1.3)
            grain += math.sin(x / 17 + y / 21) * .7
            data.append(tuple(max(0, min(255, round(v + grain))) for v in base))
    im.putdata(data)
    d = ImageDraw.Draw(im)
    trim = [(0, '#171611'), (1, edge), (2, '#5e4c32')] if name.startswith('button') else [(0, '#171611'), (1, edge), (2, '#5e4c32'), (4, edge), (5, '#332b20')]
    for inset, color in trim:
        d.rectangle((inset, inset, size-1-inset, size-1-inset), outline=color)
    for x in (10, size-11):
        for y in (10, size-11):
            if name.startswith('button'):
                continue
            d.polygon([(x,y-3),(x+3,y),(x,y+3),(x-3,y)], fill=edge)
            d.point((x-1,y-1), fill='#f1ddb0')
    im.save(UI / f'{name}.png', optimize=True)


surface('timber', (36, 34, 29), '#a88a52')
surface('parchment', (229, 215, 181), '#b69a64', True)
surface('card', (214, 200, 168), '#ac915d', True)
surface('card-hover', (241, 224, 185), '#dec48b', True)
surface('card-selected', (229, 204, 143), '#ffdc89', True)
surface('button', (57, 54, 44), '#887448')
surface('button-hover', (80, 69, 47), '#d3b379')
surface('button-pressed', (102, 47, 35), '#dcbd7f')
surface('button-disabled', (48, 47, 40), '#625c49')
surface('gold', (204, 171, 105), '#f7dba0')
surface('gold-hover', (228, 195, 130), '#fff0c7')

# Original vector heraldry and command symbols, rasterized by Godot at import.
icons = {
    'crown': '<path d="M7 13l5 5 4-10 4 10 5-5-3 13H10z"/><path d="M10 29h12"/><circle cx="7" cy="10" r="2"/><circle cx="16" cy="5" r="2"/><circle cx="25" cy="10" r="2"/>',
    'coin': '<circle cx="16" cy="16" r="12"/><circle cx="16" cy="16" r="9"/><path d="M16 9l3 5 4 2-4 2-3 5-3-5-4-2 4-2z"/>',
    'heroes': '<path d="M7 4l18 22M25 4L7 26M5 19l8 7M19 26l8-7M7 4l1 7 4-3M25 4l-1 7-4-3"/>',
    'sun': '<circle cx="16" cy="16" r="6"/><path d="M16 2v5M16 25v5M2 16h5M25 16h5M6 6l4 4M22 22l4 4M6 26l4-4M22 10l4-4"/>',
    'build': '<path d="M5 28V12h5V6h4v6h4V6h4v6h5v16zM13 28v-9h6v9"/>',
    'attack': '<path d="M8 29V4M9 5h18l-5 6 5 6H9"/>',
    'explore': '<circle cx="16" cy="16" r="12"/><path d="M21 7l-2 12-8 6 2-12zM16 1v4M16 27v4M1 16h4M27 16h4"/>',
    'spells': '<path d="M16 3l3 9 10 4-10 3-3 10-3-10-10-3 10-4z"/>',
    'heal': '<path d="M12 5h8v7h7v8h-7v7h-8v-7H5v-8h7z"/>',
    'ward': '<path d="M5 5l11-3 11 3v12c0 7-11 13-11 13S5 24 5 17zM16 7v16M10 13h12"/>',
    'haste': '<path d="M20 3L9 17h7l-4 12 13-17h-8zM3 9h7M2 24h6"/>',
    'lightning': '<path d="M18 2L5 18h10l-2 12L28 12H18z"/>',
    'frost': '<path d="M16 2v28M4 9l24 14M4 23L28 9M12 5l4 4 4-4M12 27l4-4 4 4M5 14l6-1-2-6M23 25l-2-6 6-1"/>',
    'meteor': '<circle cx="11" cy="22" r="7"/><path d="M8 13L25 3l-4 8 9-4-12 17M17 16l8-5"/>',
    'farsight': '<path d="M2 16s6-9 14-9 14 9 14 9-6 9-14 9S2 16 2 16z"/><circle cx="16" cy="16" r="5"/>',
}
for name, shape in icons.items():
    (UI / f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 32 32"><g fill="none" stroke="#d9bc7f" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">{shape}</g></svg>')
    if name in ('heal','lightning','farsight','frost','ward','haste','meteor','attack','explore'):
        ink={'heal':'b9ca99','frost':'bddde3','lightning':'efcf8e','meteor':'f0ad79','ward':'b4c8e2','farsight':'b6d0bd'}.get(name,'e2c18a')
        seal=f'<defs><radialGradient id="stone" cx="35%" cy="25%" r="80%"><stop stop-color="#536056"/><stop offset="1" stop-color="#202d2d"/></radialGradient></defs><circle cx="24" cy="24" r="22" fill="url(#stone)" stroke="#9b7b43" stroke-width="2"/><circle cx="24" cy="24" r="19" fill="none" stroke="#c4a76c" stroke-width=".6"/><g transform="translate(8 8)" fill="none" stroke="#{ink}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">{shape}</g>'
        (UI/f'{name}-seal.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 48 48">{seal}</svg>')
crest = '<path d="M7 3h50v34c0 13-25 25-25 25S7 50 7 37z" fill="#742f29" stroke="#d9bc7f" stroke-width="2"/><path d="M11 7h42v29c0 11-21 21-21 21S11 47 11 36z" fill="none" stroke="#b29158"/><g transform="translate(16 13)" fill="#e3ca91" stroke="#f1dda9" stroke-width=".5">'+icons['crown']+'</g>'
(UI/'crest.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">'+crest+'</svg>')
copyfile(ROOT/'assets/fonts/alegreya-italic.ttf', OUT/'alegreya-italic.ttf')

assets = json.loads((ROOT/'godot/data/assets.json').read_text())
for key, meta in assets.items():
    # Leisure venues have their own reproducible finishing pipeline.
    if key in ('inn','brothel') or key.startswith('terrain-') or key.startswith('bridge-') or key=='unit_warlord' or 'directions' in meta:
        continue
    src = Image.open(ROOT/meta['source']).convert('RGBA')
    rendered = ROOT/f'assets/art/royal/{key}-render.png'
    if rendered.exists():
        src=Image.open(rendered).convert('RGBA')
        ratio=src.width/240
        shadow=Image.new('RGBA',src.size); d=ImageDraw.Draw(shadow)
        if key=='palace':
            for bounds,opacity in (((24,174,226,233),18),((33,180,217,229),25),((43,185,209,225),34)):
                d.ellipse(tuple(v*ratio for v in bounds),fill=(25,39,32,opacity))
            shadow=shadow.filter(ImageFilter.GaussianBlur(1.6*ratio))
            src=Image.alpha_composite(shadow,src)
        else:
            building=json.loads((ROOT/'assets/art/buildings/buildings.json').read_text())[key]
            original=json.loads((ROOT/f'assets/art/buildings/source/{key}.json').read_text())
            anchor=[v*src.width for v in original['ground_anchor_normalized']]
            radius=(3.1 if original['plot_size']==1 else 6.2)*.7071/14.3*src.width
            for factor,opacity in ((1.06,18),(.93,26)):
                rx,ry=radius*factor,radius*factor*.5
                d.ellipse((anchor[0]-rx,anchor[1]-ry,anchor[0]+rx,anchor[1]+ry),fill=(25,39,32,opacity))
            shadow=shadow.filter(ImageFilter.GaussianBlur(src.width*.0035))
            crop=tuple(round(v*src.width/building['master_render_size'][0]) for v in building['crop'])
            src=Image.alpha_composite(shadow,src).crop(crop)
    # Always crop original animation masters by their regular 4 × 2 cell grid.
    target = Image.open(OUT/f'{key}.png').size
    if 'frames' in meta:
        result = Image.new('RGBA', target)
        sw, sh = src.width//4, src.height//2
        for i, frame in enumerate(meta['frames']):
            x,y,w,h = frame['frame']
            tile = src.crop((i%4*sw, i//4*sh, (i%4+1)*sw, (i//4+1)*sh)).resize((w,h), Image.Resampling.LANCZOS)
            result.paste(tile, (x,y))
        src = result
    else:
        src = src.resize(target, Image.Resampling.LANCZOS)
    alpha = src.getchannel('A')
    rgb = src.convert('RGB')
    # Warm limestone, richer cloth and foliage; retain directional light and wear.
    rgb = ImageEnhance.Contrast(rgb).enhance(1.10 if key.startswith('unit_') else 1.07)
    rgb = ImageEnhance.Color(rgb).enhance(1.13 if key.startswith('unit_') else .94)
    rgb = ImageEnhance.Brightness(rgb).enhance(1.09 if key.startswith(('unit_', 'pine', 'oak')) else 1.07)
    if key in ('palace', 'wizards', 'temple', 'tower') and not rendered.exists():
        pixels = []
        for r,g,b in rgb.get_flattened_data():
            h,s,v = colorsys.rgb_to_hsv(r/255,g/255,b/255)
            # Tile hue separates slate civic roofs from terracotta timber guilds.
            if .055 < h < .135 and s > .34 and v > .18:
                amount = min(1, (s-.34)*9) * min(1, (v-.18)*6)
                nr,ng,nb = colorsys.hsv_to_rgb(.56, s*.55, v*.83)
                r,g,b = [round(c*(1-amount)+n*255*amount) for c,n in zip((r,g,b),(nr,ng,nb))]
            elif s < .17 and v > .23:
                r,g,b = min(255,round(r*1.07)), min(255,round(g*1.025)), round(b*.96)
            pixels.append((r,g,b))
        rgb.putdata(pixels)
    rgb = rgb.filter(ImageFilter.UnsharpMask(radius=.7, percent=45, threshold=3))
    rgb.putalpha(alpha)
    rgb.save(OUT/f'{key}.png', optimize=True)

boss_source=ROOT/'assets/art/royal'
poses=['idle']+[f'walk-{i}' for i in range(4)]+[f'attack-{i}' for i in range(3)]
if 'directions' not in assets.get('unit_warlord',{}) and all((boss_source/f'warlord-{pose}.png').exists() for pose in poses):
    import copy
    meta=copy.deepcopy(assets['unit_troll'])
    source_meta=json.loads((ROOT/'assets/art/units/source/troll.json').read_text())
    full=[]
    for pose in poses:
        im=Image.open(boss_source/f'warlord-{pose}.png').convert('RGBA')
        anchor=[v*im.width for v in source_meta['anchor_normalized']]
        rx=14*im.width/96; ry=rx*.45
        shadow=Image.new('RGBA',im.size); d=ImageDraw.Draw(shadow)
        d.ellipse((anchor[0]-rx,anchor[1]-ry,anchor[0]+rx,anchor[1]+ry),fill=(25,39,32,58))
        shadow=shadow.filter(ImageFilter.GaussianBlur(im.width/96*.75))
        full.append(Image.alpha_composite(shadow,im))
    density=full[0].width/96
    bounds=[im.getbbox() for im in full]; pad=density*2
    crop=(max(0,math.floor((min(b[0] for b in bounds)-pad)/density)*density),
          max(0,math.floor((min(b[1] for b in bounds)-pad)/density)*density),
          min(full[0].width,math.ceil((max(b[2] for b in bounds)+pad)/density)*density),
          min(full[0].height,math.ceil((max(b[3] for b in bounds)+pad)/density)*density))
    tiles=[im.crop(crop) for im in full]
    meta['w']=tiles[0].width/density; meta['h']=tiles[0].height/density
    meta['anchor']=[(anchor[0]-crop[0])/density,(anchor[1]-crop[1])/density]
    w,h=round(meta['w']*3),round(meta['h']*3)
    master=Image.new('RGBA',(tiles[0].width*4,tiles[0].height*2))
    target=Image.new('RGBA',(w*4,h*2))
    for i,tile in enumerate(tiles):
        master.paste(tile,(i%4*tile.width,i//4*tile.height))
        x,y=i%4*w,i//4*h
        solid=tile.getchannel('A').point(lambda a:255 if a>=96 else 0).getbbox()
        meta['frames'][i]['frame']=[x,y,w,h]
        meta['frames'][i]['bounds']=[v/density for v in solid]
        target.paste(tile.resize((w,h),Image.Resampling.LANCZOS),(x,y))
    meta['healthOffset']=meta['frames'][0]['bounds'][1]-meta['anchor'][1]-7
    meta['sourceSize']=list(master.size)
    master.save(boss_source/'warlord.png',optimize=True)
    target.save(OUT/'unit_warlord.png',optimize=True)
    meta['src']='res://assets/unit_warlord.png'; meta['source']='assets/art/royal/warlord.png'
    assets['unit_warlord']=meta
    (ROOT/'godot/data/assets.json').write_text(json.dumps(assets,separators=(',',':')))

# Mipmaps preserve the painted roof and foliage detail when the camera pulls out.
for imported in OUT.glob('*.png.import'):
    imported.write_text(imported.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
print('Prepared royal interface materials, heraldry and refreshed sprite masters.')
