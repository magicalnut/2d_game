from PIL import Image
import numpy as np

path = r"F:\GodotProduction\character-design\Assets\Sprites\Characters\Player\player_sheet.png"
arr = np.array(Image.open(path).convert('RGBA'))
h, w = arr.shape[:2]
rgb = arr[:, :, :3].astype(int)

def count(is_bg_fn):
    mask = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            mask[y, x] = is_bg_fn(rgb[y, x])
    return mask.sum()

def is_bg_strict(c):
    if max(abs(c[0]-c[1]), abs(c[1]-c[2]), abs(c[0]-c[2])) > 16:
        return False
    lum = (int(c[0])+int(c[1])+int(c[2]))//3
    return 185 <= lum <= 230

def is_bg_loose(c):
    if max(abs(c[0]-c[1]), abs(c[1]-c[2]), abs(c[0]-c[2])) > 30:
        return False
    lum = (int(c[0])+int(c[1])+int(c[2]))//3
    return 170 <= lum <= 240

print("strict count:", int(count(is_bg_strict)))
print("loose  count:", int(count(is_bg_loose)))

# 边缘 is_bg 数量
edge_strict = 0
for x in range(w):
    for y in (0, h-1):
        if is_bg_strict(rgb[y, x]): edge_strict += 1
for y in range(h):
    for x in (0, w-1):
        if is_bg_strict(rgb[y, x]): edge_strict += 1
print("edge strict seeds:", edge_strict)

# 看背景典型像素分布：采样几个背景位置
# 找一帧 (0,0) 的角落 0..10
print("Sample RGB at (0,0)-(5,5):")
for yy in range(5):
    print("  ", [tuple(rgb[yy, xx]) for xx in range(5)])
