import os
from PIL import Image

base = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(base, "kenney_roguelike", "Spritesheet", "roguelikeDungeon_transparent.png")
img = Image.open(src).convert("RGBA")

def get(c, r):
    return img.crop((c*17, r*17, c*17+16, r*17+16))

coords = [(18,8),(19,8),(20,8),(18,9),(19,9),(20,9),(8,8),(9,8),(13,8)]
out = Image.new("RGBA", (16*len(coords), 16))
for i, (c, r) in enumerate(coords):
    out.paste(get(c, r), (i*16, 0))
out.save(os.path.join(base, "floor_samples.png"))
print("saved floor_samples.png")
