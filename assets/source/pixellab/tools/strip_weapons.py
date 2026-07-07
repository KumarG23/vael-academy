"""Strip the baked-in weapon from a unit's combat map sprite -> body_map.png,
so the on-map CombatRig can overlay a swappable weapon without doubling.
Per-unit config: a weapon region box + a color mode. Metal removes gray/
silver/blue blades & hafts; book removes a warm tome; wood removes a staff shaft.
Rough is fine for the combat body — the swung weapon overlay covers the hand."""
from PIL import Image
import sys, os
ROOT = "/Users/nealsharma/code/Vael Academy"

def is_metal(r,g,b):
    grayish = abs(r-g) < 46 and abs(g-b) < 58 and max(r,g,b) > 82
    bluegray = b > r + 12 and b > 92 and g > r - 10
    warm_skin = r > 150 and r > g + 28 and g > b
    return (grayish or bluegray) and not warm_skin

def is_book(r,g,b):   # warm tome: orange / red / gold pages+cover
    return r > 108 and r > b + 34 and g < r + 6 and not (r>150 and g>120 and b<90 and abs(r-g)<40)

def is_wood(r,g,b):   # staff shaft / haft: mid brown
    return 70 < r < 175 and r > g > b and r - b > 24 and abs(r-g) < 55

TESTS = {"metal": is_metal, "book": is_book, "wood": is_wood, "any": lambda r,g,b: True}

# unit -> list of (x0,y0,x1,y1, mode)
CONFIG = {
    "dain":   [(1,4,14,18,"any"),(12,10,20,21,"metal")],       # axe head (isolated) + haft
    # kael: no baked weapon in the map sprite (navy coat only) — no strip.
    # wren: no separable baked weapon — the cream mass is his hood, not a staff.
    "liora":  [(22,14,31,29,"any"),(15,15,24,27,"book")],      # tome body (isolated) + inner pages
    "brenna": [(16,1,31,31,"metal")],                          # blue-gray lance (armor is red)
    "perrin": [(16,6,31,31,"metal")],                          # white lance (armor is dark)
}

def strip(unit):
    p = f"{ROOT}/assets/sprites/units/{unit}/walk_f1.png"
    im = Image.open(p).convert("RGBA"); px = im.load(); W,H = im.size
    out = im.copy(); op = out.load()
    removed = 0
    for (x0,y0,x1,y1,mode) in CONFIG[unit]:
        test = TESTS[mode]
        for y in range(max(0,y0), min(H,y1)):
            for x in range(max(0,x0), min(W,x1)):
                r,g,bl,a = px[x,y]
                if a < 20: continue
                # protect a strong red cape only when pulling gray metal off it;
                # book/any modes intentionally target warm colors, so skip the guard
                if mode == "metal" and r > 120 and r > g + 55 and r > bl + 45: continue
                if test(r,g,bl):
                    op[x,y] = (0,0,0,0); removed += 1
    os.makedirs(f"{ROOT}/assets/art/cutout/{unit}", exist_ok=True)
    out.save(f"{ROOT}/assets/art/cutout/{unit}/body_map.png")
    return im, out, removed

if __name__ == "__main__":
    units = sys.argv[1:] or list(CONFIG)
    S = 8; pad = 12
    sheet = Image.new("RGBA", (len(units)*(32*S+pad)+pad, 2*(32*S)+50), (28,30,38,255))
    from PIL import ImageDraw
    d = ImageDraw.Draw(sheet)
    for i,u in enumerate(units):
        before, after, n = strip(u)
        x = pad + i*(32*S+pad)
        sheet.alpha_composite(before.resize((32*S,32*S),Image.NEAREST),(x,20))
        sheet.alpha_composite(after.resize((32*S,32*S),Image.NEAREST),(x,32*S+40))
        d.text((x,4),f"{u}  (-{n})",fill=(255,230,150))
        print(f"{u}: removed {n} px -> body_map.png")
    d.text((pad,20+32*S+8),"^ before   /   after v",fill=(150,155,170))
    sheet.convert("RGB").save(f"{ROOT}/assets/art_review/debug/strip_check.png")
    print("verification -> assets/art_review/debug/strip_check.png")
