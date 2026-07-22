import os, random
from PIL import Image, ImageDraw
import numpy as np

random.seed(44)

BASE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE, "kenney_roguelike", "Spritesheet", "roguelikeDungeon_transparent.png")
sheet = Image.open(SRC).convert("RGBA")

def get(c, r):
    return sheet.crop((c*17, r*17, c*17+16, r*17+16))

SCALE = 2
TILE = 16 * SCALE

def tile(c, r):
    return get(c, r).resize((TILE, TILE), Image.NEAREST)

def paste(dst, src, x, y):
    dst.paste(src, (x, y), src)

def tint(src_img, mult, add=(0,0,0)):
    arr = np.array(src_img).astype(float)
    for i in range(3):
        arr[..., i] = arr[..., i] * mult[i] + add[i]
    np.clip(arr[..., :3], 0, 255, out=arr[..., :3])
    return Image.fromarray(arr.astype(np.uint8))

# ---- palettes (verified against annotated sheet) ----
walls_dark = [(21,0),(22,0),(23,0),(24,0),(25,0),(26,0),(27,0),(28,0),
              (21,1),(22,1),(23,1),(24,1),(25,1),(26,1),(27,1),(28,1),
              (21,2),(22,2),(23,2),(24,2),(25,2),(26,2),(27,2),(28,2)]
walls_grey = [(8,0),(9,0),(10,0),(11,0),(12,0),
              (8,1),(9,1),(10,1),(11,1),(12,1),
              (8,2),(9,2),(10,2),(11,2),(12,2)]
# true grey floors are col 20; cracked grey is col 9
floors_grey = [(20,8),(20,9),(20,10),(20,11),(20,12),(20,13)]
floors_crack = [(9,8),(9,9),(9,10),(9,11),(9,12),(9,13)]
# beige sand at col 18 for optional path highlight
floors_sand = [(18,8),(18,9),(18,10)]

pillars = [(0,5),(1,5),(0,6),(1,6)]
banner = [(2,5),(2,6)]
crystals = [(0,0),(1,0),(2,0),(3,0)]
gems = [(13,10),(14,10),(15,10),(16,10),(13,11),(14,11),(15,11),(16,11)]
skulls = [(0,2),(1,2),(2,2),(3,2)]
rocks = [(4,0),(5,0),(6,0),(7,0),(4,1),(5,1),(6,1),(7,1)]
lights = [(15,13),(16,13),(17,13),(15,14),(16,14),(17,14)]
water = [(0,8),(1,8),(2,8),(3,8),(4,8),(5,8),(6,8),(7,8),
         (0,9),(1,9),(2,9),(3,9),(4,9),(5,9),(6,9),(7,9)]

GRID_W, GRID_H = 80, 45
W, H = GRID_W * TILE, GRID_H * TILE
canvas = Image.new("RGBA", (W, H), (14, 14, 17, 255))

# ---- floor ----
for y in range(1, GRID_H-1):
    for x in range(1, GRID_W-1):
        r = random.random()
        if r < 0.07:
            t = tile(*random.choice(floors_crack))
        else:
            t = tile(*random.choice(floors_grey))
        # cool/desaturate slightly for dark ruin mood
        t = tint(t, (0.92, 0.95, 1.05), (-8, -6, -2))
        paste(canvas, t, x*TILE, y*TILE)

# central worn path (subtle sand/darker grey)
path_half = 5
for y in range(12, GRID_H-2):
    for x in range(GRID_W//2 - path_half, GRID_W//2 + path_half + 1):
        if random.random() < 0.55:
            t = tile(*random.choice(floors_sand))
            t = tint(t, (0.85, 0.85, 0.95), (-18, -14, -6))  # darken to grey-beige
            paste(canvas, t, x*TILE, y*TILE)

# ---- perimeter dark walls ----
for x in range(GRID_W):
    paste(canvas, tile(*random.choice(walls_dark)), x*TILE, 0)
    paste(canvas, tile(*random.choice(walls_dark)), x*TILE, (GRID_H-1)*TILE)
for y in range(1, GRID_H-1):
    paste(canvas, tile(*random.choice(walls_dark)), 0, y*TILE)
    paste(canvas, tile(*random.choice(walls_dark)), (GRID_W-1)*TILE, y*TILE)

# ---- back teal glow / portal ----
back_w, back_h = 34, 7
back_x = (GRID_W - back_w) // 2
back_y = 5
# grey stone frame
for x in range(back_x-1, back_x+back_w+1):
    paste(canvas, tile(*random.choice(walls_grey)), x*TILE, (back_y-1)*TILE)
    paste(canvas, tile(*random.choice(walls_grey)), x*TILE, (back_y+back_h)*TILE)
for y in range(back_y-1, back_y+back_h+1):
    paste(canvas, tile(*random.choice(walls_grey)), (back_x-1)*TILE, y*TILE)
    paste(canvas, tile(*random.choice(walls_grey)), (back_x+back_w)*TILE, y*TILE)
# glowing interior
for y in range(back_y, back_y+back_h):
    for x in range(back_x, back_x+back_w):
        w = tile(*random.choice(water))
        w = tint(w, (0.65, 1.25, 1.55), (10, 50, 95))
        paste(canvas, w, x*TILE, y*TILE)

# ---- golden statues (2 tiles tall) ----
def golden_pillar():
    p = tile(*random.choice(pillars))
    return tint(p, (1.55, 1.35, 0.75), (45, 25, -5))

statue_y = list(range(8, GRID_H-8, 8))
for y in statue_y:
    p1 = golden_pillar()
    p2 = golden_pillar()
    paste(canvas, p1, 2*TILE, y*TILE)
    paste(canvas, p2, 2*TILE, (y+1)*TILE)
    p1 = golden_pillar()
    p2 = golden_pillar()
    paste(canvas, p1, (GRID_W-3)*TILE, y*TILE)
    paste(canvas, p2, (GRID_W-3)*TILE, (y+1)*TILE)

# ---- red banners (2 tiles tall) ----
def red_banner():
    b = tile(*random.choice(banner))
    return tint(b, (1.7, 0.30, 0.30), (55, -15, -15))

for x in range(12, GRID_W-12, 10):
    if random.random() < 0.85:
        paste(canvas, red_banner(), x*TILE, 2*TILE)
        paste(canvas, red_banner(), x*TILE, 3*TILE)

# ---- crystals near back glow ----
for _ in range(22):
    x = random.randint(back_x-4, back_x+back_w+4)
    y = random.randint(back_y+back_h+1, back_y+back_h+5)
    if 1 <= x < GRID_W-1 and 1 <= y < GRID_H-1:
        c = tile(*random.choice(crystals))
        c = tint(c, (0.7, 1.2, 1.5), (10, 35, 65))
        paste(canvas, c, x*TILE, y*TILE)

# ---- braziers beside statues ----
for y in statue_y:
    for dx in [4, GRID_W-5]:
        b = tile(*random.choice(lights))
        b = tint(b, (1.6, 1.25, 0.75), (60, 30, -5))
        paste(canvas, b, dx*TILE, (y+1)*TILE)

# ---- sparse corner rubble ----
for _ in range(18):
    x = random.randint(4, GRID_W-5)
    y = random.randint(14, GRID_H-5)
    if abs(x - GRID_W//2) <= path_half+2:
        continue
    if (back_x-4 <= x <= back_x+back_w+4) and (y <= back_y+back_h+6):
        continue
    choice = random.random()
    if choice < 0.35:
        obj = tile(*random.choice(skulls))
    elif choice < 0.7:
        obj = tile(*random.choice(rocks))
    else:
        obj = tile(*random.choice(gems))
    paste(canvas, obj, x*TILE, y*TILE)

# ---- post-processing ----
img = canvas.convert("RGB")
arr = np.array(img).astype(float)
h, w = arr.shape[:2]

# strong vignette
Y, X = np.ogrid[:h, :w]
cx, cy = w // 2, h // 2
max_d = np.sqrt(cx**2 + cy**2)
dist = np.sqrt((X-cx)**2 + (Y-cy)**2)
mask = 1.0 - (dist / max_d) * 0.60
mask = np.clip(mask, 0.20, 1.0)
arr *= mask[:, :, None]

# teal back glow
yc, xc = int(h * 0.17), w // 2
radius = h * 0.60
glow = np.zeros_like(arr)
for y in range(h):
    drow = y - yc
    for x in range(w):
        d = np.sqrt((x-xc)**2 + drow**2)
        if d < radius:
            f = (1 - d/radius) ** 1.5
            glow[y, x] = [0, 52*f, 78*f]
arr += glow

# shadow teal lift
lum = arr.max(axis=2, keepdims=True)
teal = np.array([0, 16, 26], dtype=float).reshape(1,1,3)
shadow_w = np.clip(1.0 - lum/60.0, 0, 1)
arr += teal * shadow_w

# subtle warm accent on highlights (statues/braziers)
arr[..., 0] = np.clip(arr[..., 0] * 1.05 + 3, 0, 255)

np.clip(arr, 0, 255, out=arr)
final = Image.fromarray(arr.astype(np.uint8))

out_full = os.path.join(BASE, "backgrounds", "ruins_v4.png")
out_prev = os.path.join(BASE, "backgrounds", "preview_ruins_v4.png")
final.save(out_full)
final.resize((1280, 720), Image.NEAREST).save(out_prev)
print("saved", out_full, final.size)
print("saved preview", out_prev)
