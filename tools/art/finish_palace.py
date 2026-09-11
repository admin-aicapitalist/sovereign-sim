"""Export a full-resolution game texture and optional palette-controlled pixel sprites."""

import hashlib
import json
import re
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/palace"
SIZE = 240
COLORS = 88


def font(size, serif=False):
    candidates = (["/System/Library/Fonts/Supplemental/Georgia.ttf"] if serif else []) + [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


def make_pixelorama(palace, shadow):
    """Native two-layer .pxo v7 project: editable palace above a separate ground shadow."""
    layer = dict(type=0, opacity=1.0, blend_mode=0, visible=True, locked=False,
                 parent=-1, clipping_mask=False, effects=[], new_cels_linked=False,
                 metadata={}, ui_color="(0.0, 0.0, 0.0, 0.0)")
    cel = dict(opacity=1.0, z_index=0, metadata={}, ui_color="(0.0, 0.0, 0.0, 0.0)")
    data = dict(pxo_version=7, pixelorama_version="v1.2.2-stable", size_x=SIZE, size_y=SIZE,
                color_mode=5, current_frame=0, current_layer=1, fps=12,
                layers=[dict(layer,name="Ground shadow"),dict(layer,name="Royal palace")],
                frames=[dict(cels=[cel.copy(),cel.copy()],duration=1.0,metadata={})],
                tags=[], guides=[], brushes=[], reference_images=[], tilesets=[],
                symmetry_points=[SIZE-1,SIZE-1], metadata={}, next_keyframe_id=0,
                author_display_name="Sovereign", license="", user_data="Original Sovereign castle, rendered from sovereign-palace.blend.",
                export_profile=dict(directory_path=json.dumps(str(OUT)),file_name='"palace"',
                                    file_format="0",current_tab="0",resize="100",export_json="false"))
    import io
    buf=io.BytesIO()
    Image.alpha_composite(shadow,palace).save(buf,format="PNG")
    with ZipFile(OUT/"sovereign-palace.pxo","w",ZIP_DEFLATED) as z:
        z.writestr("mimetype","application/x-pixelorama")
        z.writestr("data.json",json.dumps(data))
        z.writestr("preview.png",buf.getvalue())
        for i,im in enumerate((shadow,palace),1):
            z.writestr(f"image_data/frames/1/layer_{i}",im.tobytes())


def version_runtime_scripts():
    """Refresh script URLs so an ordinary reload picks up regenerated artwork and code."""
    for page in (ROOT / "index.html", ROOT / "test/spritesheet.html"):
        def version(match):
            asset_path = page.parent / match[2]
            digest = hashlib.sha256(asset_path.read_bytes()).hexdigest()[:12]
            return f'{match[1]}{match[2]}?v={digest}{match[3]}'
        page.write_text(re.sub(r'(<script src=")([^"?]+)(?:\?[^\"]*)?(")', version, page.read_text()))


def main():
    source=Image.open(OUT/"palace-render.png").convert("RGBA")
    # Preserve the rendered material detail and antialiased silhouette for the game.
    # The separate pixel exports below remain available for pixel-art editing.
    ratio=source.width/SIZE
    high_shadow=Image.new("RGBA",source.size)
    draw=ImageDraw.Draw(high_shadow)
    for bounds,opacity in (((24,174,226,233),18),((33,180,217,229),25),((43,185,209,225),34)):
        draw.ellipse(tuple(v*ratio for v in bounds),fill=(25,39,32,opacity))
    high_shadow=high_shadow.filter(ImageFilter.GaussianBlur(1.6*ratio))
    high_sprite=Image.alpha_composite(high_shadow,source)
    high_path=OUT/"palace-hires.png"
    high_sprite.save(high_path,optimize=True)
    high_preview=Image.new("RGBA",source.size,(36,55,45,255))
    high_preview.alpha_composite(high_sprite)
    high_preview.convert("RGB").save(OUT/"palace-hires-preview.png")
    small=source.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
    alpha=small.getchannel("A").point(lambda v:255 if v>=115 else 0)
    pixels=[rgb for rgb,a in zip(small.convert("RGB").get_flattened_data(),alpha.get_flattened_data()) if a]
    # Keep small crimson banners and moss patches represented in the palette.
    reds=[p for p in pixels if p[0]>p[1]*1.65 and p[0]>p[2]*1.7 and p[0]>60]
    greens=[p for p in pixels if p[1]>p[0]*1.10 and p[1]>p[2]*1.2 and p[1]>38]
    weighted=pixels+reds*4+greens*8
    sample=Image.new("RGB",(len(weighted),1))
    sample.putdata(weighted)
    quantized=sample.quantize(colors=COLORS,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    palace=small.convert("RGB").quantize(palette=quantized,dither=Image.Dither.NONE).convert("RGBA")
    palace.putalpha(alpha)
    # The three bands give a quiet pixel-art contact shadow on any ground colour.
    shadow=Image.new("RGBA",(SIZE,SIZE))
    draw=ImageDraw.Draw(shadow)
    draw.ellipse((24,174,226,233),fill=(25,39,32,18))
    draw.ellipse((33,180,217,229),fill=(25,39,32,25))
    draw.ellipse((43,185,209,225),fill=(25,39,32,34))
    sprite=Image.alpha_composite(shadow,palace)
    palace.save(OUT/"palace-no-shadow.png")
    shadow.save(OUT/"palace-shadow.png")
    sprite.save(OUT/"palace.png")
    sprite.resize((480,480),Image.Resampling.NEAREST).save(OUT/"palace@2x.png")
    # Readable presentation at 4x, preserving every pixel.
    preview=Image.new("RGB",(1040,1120))
    px=preview.load()
    for y in range(preview.height):
        t=y/preview.height
        for x in range(preview.width):
            glow=max(0,1-((x-520)/710)**2-((y-605)/790)**2)
            px[x,y]=(round(29+glow*15+t*2),round(43+glow*17+t*2),round(40+glow*11))
    preview=preview.convert("RGBA")
    preview.alpha_composite(sprite.resize((960,960),Image.Resampling.NEAREST),(40,23))
    d=ImageDraw.Draw(preview)
    d.line((420,1002,620,1002),fill="#8d8258",width=1)
    d.text((520,1030),"S O V E R E I G N",fill="#e4d7b4",font=font(25,True),anchor="mm")
    d.text((520,1066),"THE ROYAL PALACE  /  WEATHERED",fill="#a4b0a0",font=font(12),anchor="mm")
    preview.convert("RGB").save(OUT/"palace-preview.png")
    # A second preview gives an honest view on light terrain, at actual game scale.
    field=Image.new("RGBA",(320,300),(132,146,91,255))
    field.alpha_composite(sprite,(40,20))
    field.resize((960,900),Image.Resampling.NEAREST).convert("RGB").save(OUT/"palace-on-grass.png")
    palette=quantized.getpalette()[:COLORS*3]
    lines=["GIMP Palette","Name: Sovereign palace","Columns: 8","# Generated from the original Blender palace render"]
    for i in range(0,len(palette),3):
        r,g,b=palette[i:i+3]
        lines.append(f"{r:3} {g:3} {b:3}  Palace {i//3+1:02}")
    (OUT/"palace-palette.gpl").write_text("\n".join(lines)+"\n")
    theme=json.loads((OUT/"color-theme.json").read_text())
    reference_lines=["GIMP Palette","Name: Sovereign reference colours","Columns: 5","# Sampled from the user-provided city screenshot"]
    for group,colors in theme["sampled_reference"].items():
        for i,color in enumerate(colors):
            rgb=tuple(int(color[j:j+2],16) for j in (0,2,4))
            reference_lines.append(f"{rgb[0]:3} {rgb[1]:3} {rgb[2]:3}  {group} {i+1}")
    (OUT/"reference-palette.gpl").write_text("\n".join(reference_lines)+"\n")
    make_pixelorama(palace,shadow)
    projection=json.loads((OUT/"projection.json").read_text())
    metadata=dict(name="Sovereign Royal Palace",image="palace-hires.png",size=list(source.size),
                  logical_size=[SIZE,SIZE],pixel_art_image="palace.png",pixel_art_size=[SIZE,SIZE],
                  pixel_art_scale_2x="palace@2x.png",pixel_art_palette_colors=COLORS,
                  ground_anchor=[round(v*SIZE) for v in projection["ground_anchor_normalized"]],
                  ground_anchor_space="logical pixels",
                  projection="2:1 isometric, orthographic, 30-degree elevation",
                  source_scene="sovereign-palace.blend",pixelorama_project="sovereign-palace.pxo",
                  color_theme=theme["name"],
                  wear=["chipped battlements","fractured tower masonry","gate soot","water stains","lichen and ivy","worn clay tiles","frayed banners"],
                  runtime_manifest="palace-sprite.js",
                  game_integration="Full-resolution texture with smooth scaling, rendered using the logical ground anchor.")
    (OUT/"palace.json").write_text(json.dumps(metadata,indent=2)+"\n")
    # A classic-script manifest keeps direct file:// play working without JSON fetch.
    runtime=dict(w=SIZE,h=SIZE,anchor=metadata["ground_anchor"],bounds=list(alpha.getbbox()),
                 pixelArt=False,sourceSize=list(source.size))
    manifest="// Generated by tools/art/finish_palace.py.\n(function () {\n"
    manifest+="  const asset = "+json.dumps(runtime)+";\n"
    digest=hashlib.sha256(high_path.read_bytes()).hexdigest()[:12]
    manifest+=f'  asset.src = new URL("palace-hires.png?v={digest}", document.currentScript.src).href;\n'
    manifest+="  G.spriteAssets = G.spriteAssets || {};\n  G.spriteAssets.palace = asset;\n})();\n"
    (OUT/"palace-sprite.js").write_text(manifest)
    version_runtime_scripts()
    assert sprite.size==(240,240) and sprite.mode=="RGBA"
    assert alpha.getbbox() and alpha.getbbox()[0]>0 and alpha.getbbox()[2]<SIZE
    assert alpha.getbbox()[1]>0 and alpha.getbbox()[3]<SIZE
    assert len({tuple(p) for p in pixels})>COLORS
    assert Image.open(OUT/"palace@2x.png").resize((SIZE,SIZE),Image.Resampling.NEAREST).tobytes()==sprite.tobytes()
    assert high_sprite.size==source.size and high_sprite.mode=="RGBA"
    print("Created high-resolution game texture, pixel sprites, previews, palette, and Pixelorama project in",OUT)
    print("Game texture:",high_sprite.size,"Logical size:",(SIZE,SIZE))
    print("Castle bounds:",alpha.getbbox(),"Ground anchor:",metadata["ground_anchor"])


if __name__=="__main__":
    main()
