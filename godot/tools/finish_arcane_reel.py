"""Assemble browser-captured frames; no effect animation is synthesized here."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'godot/reports'
SOURCE=Path('/tmp/sovereign-arcane-reel')
frames=json.loads((SOURCE/'frames.json').read_text())
names={'heal':'HEALING LIGHT','lightning':'LIGHTNING BOLT','frost':'FROST NOVA','meteor':'METEOR','ward':'ARCANE WARD','farsight':'FAR SIGHT'}
font=ImageFont.truetype(str(ROOT/'godot/assets/cinzel.ttf'),20)
small=ImageFont.truetype(str(ROOT/'godot/assets/alegreya.ttf'),17)
reel=[]
for record in frames:
    board=Image.new('RGB',(990,608),'#202925'); draw=ImageDraw.Draw(board)
    draw.text((18,11),'SOVEREIGN',font=font,fill='#e0c890')
    draw.text((970,12),names[record['spell']],font=font,fill='#e0c890',anchor='ra')
    draw.line((16,43,974,43),fill='#76643e')
    board.paste(Image.open(SOURCE/record['file']),(0,48)); reel.append(board)
reel[0].save(OUT/'arcane-reel.webp',save_all=True,append_images=reel[1:],duration=50,loop=0,quality=82,method=4,minimize_size=True)
board=Image.new('RGB',(1040,1070),'#202925'); draw=ImageDraw.Draw(board)
draw.text((24,20),'SOVEREIGN / THE ART OF SPELLCASTING',font=font,fill='#e0c890')
for index,(key,frame) in enumerate([('heal',7),('lightning',2),('frost',6),('meteor',15),('ward',7),('farsight',9)]):
    tile=Image.open(SOURCE/f'{key}-{frame:03d}.png').resize((495,280),Image.Resampling.LANCZOS)
    x=16+(index%2)*514; y=70+(index//2)*325
    board.paste(tile,(x,y)); draw.text((x+4,y+286),names[key],font=small,fill='#dfc897')
board.save(OUT/'arcane-showcase.png',optimize=True)
print(f'Assembled {len(reel)} actual game frames into {OUT / "arcane-reel.webp"}')
print(f'Animation size: {(OUT / "arcane-reel.webp").stat().st_size/1e6:.2f} MB')
