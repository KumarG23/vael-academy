"""Kai map chibi 32x32, 4-frame side walk (faces right; engine flips for left).

GBA lord map-sprite register: big head, readable face, crimson mini-cape,
chunky legs. f1/f3 = stride poses, f2/f4 = passing poses (idle bob pair).
"""
from canvas import Canvas
from spritelib import render, validate_grid
from kai_battle import PAL, hx
from PIL import Image
import os

OUT = os.path.dirname(os.path.abspath(__file__))

# gatherer olive-wool ramp (his pre-academy clothes)
PAL = dict(PAL)
PAL["5"] = hx("232f1c"); PAL["6"] = hx("3a5030"); PAL["7"] = hx("567544")

# outfit definitions: what the torso block is made of and which extras render
OUTFITS = {
    # academy battle kit: navy jacket, crimson cape + headband, sword on back
    "battle": dict(jacket=("z", "x", "c", "v"), trim="h", collar="tyyt",
                   cape=True, band=True, sword=True, satchel=False),
    # school uniform: same navy jacket, neat crimson collar, no field gear
    "school": dict(jacket=("z", "x", "c", "v"), trim="h", collar="tyyt",
                   cape=False, band=False, sword=False, satchel=False),
    # gatherer clothes: olive wool tunic, leather satchel, no uniform trim
    "gather": dict(jacket=("5", "6", "6", "7"), trim=None, collar=None,
                   cape=False, band=False, sword=False, satchel=True),
}


def head(c, oy, band=True):
    # skull x10-21, crown y3, chin y13 (all +oy); facing 3/4 right.
    # Battle kit: crimson headband welds hair to face (matches the battle
    # tier). Without the band, a fringe row with a lock tip does the welding.
    brow = "astyyyyyyts" if band else "assdddfddds"
    fore = "asswqeeee*e" if band else "asswseeee*e"
    c.rows(3 + oy, [
        (12, ".ss.d"),         # y3  spike tips
        (11, "ssssdds"),       # y4
        (10, "ssdddffds"),     # y5  dome
        (10, "asddddfffds"),   # y6  dome, sheen toward the light
        (10, brow),            # y7  band or fringe
        (10, fore),            # y8  skin under it + temple mark
        (10, ".asqeXeeXee"),   # y9  eye row, 2px-tall pupils (x15, x18)
        (10, ".asqwXeeXee"),   # y10 pupil bottoms
        (10, "..sqweeeeee"),   # y11 cheek
        (10, "...sqwweeqe"),   # y12 mouth (q x18) + chin
        (10, "....qwwee"),     # y13 jaw
    ])
    c.px(20, 10 + oy, "e")     # nose bump on silhouette (1px)


def cape(c, oy, sway, sword=True):
    # crimson cape hung from the shoulders, trailing behind (left)
    x0 = 8 - sway
    c.rows(14 + oy, [
        (10, "tyy"),
        (9,  "yyyy"),
        (x0, "tyyyy"),
        (x0, "ttyyy"),
        (x0, "rtyy"),
        (x0, "ryyt"),
        (x0 + 1, "ry t"),
    ])
    if sword:
        # sword worn on the back: grip + gold pommel above the back shoulder
        c.px(10, 12 + oy, "k"); c.px(9, 11 + oy, "k")
        c.px(8, 10 + oy, "h")


def torso(c, oy, swing, o):
    """swing: -1 back arm forward, +1 front arm forward, 0 neutral.
    o: outfit dict (see OUTFITS)."""
    dk, md, lt, rim = o["jacket"]
    if o["collar"]:
        c.rows(14 + oy, [(14, o["collar"])])
    c.rect(12, 15 + oy, 19, 20 + oy, md)
    c.vline(12, 15 + oy, 20 + oy, dk); c.vline(13, 15 + oy, 20 + oy, dk)
    c.vline(18, 15 + oy, 20 + oy, lt); c.vline(19, 15 + oy, 20 + oy, rim)
    if o["trim"]:
        c.vline(17, 15 + oy, 19 + oy, o["trim"])
    # belt + buckle
    c.hline(12, 19, 20 + oy, "k")
    c.px(16, 20 + oy, "j")
    if o["satchel"]:
        # leather strap across the chest + pouch at the back hip
        c.line(13, 15 + oy, 18, 19 + oy, "k")
        c.rows(19 + oy, [(10, "lm"), (10, "kl")])
    # arms: small sleeves + glove nubs
    bx = 12 + (1 if swing > 0 else 0)          # back arm
    fx = 19 - (1 if swing < 0 else 0)          # front arm
    c.vline(bx, 16 + oy, 18 + oy, dk)
    c.px(bx, 19 + oy, "l")
    c.vline(fx, 16 + oy, 18 + oy, lt)
    c.px(fx, 19 + oy, "m")


def legs_contact(c, mirror):
    """Stride pose, feet on ground row y27. Chunky 2px boots.
    mirror=False: NEAR leg forward (lit). mirror=True: FAR leg forward
    (shaded darker), near leg trailing — the opposite contact pose."""
    if not mirror:
        # far leg trailing (dark)
        c.rows(21, [
            (14, "11"), (13, "11"),
            (13, "kk"), (12, "kk"), (12, "kk"),
            (11, "kk"),
            (11, "kkk"),
        ])
        # near leg forward (lit)
        c.rows(21, [
            (16, "22"), (17, "22"),
            (17, "kl"), (17, "kl"), (18, "kl"),
            (18, "klm"),
            (18, "kkk"),
        ])
    else:
        # far leg forward (dark)
        c.rows(21, [
            (15, "11"), (16, "11"),
            (16, "kk"), (17, "kk"), (17, "kk"),
            (17, "kk"),
            (17, "kkk"),
        ])
        # near leg trailing (lit)
        c.rows(21, [
            (14, "22"), (13, "22"),
            (13, "kl"), (12, "kl"), (12, "kl"),
            (11, "kl"),
            (11, "kkl"),
        ])


def legs_passing(c):
    """Legs together under the body: near leg full, far leg a dark sliver."""
    c.rows(22, [
        (14, "222"),
        (15, "22"),
        (15, "kl"),
        (15, "kl"),
        (15, "kl"),
        (15, "klm"),
        (15, "kkk"),
    ])
    # far leg sliver behind
    c.vline(14, 24, 27, "k")
    c.px(13, 27, "k")


def frame(pose, sway=0, outfit="battle"):
    o = OUTFITS[outfit]
    c = Canvas(32, 32)
    if pose == "contact_a":
        oy = 0
        if o["cape"]:
            cape(c, oy, 0, o["sword"])
        legs_contact(c, False)
        torso(c, oy, +1, o)
        head(c, oy, o["band"])
    elif pose == "contact_b":
        oy = 0
        if o["cape"]:
            cape(c, oy, 1, o["sword"])
        legs_contact(c, True)
        torso(c, oy, -1, o)
        head(c, oy, o["band"])
    else:  # passing: body rides 1px down (weight over the planted leg)
        oy = 1
        if o["cape"]:
            cape(c, oy, sway, o["sword"])
        legs_passing(c)
        torso(c, oy, 0, o)
        head(c, oy, o["band"])
    c.outline_sprite("X")
    return c


if __name__ == "__main__":
    poses = [("f1", "contact_a", 0), ("f2", "pass", 0),
             ("f3", "contact_b", 0), ("f4", "pass", 1)]
    all_first = []
    for outfit in OUTFITS:
        imgs = []
        for name, pose, sway in poses:
            c = frame(pose, sway, outfit)
            g = c.grid()
            validate_grid(g, 32)
            img = render(g, PAL, os.path.join(OUT, f"kai_map_{outfit}_{name}.png"))
            if outfit == "battle":
                img.save(os.path.join(OUT, f"kai_map_{name}.png"))  # engine names
            imgs.append(img)
        all_first.append(imgs[0])
        strip = Image.new("RGBA", (32*8*4 + 50, 32*8 + 20), (26, 26, 26, 255))
        for i, im in enumerate(imgs):
            strip.alpha_composite(im.resize((256, 256), Image.NEAREST), (10 + i*266, 10))
        strip.save(os.path.join(OUT, f"kai_map_{outfit}_strip.png"))
        gif = [im.resize((192, 192), Image.NEAREST).convert("RGBA") for im in imgs]
        bg = [Image.new("RGBA", g.size, (40, 44, 40, 255)) for g in gif]
        for b, g in zip(bg, gif):
            b.alpha_composite(g)
        bg[0].save(os.path.join(OUT, f"kai_map_{outfit}_walk.gif"), save_all=True,
                   append_images=bg[1:], duration=125, loop=0)
    # variant lineup card
    card = Image.new("RGBA", (32*8*3 + 40, 32*8 + 20), (26, 26, 26, 255))
    for i, im in enumerate(all_first):
        card.alpha_composite(im.resize((256, 256), Image.NEAREST), (10 + i*266, 10))
    card.save(os.path.join(OUT, "kai_map_variants.png"))
    print("rendered map frames for outfits:", ", ".join(OUTFITS))
