from PIL import Image
import os

img_path = r"C:\Users\86189\.workbuddy\clipboard-images\clipboard-2026-07-15T06-16-27-229Z-9d482db6.png"
img = Image.open(img_path)
print(f"Size: {img.size}")
print(f"Mode: {img.mode}")

w, h = img.size

# 尝试推测每帧大小
# 行数明显是 4 行
rows = 4
row_h = h / rows
print(f"Row height: {row_h}")

# 列数可能是 9
cols = 9
col_w = w / cols
print(f"Col width (9 cols): {col_w}")

# 也尝试 8/10 列
for c in [8, 9, 10]:
    print(f"  {c} cols -> {w/c:.2f}px")

# 检测每行非透明边界
import numpy as np
arr = np.array(img.convert('RGBA'))
alpha = arr[:, :, 3]

for r in range(rows):
    y0 = int(r * row_h)
    y1 = int((r+1) * row_h)
    row_alpha = alpha[y0:y1, :]
    nonzero = np.argwhere(row_alpha > 30)
    if len(nonzero) > 0:
        min_y, min_x = nonzero.min(axis=0)
        max_y, max_x = nonzero.max(axis=0)
        print(f"Row {r}: y={y0+y0}-{y0+y1}, content x={min_x}-{max_x}, y={y0+min_y}-{y0+max_y}")

# 输出一个网格叠加图帮助确认
from PIL import ImageDraw
preview = img.copy().convert('RGBA')
draw = ImageDraw.Draw(preview)
for c in range(cols+1):
    x = int(c * col_w)
    draw.line([(x, 0), (x, h)], fill=(255, 0, 0, 128), width=1)
for r in range(rows+1):
    y = int(r * row_h)
    draw.line([(0, y), (w, y)], fill=(255, 0, 0, 128), width=1)

preview.save(r"F:\GodotProduction\character-design\_candidates\player_sheet_grid.png")
print("Saved grid preview to _candidates/player_sheet_grid.png")
