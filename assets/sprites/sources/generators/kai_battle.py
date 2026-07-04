"""Kai battle-tier sprite 48x64, GBA-FE register.

Facing 3/4 viewer-RIGHT (shows his left-temple mark). Crimson Emberwing
half-cape billows viewer-left; sword held low across body, blade down-right.
Light source: upper right (the side he faces).
"""
from canvas import Canvas
from spritelib import hx, render, validate_grid, compare_card
import os

PAL = {
    "X": hx("16 0d 12".replace(" ", "")),
    # skin (warm brown)
    "q": hx("6f3b26"), "w": hx("a05f3a"), "e": hx("cf8f5e"),
    # hair (near-black, cool sheen)
    "a": hx("16141f"), "s": hx("252537"), "d": hx("383d56"), "f": hx("525c80"),
    # jacket (academy navy)
    "z": hx("151c2b"), "x": hx("263650"), "c": hx("3d5678"), "v": hx("5c7ba8"),
    # cape (Emberwing crimson)
    "r": hx("4f1216"), "t": hx("8c1f22"), "y": hx("c72929"), "u": hx("e05a41"),
    # gold
    "g": hx("8a5c20"), "h": hx("c1902f"), "j": hx("edc24a"), "J": hx("ffeb9c"),
    # leather
    "k": hx("362112"), "l": hx("5a3c1e"), "m": hx("82602f"),
    # steel
    "n": hx("3d4454"), "b": hx("7e8a9e"), "p": hx("bac6d6"), "P": hx("eef4fa"),
    # trousers
    "1": hx("1d1721"), "2": hx("2d2536"), "3": hx("443b52"),
    # temple mark
    "*": hx("c4d6e2"),
    "W": hx("ffffff"),
    "_": (0, 0, 0, 110),
}


def paint():
    c = Canvas(48, 64)

    # ---------- CAPE (back layer, billows viewer-left) ----------
    # outer silhouette per row: (y, x_left, x_right)
    cape_rows = [
        (20, 14, 19), (21, 13, 19), (22, 11, 18), (23, 10, 18),
        (24, 9, 18), (25, 8, 18), (26, 7, 17), (27, 7, 17),
        (28, 6, 17), (29, 6, 17), (30, 5, 17), (31, 5, 17),
        (32, 5, 17), (33, 4, 17), (34, 4, 17), (35, 4, 17),
        (36, 3, 17), (37, 3, 17), (38, 3, 17), (39, 2, 17),
        (40, 2, 17), (41, 2, 17), (42, 1, 17), (43, 1, 17),
        (44, 1, 17), (45, 1, 17), (46, 2, 16),
    ]
    for y, x0, x1 in cape_rows:
        c.hline(x0, x1, y, "y")
    # cape shoulder attachment (behind torso, both sides)
    c.rows(18, [
        (15, "yyyy"),
        (14, "yyyyy"),
    ])
    # zigzag hem (solid triangular points, flared wide)
    c.rows(47, [
        (2,  "yyyyyyyyyyyyyyy"),
        (2,  "ryyyytyyyytyyy"),
        (3,  "ryyy tyyy tyy"),
        (4,  "ryy   tyy  ty"),
        (5,  "ry     ty"),
    ])
    # fold shading: deep shadow near body (right edge) and under hem
    for y, x0, x1 in cape_rows:
        c.vline(x1, y, y, "r")
        c.px(x1 - 1, y, "t")
    # fold streaks (dark), fanning outward — irregular widths and breaks
    c.line(13, 23, 11, 32, "t"); c.line(11, 33, 9, 46, "t")
    c.line(12, 27, 10, 34, "t")          # doubled fold (wider shadow)
    c.line(9, 28, 7, 36, "t"); c.line(7, 37, 6, 46, "t")
    c.line(15, 24, 14, 32, "t")          # short fold, breaks early
    c.line(14, 40, 13, 46, "t")          # partial fold near hem
    # highlight folds on outer bulge
    c.line(7, 29, 5, 36, "u"); c.line(5, 37, 4, 43, "u")
    c.line(10, 31, 9, 37, "u")
    c.px(3, 40, "u"); c.px(3, 41, "u")
    # hem shade row above zigzag
    c.hline(3, 16, 46, "t")

    # ---------- BACK LEG (viewer-left, planted) ----------
    c.rect(19, 36, 23, 43, "2")
    c.vline(19, 36, 43, "1"); c.vline(20, 36, 43, "1")
    # back boot (dark leather)
    c.rows(44, [(19, "lllll")])  # cuff highlight line
    c.px(21, 44, "h")            # gold cuff tip
    c.rect(19, 45, 23, 52, "k")
    c.vline(22, 45, 52, "l"); c.vline(23, 45, 52, "l")
    # back foot (profile, pointing right, tucked)
    c.rows(53, [
        (17, "kkkkkk"),
        (16, "kkkkkkl"),
        (16, "kkkkkkk"),
    ])

    # ---------- FRONT LEG (viewer-right, stepped out for a wider stance) ----------
    c.rows(36, [(24, "222 "), (24, "2223"), (25, "2233"), (25, "2233")])
    c.rows(40, [(26, "2233"), (26, "2233"), (27, "223"), (27, "223")])
    # front boot (dark leather, lit shin edge)
    c.rows(44, [(27, "mmmm")])   # cuff highlight line
    c.px(29, 44, "j")            # gold cuff tip
    c.rect(27, 45, 30, 52, "k")
    c.vline(29, 45, 52, "l"); c.vline(30, 45, 52, "m")
    # front foot pointing right, solid wedge
    c.rows(53, [
        (27, "kklll"),
        (27, "kkllllm"),
        (27, "kkkllll"),
        (27, "kkkkkkk"),
    ])

    # ---------- TORSO (jacket) ----------
    c.rect(18, 20, 30, 35, "x")
    # sloped shoulder caps (rounded corners)
    c.hline(20, 28, 19, "x")
    c.px(19, 20, "z"); c.px(18, 20, "."); c.px(30, 20, "v")
    # shading: back (left) darker, front (right) lit
    c.vline(18, 21, 35, "z"); c.vline(19, 21, 35, "z"); c.vline(20, 21, 35, "z")
    c.vline(27, 20, 33, "c"); c.vline(28, 20, 33, "c"); c.vline(29, 19, 33, "c")
    c.vline(30, 21, 33, "v")
    # garment fold modeling: thin shadow ticks, lit chest patch
    c.px(22, 26, "z"); c.px(23, 27, "z")
    c.rows(21, [(28, "vc"), (28, "cv")])
    c.px(24, 24, "z"); c.px(23, 30, "z")
    # gold front placket trim (thin line down chest)
    c.vline(27, 20, 32, "h")
    c.px(27, 21, "j"); c.px(27, 25, "j"); c.px(27, 29, "j")
    # gold buttons left of placket
    c.px(25, 22, "j"); c.px(25, 26, "j"); c.px(25, 30, "j")
    # shoulder seam highlight (lit side only)
    c.px(29, 19, "v")
    # cape chest-strap with gold clasp
    c.hline(22, 26, 20, "t")
    c.px(24, 20, "j"); c.px(25, 20, "J")
    # chest-out / waist-in curve on the lit side
    c.vline(31, 21, 24, "v")
    c.px(31, 20, "c")
    # belt
    c.rect(19, 33, 30, 34, "l")
    c.hline(19, 30, 33, "k")
    c.rows(33, [(23, "gj")]); c.rows(34, [(23, "jJ")])  # buckle

    # ---------- LEFT ARM (near side, hand at hip) ----------
    c.rect(17, 21, 19, 27, "x")
    c.vline(17, 21, 27, "z")
    c.rect(18, 28, 20, 31, "x")
    c.vline(18, 28, 31, "z")
    c.rows(31, [(19, "tt")])  # crimson cuff trim
    # glove hand at hip
    c.rows(32, [
        (19, "lm"),
        (19, "mm"),
        (19, "kl"),
    ])

    # ---------- SWORD ARM + HILT (one explicit patch, x28-37 / y17-25) ----------
    # sleeve rises from the far shoulder; gloved fist wraps the grip;
    # gold crossguard perpendicular to the blade; pommel below the fist.
    # crossguard (gold diagonal bar, 2px thick)
    c.px(33, 18, "j"); c.px(34, 18, "h")
    c.px(34, 19, "j"); c.px(35, 19, "h")
    c.px(35, 20, "g")
    # grip + pommel
    c.px(33, 20, "k"); c.px(31, 23, "h")
    # gloved fist wrapping the grip
    c.rows(20, [
        (31, "mm"),
        (30, "lmm"),
        (30, "lm"),
    ])
    # sleeve (short, nearly horizontal to the raised fist), crimson cuff at wrist
    c.px(29, 20, "c")
    c.rows(21, [(28, "xcy"), (28, "xcy")])
    c.px(29, 23, "x"); c.px(30, 23, "x")
    # blade: two-px wide diagonal from (35,19) to (46,7)
    c.line(35, 18, 45, 8, "b")
    c.line(36, 19, 46, 9, "p")
    c.px(46, 8, "P"); c.px(47, 8, "P")
    # glints along the lit edge
    c.px(38, 16, "P"); c.px(39, 15, "P")
    c.px(43, 11, "P")

    # ---------- HEAD (hand-drawn patch, x18-31 / y2-16, 3/4 facing right) ----------
    # neck
    c.rows(16, [(25, "qqw"), (25, "qq")])
    # collar (crimson band)
    c.rows(17, [(22, " tyy t")])
    c.rows(18, [(21, "tyyyyt")])
    # one explicit grid, origin x19/y1. hair a/s/d/f, skin q/w/e, mark *.
    # fringe = pointed locks at varying depths; near eye X pupil + W glint;
    # mark = silver diagonal (29,8)-(30,9) on the temple skin.
    c.rows(1, [
        (19, "....s...d"),       # y1  crown spike tips
        (19, "..sssdfds"),       # y2  lock tip catches light
        (19, ".ssdsdffds"),      # y3  's' seams carve lock clusters
        (19, "ssdfsdfffds"),     # y4
        (19, "asdffsdfffds"),    # y5  sheen toward the light
        (19, "assddsddsdfs"),    # y6  skull widest, lock seams
        (19, "assdsdddsdss"),    # y7  fringe root
        (19, "sssseesdes*e"),    # y8  locks over forehead + mark
        (19, "assseaseaae*"),    # y9  lock tips, brows, mark
        (19, ".asweXeeXWee"),    # y10 eye row
        (19, "..sweweeXeeee"),   # y11 pupil bottom, nose bump x31
        (19, "..sqweeeeeeee"),   # y12 cheek, nose tip x31
        (19, "....qwweeeeq"),    # y13 under-nose shadow
        (19, ".....qwweqe"),     # y14 mouth (q at x27)
        (19, "......qwee"),      # y15 chin
    ])
    # rim light along the lit (right) hair silhouette
    c.px(28, 3, "f"); c.px(29, 4, "f"); c.px(30, 6, "f")

    # ---------- OUTLINE + GROUND SHADOW ----------
    c.outline_sprite("X")
    # ground shadow ellipse — only where transparent (never over feet)
    for y, x0, x1 in ((56, 15, 36), (57, 13, 38), (58, 16, 35)):
        for x in range(x0, x1 + 1):
            if c.get(x, y) == ".":
                c.px(x, y, "_")
    return c


if __name__ == "__main__":
    c = paint()
    g = c.grid()
    validate_grid(g, 48)
    out = os.path.dirname(os.path.abspath(__file__))
    render(g, PAL, os.path.join(out, "kai_battle_1x.png"), scale=8,
           path_big=os.path.join(out, "kai_battle_8x.png"))
    compare_card(
        [("sample", os.path.join(out, "study/lucina_big.png")),
         ("kai", os.path.join(out, "kai_battle_1x.png"))],
        os.path.join(out, "kai_vs_sample.png"))
    print("rendered")
