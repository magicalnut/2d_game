from PIL import Image, ImageDraw, ImageFont
import os

src = os.path.join(os.path.dirname(__file__), "kenney_roguelike", "Spritesheet", "roguelikeDungeon_transparent.png")
img = Image.open(src).convert("RGBA")
scale = 4
w, h = img.size
scaled = img.resize((w*scale, h*scale), Image.NEAREST)

draw = ImageDraw.Draw(scaled)
# Grid
for c in range(30):
    x = c * 17 * scale
    draw.line([(x, 0), (x, scaled.height)], fill=(255,0,0,80), width=1)
for r in range(19):
    y = r * 17 * scale
    draw.line([(0, y), (scaled.width, y)], fill=(255,0,0,80), width=1)

# Labels
try:
    font = ImageFont.truetype("arial.ttf", 14)
except:
    font = ImageFont.load_default()

for c in range(29):
    for r in range(18):
        x = c * 17 * scale + 2
        y = r * 17 * scale + 2
        draw.text((x, y), f"{c},{r}", fill=(255,255,255,255), font=font, stroke_width=2, stroke_fill=(0,0,0,255))

out = os.path.join(os.path.dirname(__file__), "kenney_roguelike", "annotated.png")
scaled.save(out)
print("saved", out, scaled.size)
