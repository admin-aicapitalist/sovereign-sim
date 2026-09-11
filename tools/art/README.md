# Sprite tools

The first rendered asset is the [Sovereign Royal Palace](../../assets/art/palace/README.md),
with an editable Blender scene, Pixelorama project, and transparent pixel sprites.
The [remaining building collection](../../assets/art/buildings/README.md) provides
ten matching high-resolution buildings and monster lairs with editable Blender scenes.
The [character collection](../../assets/art/units/README.md) adds ten matching heroes,
workers and monsters, with 80 high-resolution poses and editable Blender timelines.
The [environment collection](../../assets/art/environment/README.md) provides
35 tree, scenery and ground images, matching lighting, editable Blender scenes,
and reproducible seamless terrain materials.

Installed on this Apple Silicon Mac on 2026-09-11. These are optional authoring
tools; the browser game still runs without them.

| Tool | Installed version | App / command |
|---|---|---|
| Pixelorama | 1.2.2 | `/Applications/Pixelorama.app`; `pixelorama` |
| LibreSprite | 1.1 release, reports `1.1-dev` | `/Applications/libresprite.app`; `libresprite` |
| Blender | 5.2.1 LTS | `/Applications/Blender.app`; `blender` |
| ImageMagick | 7.1.2-31 | `magick` |
| Pillow | 12.3.0 | Project `.venv/bin/python` |

Open the editors from Applications, or run `pixelorama`, `libresprite`, or
`blender` in a terminal. The sprite editors have small launch scripts in
`/opt/homebrew/bin` that execute the binaries inside their app bundles. Plain
symlinks cause these editors to miss their bundled resources.

## Python sprite scripts

From the repository root:

```sh
.venv/bin/python your_sprite_script.py
```

To recreate the Python environment:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r tools/art/requirements.txt
```

## Export commands

Replace the example input filenames with your own artwork. Create output
directories before exporting.

```sh
# Pixelorama: export a saved project as a PNG sheet and project JSON.
pixelorama --headless --quit -- --export --spritesheet --json --output /tmp/sheet.png hero.pxo

# LibreSprite: export an animation as a PNG sheet with frame rectangles.
libresprite --batch hero.ase --sheet /tmp/hero.png --data /tmp/hero.json --format json-array

# Blender: run a Python script that builds and renders an isometric scene.
blender --background --factory-startup --python-exit-code 1 --python render_sprites.py

# ImageMagick: enlarge a sprite with crisp pixels.
magick sprite.png -filter point -resize 200% /tmp/sprite-preview.png
```

Pixelorama 1.2.2 has two observed export limitations: `--output` selects the
directory, but the PNG uses the project's saved export filename and the JSON
uses the project name. A project with animated shader effects crashed in
headless mode; the same example with those effects removed exported correctly.
Use flattened layers for automated exports, or use the desktop editor for
effects. Plain PNG imports can open an import dialog, so use saved `.pxo`
projects for Pixelorama batch work. Its JSON contains project data; LibreSprite's
JSON is preferable when the game needs sprite-sheet frame rectangles.

## Installation sources and notes

- [Pixelorama official release](https://github.com/Orama-Interactive/Pixelorama/releases/tag/v1.2.2): universal macOS DMG, verified against the SHA-256 digest published by GitHub.
- [LibreSprite official release](https://github.com/LibreSprite/LibreSprite/releases/tag/v1.1): ARM64 macOS archive. Its bundled libraries required local ad-hoc signing to repair the [upstream packaging defect](https://github.com/LibreSprite/LibreSprite/issues/594). The missing `CFBundleExecutable` entry was added and the app was signed locally; the installed bundle passes `codesign --verify --deep --strict`.
- Blender and ImageMagick were installed through Homebrew: `brew install --cask blender` and `brew install imagemagick`.
- Pillow was installed in the project environment and is pinned in `requirements.txt`.

When running through a filesystem sandbox, Blender rendering and LibreSprite
startup may require execution outside it. Pixelorama also writes normal app
settings under the user's Library directory.

## Verified

- Pillow: transparent PNG write/read.
- ImageMagick: nearest-neighbor scaling preserves pixels and transparency.
- Blender: background CPU render produces a transparent RGBA PNG.
- LibreSprite: PNG round-trip preserves all pixels; sprite-sheet JSON exports.
- Pixelorama: desktop startup and six-frame PNG sheet export; a project without
  layer effects also exports headlessly with matching pixels and project JSON.

## Game dimensions

The terrain grid is 64×32. Building masters are 1920×1920, based on a 240×240
logical canvas. Character masters are 960×960, based on a 96×96 logical canvas.
Both exporters crop transparent margins and preserve native pixel density and
foot anchors. Characters use one idle, four walk and three action frames packed
in one atlas per type, with horizontal mirroring for facing. Peasants hammer while
building or repairing. Tree masters are 1280×1280 on a 160×160 logical canvas;
small props use the same master resolution on a 96×96 logical canvas. Ground
materials have six texture pixels per logical pixel and are cached in sections
at a resolution appropriate to the current zoom and display.

`js/sprites.js` loads the imported manifests before play and retains procedural
fallbacks (240×240 buildings and 64×76 characters, rasterized at twice those
dimensions) if individual images fail to load.
