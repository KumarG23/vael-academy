from PIL import Image

img = Image.open('assets/sprites/sources/generators/kai_battle_1x.png').convert('RGBA')
colors = set()
for y in range(img.height):
    for x in range(img.width):
        r, g, b, a = img.getpixel((x,y))
        if a > 0:
            colors.add((r, g, b))

print("Unique colors:", len(colors))
for c in colors:
    print(c)
