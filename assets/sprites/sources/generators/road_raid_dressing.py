#!/usr/bin/env python3
"""VS-1B.5 native pixel dressing derived from existing prop palette; Pillow.
No random/game state. Cosmetic dust/rubble adds neither hazards nor collision.
"""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/art/pixellab/props/road_raid'
SOURCE = ROOT / 'assets/source/vs1b5_raid_art'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ground = Image.new('RGBA', (512, 352))
    d = ImageDraw.Draw(ground)
    chapter = (ROOT / 'data/chapters/prologue.tres').read_text()
    terrain = list(map(int, re.search(r'terrain = PackedInt32Array\(([^)]*)\)', chapter)[1].split(',')))
    for y in range(352):
        for x in range(512):
            if terrain[(y//32)*16+x//32] not in (0, 12):
                continue
            west = ((x-110)/110)**2 + ((y-143)/119)**2
            east = ((x-386)/79)**2 + ((y-225)/80)**2
            dist = min(west, east)
            if dist < 1:
                cluster = ((x//3)*73856093 ^ (y//2)*19349663) & 255
                d.point((x,y), fill=(157+cluster%9,128+cluster%7,79+cluster%5,
                                    int((205+cluster%35)*(1-dist)**0.22)))
    for cx,cy,rx,ry in [(374,247,35,12),(16,92,19,9),(495,312,22,10)]:
        for y in range(cy-ry,cy+ry+1):
            for x in range(max(0,cx-rx),min(512,cx+rx+1)):
                if terrain[(y//32)*16+x//32] in (0,12,2) and ((x-cx)/rx)**2+((y-cy)/ry)**2<1:
                    d.point((x,y),fill=(57,50,57,130 if (x+y)%3 else 95))
    for x,y in [(97,133),(159,98),(199,117),(239,104),(347,246),(408,249),(60,249)]:
        d.line((x-8,y,x+6,y-3),fill='#513c38',width=2)
        d.line((x-6,y-1,x+5,y-4),fill='#bb8050',width=1)
        for dx,dy in [(8,4),(11,1),(-8,5)]:
            d.rectangle((x+dx,y+dy,x+dx+1,y+dy+1),fill='#d1af70')
        for dx,dy in [(4,5),(9,8),(15,6)]:
            d.rectangle((x+dx,y+dy,x+dx+2,y+dy+1),fill='#a24b35')
    ground.save(OUT / 'square_ground.png')
    # PixelLab source kept immutable; native cleanup adds the broken wheel and
    # scattered load that the generated empty cart omitted. No soft scaling.
    im = Image.open(ROOT/'assets/source/pixellab/vs1b5_cart/cart_original.png').convert('RGBA')
    d=ImageDraw.Draw(im)
    d.ellipse((44,34,57,42),fill='#513c38',outline='#bb8050',width=2)
    d.line((45,38,56,38),fill='#805137');d.line((50,35,50,41),fill='#805137')
    d.line((4,43,25,40),fill='#513c38',width=2)
    for i in range(26):
        d.point((14+(i*7)%22,42+(i*3)%6),fill='#d1af70')
    for x,y in [(37,39),(42,43),(53,45)]:
        d.rectangle((x,y,x+2,y+1),fill='#a24b35')
    im.save(OUT/'cart_overturned.png')
    stall=Image.open(ROOT/'assets/art/pixellab/props/market_stall.png').convert('RGBA')
    px=stall.load()
    for y in range(stall.height):
        for x in range(stall.width):
            r,g,b,a=px[x,y]
            if a and r>g*1.2:
                px[x,y]=(int(r*.78),int(g*.78),int(b*.78),a)
    ImageDraw.Draw(stall).polygon([(23,20),(28,20),(26,27)],fill=(0,0,0,0))
    stall.save(OUT/'stall_damaged.png')
    house=Image.open(ROOT/'assets/art/pixellab/props/house_b.png').convert('RGBA')
    px=house.load()
    for y in range(house.height):
        for x in range(house.width):
            r,g,b,a=px[x,y]
            if a and y<38 and x>18:
                lum=(r+g+b)//3
                px[x,y]=(int(lum*.57),int(lum*.51),int(lum*.49),a)
    house.save(OUT/'house_scorched.png')
    report={p.name:{'size':Image.open(p).size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
                    'rgba_colors':len(Image.open(p).getcolors(1000000))} for p in OUT.glob('*.png')}
    (SOURCE/'pixel-dressing-qa.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Built', len(report), 'repeatable native pixel dressing assets')

if __name__=='__main__':main()
