# Делает иконку незаточенного меча из иконки меча (#42): голубой блестящий клинок
# перекрашивается в тусклый серый, рукоять и гарда не меняются.
# Из корня репозитория: python sandbox/layers-2d/source/make_blunt_sword.py <меч.png> <незаточенный.png>
import sys

from PIL import Image

# Цвета клинка в иконке W_Sword001 → тусклые серые.
BLADE_COLORS = {
    (255, 255, 255): (170, 168, 176),
    (176, 222, 240): (138, 136, 146),
    (129, 174, 209): (112, 110, 122),
    (94, 138, 190): (88, 86, 98),
}

image = Image.open(sys.argv[1]).convert("RGBA")
pixels = image.load()
for y in range(image.height):
    for x in range(image.width):
        red, green, blue, alpha = pixels[x, y]
        if (red, green, blue) in BLADE_COLORS:
            pixels[x, y] = BLADE_COLORS[(red, green, blue)] + (alpha,)
image.save(sys.argv[2])
