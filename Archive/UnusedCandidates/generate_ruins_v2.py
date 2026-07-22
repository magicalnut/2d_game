import os, random
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

random.seed(42)

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
    """paste respecting alpha"""
    dst.paste(src, (x, y), src)

def tint(src_img, mult, add=(0,0,0)):
    """multiply RGB then add; keep alpha. mult/add are (R,G,B)"""
    arr = np.array(src_img).astype(float)
    for i in range(3):
        arr[..., i] = arr[..., i] * mult[i] + add[i]
    np.clip(arr[..., :3], 0, 255, out=arr[..., :3])
    return Image.fromarray(arr.astype(np.uint8))

# ---- tile palettes (column, row) ----
walls_grey = [(8,0),(9,0),(10,0),(11,0),(12,0),
              (8,1),(9,1),(10,1),(11,1),(12,1),
              (8,2),(9,2),(10,2),(11,2),(12,2)]
walls_dark = [(21,0),(22,0),(23,0),(24,0),(25,0),(26,0),(27,0),(28,0),
              (21,1),(22,1),(23,1),(24,1),(25,1),(26,1),(27,1),(28,1),
              (21,2),(22,2),(23,2),(24,2),(25,2),(26,2),(27,2),(28,2),
              (21,3),(22,3),(23,3),(24,3),(25,3),(26,3),(27,3),(28,3)]
floors_grey = [(18,8),(19,8),(20,8),(18,9),(19,9),(20,9),(18,10),(19,10),(20,10)]
floors_crack = [(8,8),(9,8),(10,8),(11,8),(12,8),
                (8,9),(9,9),(10,9),(11,9),(12,9),
                (8,10),(9,10),(10,10),(11,10),(12,10)]
floors_dirt = [(13,8),(14,8),(15,8),(16,8),(17,8),
               (13,9),(14,9),(15,9),(16,9),(17,9),
               (13,10),(14,10),(15,10),(16,10),(17,10)]
pillars = [(0,5),(1,5),(0,6),(1,6),(0,7),(1,7)]
banner = [(2,5),(2,6)]
crystals = [(0,0),(1,0),(2,0),(3,0),(0,1),(1,1),(2,1),(3,1)]
gems = [(13,10),(14,10),(15,10),(16,10),(13,11),(14,11),(15,11),(16,11),
        (13,12),(14,12),(15,12),(16,12)]
skulls = [(0,2),(1,2),(2,2),(3,2),(0,3),(1,3),(2,3),(3,3)]
rocks = [(4,0),(5,0),(6,0),(7,0),(4,1),(5,1),(6,1),(7,1)]
lights = [(15,13),(16,13),(17,13),(15,14),(16,14),(17,14)]
water = [(0,8),(1,8),(2,8),(3,8),(4,8),(5,8),(6,8),(7,8),
         (0,9),(1,9),(2,9),(3,9),(4,9),(5,9),(6,9),(7,9)]

# ---- canvas ----
GRID_W, GRID_H = 80, 45
W, H = GRID_W * TILE, GRID_H * TILE
canvas = Image.new("RGBA", (W, H), (18, 18, 22, 255))

# ---- walls (perimeter + some inner ruined walls) ----
for x in range(GRID_W):
    paste(canvas, tile(*random.choice(walls_dark)), x*TILE, 0)
    paste(canvas, tile(*random.choice(walls_dark)), x*TILE, (GRID_H-1)*TILE)
for y in range(1, GRID_H-1):
    paste(canvas, tile(*random.choice(walls_dark)), 0, y*TILE)
    paste(canvas, tile(*random.choice(walls_dark)), (GRID_W-1)*TILE, y*TILE)

# ruined inner wall fragments (top/back area)
for x in range(12, GRID_W-12):
    if random.random() < 0.25:
        paste(canvas, tile(*random.choice(walls_grey)), x*TILE, 4*TILE)

# ---- floor ----
floor_layout = {}
for y in range(1, GRID_H-1):
    for x in range(1, GRID_W-1):
        r = random.random()
        if r < 0.12:
            t = floors_crack
        elif r < 0.22:
            t = floors_dirt
        else:
            t = floors_grey
        paste(canvas, tile(*random.choice(t)), x*TILE, y*TILE)
        floor_layout[(x, y)] = t

# ---- golden statues along left/right sides ----
# warm gold tint for stone pillars
def golden_pillar():
    p = tile(*random.choice(pillars))
    return tint(p, (1.35, 1.15, 0.65), (25, 10, -10))

for y in range(5, GRID_H-5, 6):
    # left
    p = golden_pillar()
    paste(canvas, p, 2*TILE, y*TILE)
    # right
    p = golden_pillar()
    paste(canvas, p, (GRID_W-3)*TILE, y*TILE)

# ---- red banners hanging from top ----
def red_banner():
    b = tile(*random.choice(banner))
    return tint(b, (1.55, 0.35, 0.35), (35, -10, -10))

for x in range(8, GRID_W-8, 7):
    if random.random() < 0.8:
        b = red_banner()
        paste(canvas, b, x*TILE, 2*TILE)

# ---- back teal glow / portal pool ----
back_w, back_h = 28, 7
back_x = (GRID_W - back_w) // 2
back_y = 6
for y in range(back_y, back_y + back_h):
    for x in range(back_x, back_x + back_w):
        if 1 <= x < GRID_W-1 and 1 <= y < GRID_H-1:
            w = tile(*random.choice(water))
            # boost teal/cyan
            w = tint(w, (0.75, 1.15, 1.35), (10, 35, 60))
            paste(canvas, w, x*TILE, y*TILE)

# frame the glow with grey stone
for x in range(back_x-1, back_x+back_w+1):
    paste(canvas, tile(*random.choice(walls_grey)), x*TILE, (back_y-1)*TILE)
    paste(canvas, tile(*random.choice(walls_grey)), x*TILE, (back_y+back_h)*TILE)
for y in range(back_y-1, back_y+back_h+1):
    paste(canvas, tile(*random.choice(walls_grey)), (back_x-1)*TILE, y*TILE)
    paste(canvas, tile(*random.choice(walls_grey)), (back_x+back_w)*TILE, y*TILE)

# ---- scattered decor ----
random_positions = [(random.randint(3, GRID_W-4), random.randint(8, GRID_H-4)) for _ in range(70)]
for (x, y) in random_positions:
    if (back_x-2 <= x <= back_x+back_w+2) and (back_y-2 <= y <= back_y+back_h+2):
        continue  # don't clutter the glow area
    choice = random.random()
    if choice < 0.22:
        obj = tile(*random.choice(crystals))
        obj = tint(obj, (0.8, 1.1, 1.3), (5, 20, 35))  # slight cyan
    elif choice < 0.38:
        obj = tile(*random.choice(gems))
    elif choice < 0.55:
        obj = tile(*random.choice(skulls))
    elif choice < 0.72:
        obj = tile(*random.choice(rocks))
    else:
        obj = tile(*random.choice(lights))
        obj = tint(obj, (1.4, 1.1, 0.7), (40, 20, -10))  # warm torch
    paste(canvas, obj, x*TILE, y*TILE)

# ---- convert to RGB for post FX ----
img = canvas.convert("RGB")
arr = np.array(img).astype(float)
h, w = arr.shape[:2]

# 1. vignette (darken corners, keep center)
Y, X = np.ogrid[:h, :w]
cx, cy = w // 2, h // 2
max_d = np.sqrt(cx**2 + cy**2)
dist = np.sqrt((X-cx)**2 + (Y-cy)**2)
mask = 1.0 - (dist / max_d) * 0.45
mask = np.clip(mask, 0.35, 1.0)
arr *= mask[:, :, None]

# 2. teal back glow (top-center)
glow = np.zeros_like(arr)
yc, xc = int(h * 0.22), w // 2
radius = h * 0.55
for y in range(h):
    for x in range(w):
        d = np.sqrt((x-xc)**2 + (y-yc)**2)
        if d < radius:
            f = (1 - d/radius) ** 1.8
            glow[y, x] = [0, 45*f, 65*f]
arr += glow

# 3. subtle shadow lift toward teal in dark areas
lum = arr.max(axis=2, keepdims=True)
teal_tint = np.zeros_like(arr)
teal_tint[..., 0] = 0
teal_tint[..., 1] = 12
teal_tint[..., 2] = 18
# blend stronger where dark
shadow_weight = np.clip(1.0 - lum/80.0, 0, 1)
arr = arr + teal_tint * shadow_weight

# 4. warm statues - already tinted; add slight global warmth to midtones
arr[..., 0] = np.clip(arr[..., 0] * 1.06 + 4, 0, 255)
arr[..., 1] = np.clip(arr[..., 1] * 1.02 + 1, 0, 255)

np.clip(arr, 0, 255, out=arr)
final = Image.fromarray(arr.astype(np.uint8))

# save
out_full = os.path.join(BASE, "backgrounds", "ruins_v2.png")
out_prev = os.path.join(BASE, "backgrounds", "preview_ruins_v2.png")
final.save(out_full)
final.resize((1280, 720), Image.NEAREST).save(out_prev)
print("saved", out_full, final.size)
print("saved preview", out_prev)
