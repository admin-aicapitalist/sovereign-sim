"""Pack character poses without resampling; export stable anchors and previews."""

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from finish_palace import font, version_runtime_scripts

ROOT = Path(__file__).resolve().parents[2]
KEYS = ('warrior', 'ranger', 'wizard', 'guard', 'peasant', 'collector', 'rat', 'goblin', 'skeleton', 'troll')
POSES = ['idle'] + [f'walk-{i}' for i in range(4)] + [f'attack-{i}' for i in range(3)]


def preview(sprites, animated=False):
    width, height = (1280, 800) if animated else (1900, 1120)
    cell_w, cell_h = width // 5, (height - 120) // 2
    scale = 4.1 if animated else 6.2
    base = Image.new('RGBA', (width, height), '#22332b')
    d = ImageDraw.Draw(base)
    d.text((width // 2, 40), 'S O V E R E I G N   /   T H E   B O R D E R L A N D S',
           font=font(19 if animated else 27, True), fill='#e8dbc0', anchor='mm')
    d.text((width // 2, 78), 'HEROES, WORKERS & MONSTERS  ·  IDLE / WALK / ACTION',
           font=font(12 if animated else 14), fill='#aebba0', anchor='mm')
    for i, (name, _, __) in enumerate(sprites):
        x, y = i % 5 * cell_w, i // 5 * cell_h + 110
        d.rounded_rectangle((x + 10, y, x + cell_w - 10, y + cell_h - 14), radius=5,
                            fill='#2d4338', outline='#697253')
        d.text((x + cell_w // 2, y + cell_h - 43), name,
               font=font(14 if animated else 19, True), fill='#e3d7bc', anchor='mm')
    frames = []
    for pose in ([0, 0, 1, 2, 3, 4, 1, 2, 3, 4, 0, 5, 6, 7, 0] if animated else [0]):
        board = base.copy()
        for i, (_, images, anchor) in enumerate(sprites):
            img = images[pose]
            ratio = img.info['density']
            img = img.resize((round(img.width / ratio * scale), round(img.height / ratio * scale)), Image.Resampling.LANCZOS)
            x, y = i % 5 * cell_w + cell_w / 2, i // 5 * cell_h + 110 + cell_h - 72
            board.alpha_composite(img, (round(x - anchor[0] * scale), round(y - anchor[1] * scale)))
        frames.append(board.convert('RGB'))
    return frames


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=ROOT / 'assets/art/units/source')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/art/units')
    parser.add_argument('--no-integrate', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    assets, info, previews = {}, {}, []
    for key in KEYS:
        meta = json.loads((args.source / f'{key}.json').read_text())
        assert meta['poses'] == POSES, f'{key}: render every pose before exporting'
        masters = [Image.open(args.source / f'{key}-{pose}.png').convert('RGBA') for pose in POSES]
        size = masters[0].width
        ratio = size / meta['logical_size'][0]
        assert size >= 960 and all(im.size == (size, size) for im in masters)
        anchor = [n * size for n in meta['anchor_normalized']]
        shadow = Image.new('RGBA', (size, size))
        d = ImageDraw.Draw(shadow)
        rx = (14 if key == 'troll' else 11 if key == 'rat' else 6.5) * ratio
        ry = rx * .45
        d.ellipse((anchor[0] - rx, anchor[1] - ry, anchor[0] + rx, anchor[1] + ry), fill=(25, 39, 32, 58))
        shadow = shadow.filter(ImageFilter.GaussianBlur(ratio * .75))
        images = []
        for pose, master in zip(POSES, masters):
            bb = master.getchannel('A').getbbox()
            assert bb and all(0 < v < size for v in bb), f'{key}/{pose}: clipped silhouette {bb}'
            images.append(Image.alpha_composite(shadow, master))
        boxes = [im.getbbox() for im in images]
        # Every pose has the same crop and floor anchor: no jitter when changing frames.
        bounds = [min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes)]
        step, pad = round(ratio), ratio * 2
        crop = (max(0, math.floor((bounds[0] - pad) / step) * step),
                max(0, math.floor((bounds[1] - pad) / step) * step),
                min(size, math.ceil((bounds[2] + pad) / step) * step),
                min(size, math.ceil((bounds[3] + pad) / step) * step))
        images = [im.crop(crop) for im in images]
        cw, ch = images[0].size
        atlas = Image.new('RGBA', (cw * 4, ch * 2))
        frames = []
        for i, (im, master) in enumerate(zip(images, masters)):
            x, y = i % 4 * cw, i // 4 * ch
            atlas.alpha_composite(im, (x, y))
            solid = master.crop(crop).getchannel('A').point(lambda a: 255 if a >= 96 else 0)
            frames.append({'pose': POSES[i], 'frame': [x, y, cw, ch], 'bounds': [v / ratio for v in solid.getbbox()]})
            im.info['density'] = ratio
        path = args.output / f'{key}.png'
        atlas.save(path, optimize=True)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()[:12]
        logical_anchor = [(anchor[0] - crop[0]) / ratio, (anchor[1] - crop[1]) / ratio]
        selection = [(meta['selection_normalized'][i] - meta['anchor_normalized'][i]) * size / ratio for i in range(2)]
        runtime = {'src': f'{key}.png?v={digest}', 'w': cw / ratio, 'h': ch / ratio, 'anchor': logical_anchor,
                   'sourceSize': list(atlas.size), 'density': ratio, 'pixelArt': False, 'frames': frames,
                   'animations': {'idle': [0], 'walk': [1, 2, 3, 4], 'attack': [5, 6, 7]},
                   'selection': selection, 'selectionRadius': meta['selection_radius'],
                   'healthOffset': frames[0]['bounds'][1] - logical_anchor[1] - 7}
        assets[key] = runtime
        info[key] = {'name': meta['name'], 'scene': f'source/{key}.blend', 'master_render_size': [size, size],
                     'crop': list(crop), **runtime}
        previews.append((meta['name'], images, logical_anchor))
        print(f'{key}: 8 × {size}² renders → {atlas.width}×{atlas.height} atlas ({path.stat().st_size / 1048576:.2f} MiB)')
    manifest = '// Generated by tools/art/finish_units.py.\n(function () {\n'
    manifest += '  const assets = ' + json.dumps(assets, separators=(',', ':')) + ';\n'
    manifest += '  G.unitAssets = G.unitAssets || {};\n'
    manifest += '  for (const [key, asset] of Object.entries(assets)) {\n'
    manifest += '    asset.src = new URL(asset.src, document.currentScript.src).href;\n'
    manifest += '    G.unitAssets[key] = asset;\n  }\n})();\n'
    (args.output / 'units-sprites.js').write_text(manifest)
    (args.output / 'units.json').write_text(json.dumps(info, indent=2) + '\n')
    preview(previews)[0].save(args.output / 'units-preview.png')
    animation = preview(previews, animated=True)
    animation[0].save(args.output / 'units-animated.gif', save_all=True, append_images=animation[1:],
                      duration=140, loop=0, disposal=2, optimize=False)
    if not args.no_integrate:
        version_runtime_scripts()


if __name__ == '__main__':
    main()
