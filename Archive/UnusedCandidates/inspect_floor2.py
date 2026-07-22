import os
from PIL import Image

base = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(base, "kenney_roguelike", "Spritesheet", "roguelikeDungeon_transparent.png")
img = Image.open(src).convert("RGBA")

def get(c, r):
    return img.crop((c*17, r*17, c*17+16, r*17+16))

# scan rows 8..17, columns 8..20 (floor area) scaled 3x
rows = list(range(8, 18))
cols = list(range(8, 21))
scale = 3
out = Image.new("RGBA", (len(cols)*16*scale, len(rows)*16*scale))
for ry, r in enumerate(rows):
    for cx, c in enumerate(cols):
        t = get(c, r).resize((16*scale, 16*scale), Image.NEAREST)
        out.paste(t, (cx*16*scale, ry*16*scale))
out.save(os.path.join(base, "floor_grid.png"))
print("saved floor_grid.png")
