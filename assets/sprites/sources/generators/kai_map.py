"""Kai map chibi 32x32, 4-frame side walk (faces right; engine flips for left).

GBA lord map-sprite register: big head, readable face, crimson mini-cape,
chunky legs. f1/f3 = stride poses, f2/f4 = passing poses (idle bob pair).
"""
from canvas import Canvas
from spritelib import render, validate_grid
from kai_battle import PAL
from PIL import Image
import os

OUT = os.path.dirname(os.path.abspath(__file__))


def head(c, oy):
    # skull x10-21, crown y3, chin y13 (all +oy); facing 3/4 right.
    # Face mostly light 'e'; single shade column at the back; simple 1x2 eyes.
    c.rows(3 + oy, [
        (12, ".ss.d"),         # y3  spike tips
        (11, "ssssdds"),       # y4
        (10, "ssdddffds"),     # y5
        (10, "asddfffffds"),   # y6
        (10, "assdddddddss"),  # y7  skull widest
        (10, "asssdeesdese"),  # y8  fringe locks over forehead
        (10, "asswea*eaaee"),  # y9  lock tips + brows + mark
        (10, ".aswe Xee Xe"),  # y10 eye row (pupils painted below)
        (10, ".asweXeeeXee"),  # y11 pupil bottom, nose bump x21
        (10, "..sqweeeeeee"),  # y12 cheek
        (10, "...sqwweeeq"),   # y13 jaw + chin
    ])
    c.px(21, 11 + oy, "e")     # nose bump on silhouette
    c.px(15, 10 + oy, "X"); c.px(19, 10 + oy, "X")  # pupils (fill row gaps)


def cape(c, oy, sway):
    # crimson cape hung from the shoulders, trailing behind (left)
    x0 = 8 - sway
    c.rows(14 + oy, [
        (10, "tyy"),
        (9,  "yyyy"),
        (x0, "tyyyy"),
        (x0, "tyyy"),
        (x0, "ryyy"),
        (x0, "ryyt"),
        (x0 + 1, "ry t"),
    ])


def torso(c, oy, swing):
    """swing: -1 back arm forward, +1 front arm forward, 0 neutral."""
    # collar (crimson) + jacket block x12-19, y14-20
    c.rows(14 + oy, [(14, "tyyt")])
    c.rect(12, 15 + oy, 19, 20 + oy, "x")
    c.vline(12, 15 + oy, 20 + oy, "z"); c.vline(13, 15 + oy, 20 + oy, "z")
    c.vline(18, 15 + oy, 20 + oy, "c"); c.vline(19, 15 + oy, 20 + oy, "v")
    # gold placket
    c.vline(17, 15 + oy, 19 + oy, "h")
    # belt + buckle
    c.hline(12, 19, 20 + oy, "k")
    c.px(16, 20 + oy, "j")
    # arms: small sleeves + glove nubs
    bx = 12 + (1 if swing > 0 else 0)          # back arm
    fx = 19 - (1 if swing < 0 else 0)          # front arm
    c.vline(bx, 16 + oy, 18 + oy, "z")
    c.px(bx, 19 + oy, "l")
    c.vline(fx, 16 + oy, 18 + oy, "c")
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


def frame(pose, sway=0):
    c = Canvas(32, 32)
    if pose == "contact_a":
        oy = 0
        cape(c, oy, 0)
        legs_contact(c, False)
        torso(c, oy, +1)
        head(c, oy)
    elif pose == "contact_b":
        oy = 0
        cape(c, oy, 1)
        legs_contact(c, True)
        torso(c, oy, -1)
        head(c, oy)
    else:  # passing: body rides 1px down (weight over the planted leg)
        oy = 1
        cape(c, oy, sway)
        legs_passing(c)
        torso(c, oy, 0)
        head(c, oy)
    c.outline_sprite("X")
    return c


if __name__ == "__main__":
    poses = [("f1", "contact_a", 0), ("f2", "pass", 0),
             ("f3", "contact_b", 0), ("f4", "pass", 1)]
    imgs = []
    for name, pose, sway in poses:
        c = frame(pose, sway)
        g = c.grid()
        validate_grid(g, 32)
        p = os.path.join(OUT, f"kai_map_{name}.png")
        img = render(g, PAL, p)
        imgs.append(img)
    # preview strip at 8x
    strip = Image.new("RGBA", (32 * 8 * 4 + 50, 32 * 8 + 20), (26, 26, 26, 255))
    for i, im in enumerate(imgs):
        big = im.resize((256, 256), Image.NEAREST)
        strip.alpha_composite(big, (10 + i * 266, 10))
    strip.save(os.path.join(OUT, "kai_map_strip.png"))
    # animated gif preview at 6x
    gif = [im.resize((192, 192), Image.NEAREST).convert("RGBA") for im in imgs]
    bg = [Image.new("RGBA", g.size, (40, 44, 40, 255)) for g in gif]
    for b, g in zip(bg, gif):
        b.alpha_composite(g)
    bg[0].save(os.path.join(OUT, "kai_map_walk.gif"), save_all=True,
               append_images=bg[1:], duration=125, loop=0)
    print("rendered map frames")
