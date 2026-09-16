"""Pack the additional wizard performance without changing any base unit atlas."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from finish_characters import ROOT, pack

entry,images,report=pack('wizard',Path('/tmp/sovereign-casting-renders'),'wizard_cast')
(ROOT/'godot/data/casting.json').write_text(json.dumps(entry,separators=(',',':'))+'\n')
(ROOT/'assets/art/units/directional/wizard_cast.json').write_text(json.dumps(entry,indent=2)+'\n')
font=ImageFont.truetype(str(ROOT/'godot/assets/cinzel.ttf'),24)
boards=[]
for pose in range(16):
    board=Image.new('RGB',(1280,440),'#202925'); d=ImageDraw.Draw(board)
    d.text((30,22),'SOVEREIGN / THE ART OF SPELLCASTING',font=font,fill='#ddc58e')
    for direction in range(8):
        f=entry['frames'][pose*8+direction]; tile=images[pose*8+direction]
        scale=2.8/entry['density']; tile=tile.resize((round(tile.width*scale),round(tile.height*scale)),Image.Resampling.LANCZOS)
        at=(80+direction*160-round(f['anchor'][0]*2.8),350-round(f['anchor'][1]*2.8))
        board.paste(tile,at,tile)
        d.text((65+direction*160,392),entry['directions'][direction],font=font,fill='#ddc58e')
    boards.append(board)
boards[0].save(ROOT/'godot/reports/arcane-casting.webp',save_all=True,append_images=boards[1:],duration=80,loop=0,quality=90,method=6)
(ROOT/'godot/reports/arcane-art.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
