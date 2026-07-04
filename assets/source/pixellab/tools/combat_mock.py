"""FE-style combat pop-up mock GIF: Kai's PixelLab attack animation vs a
sparring dummy on a simple arena backdrop with HP-bar chrome.
Pure mock — sells the battle-scene vision, no engine code."""
from PIL import Image, ImageDraw
import glob
import os

ART = "/Users/nealsharma/code/Vael Academy/assets/art/pixellab/kai"
S = 5           # sprite scale
W, H = 480, 270  # GBA-ish 16:9 stage


def backdrop():
    bg = Image.new("RGBA", (W, H), (23, 20, 26, 255))
    d = ImageDraw.Draw(bg)
    # sky gradient band
    for y in range(0, 150):
        t = y / 150
        d.line([(0, y), (W, y)], fill=(int(30+18*t), int(26+10*t), int(38+8*t)))
    # ground
    for y in range(150, H):
        t = (y - 150) / (H - 150)
        d.line([(0, y), (W, y)], fill=(int(44-10*t), int(52-14*t), int(34-8*t)))
    d.line([(0, 150), (W, 150)], fill=(70, 80, 52), width=2)
    return bg


def chrome(d):
    # bottom HP panels, FE style
    for x0, name, hp in ((16, "KAI", 24), (W//2 + 16, "DUMMY", 17)):
        d.rounded_rectangle([x0, H-58, x0 + W//2 - 32, H-14], 6,
                            fill=(18, 16, 22, 235), outline=(237, 194, 74), width=2)
        d.text((x0 + 12, H-52), name, fill=(233, 227, 215))
        # hp pips
        for i in range(28):
            c = (199, 41, 41) if i < hp else (60, 54, 66)
            d.rectangle([x0 + 12 + i*7, H-32, x0 + 16 + i*7, H-24], fill=c)


def build():
    attack = [Image.open(f).convert("RGBA")
              for f in sorted(glob.glob(f"{ART}/attack_east/attack_f*.png"))]
    east = Image.open("/Users/nealsharma/code/Vael Academy/assets/source/pixellab/"
                      "kai_map_v1/unpacked/Kai_Emberwing/rotations/east.png").convert("RGBA")
    east = east.crop(east.getbbox())
    pad = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    pad.alpha_composite(east, ((32 - east.size[0]) // 2, 32 - east.size[1] - 1))
    # dummy = west-facing Kai silhouette, dark-tinted (sparring partner)
    dummy = pad.transpose(Image.FLIP_LEFT_RIGHT)
    px = dummy.load()
    for y in range(dummy.size[1]):
        for x in range(dummy.size[0]):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r*0.45), int(g*0.5), int(b*0.62), a)

    frames = []
    ground_y = 190
    # hold on the ready pose a beat, play attack, hold end
    seq = [attack[0]]*3 + attack + [attack[-1]]*3
    lunge = {len(attack)//2 + 3: 10, len(attack)//2 + 4: 14}  # step-in on the slash
    hit_at = 3 + 5  # around the slash frame
    for i, spr in enumerate(seq):
        f = backdrop()
        d = ImageDraw.Draw(f)
        dx = lunge.get(i, 0)
        big = spr.resize((32*S, 32*S), Image.NEAREST)
        f.alpha_composite(big, (70 + dx*S//2, ground_y - 32*S + 40))
        dm = dummy.resize((32*S, 32*S), Image.NEAREST)
        # flinch shake when the slash lands
        shake = 6 if i in (hit_at, hit_at+1) else 0
        f.alpha_composite(dm, (300 + shake, ground_y - 32*S + 40))
        if i in (hit_at, hit_at+1):
            # impact flash
            d.polygon([(330, 120), (352, 96), (346, 128), (372, 118),
                       (344, 140), (352, 164), (330, 142), (308, 152),
                       (320, 130), (304, 112)], fill=(255, 244, 200, 230))
        chrome(d)
        frames.append(f.convert("RGB"))
    out = f"{ART}/combat_popup_mock.gif"
    frames[0].save(out, save_all=True, append_images=frames[1:],
                   duration=110, loop=0)
    print("combat mock:", out, len(frames), "frames")


if __name__ == "__main__":
    build()
