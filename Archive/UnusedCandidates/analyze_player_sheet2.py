from PIL import Image
import numpy as np

img_path = r"C:\Users\86189\.workbuddy\clipboard-images\clipboard-2026-07-15T06-16-27-229Z-9d482db6.png"
img = Image.open(img_path)
w, h = img.size
arr = np.array(img.convert('RGBA'))
alpha = arr[:, :, 3]

# 按行检测内容
row_ranges = []
y = 0
while y < h:
    # 找当前 y 开始有内容的行
    while y < h and alpha[y, :].max() < 30:
        y += 1
    if y >= h:
        break
    y_start = y
    while y < h and alpha[y, :].max() >= 30:
        y += 1
    y_end = y
    row_ranges.append((y_start, y_end))

print(f"Detected {len(row_ranges)} rows:")
for i, (y0, y1) in enumerate(row_ranges):
    print(f"  Row {i}: y={y0}-{y1-1}, height={y1-y0}")

# 按列检测 - 在合并后的内容区域内
nonzero = np.argwhere(alpha > 30)
min_x, max_x = nonzero[:, 1].min(), nonzero[:, 1].max()
print(f"Content x range: {min_x}-{max_x}")

# 假设每行有 9 帧，按等宽切
# 用第一行来分析列
if row_ranges:
    y0, y1 = row_ranges[0]
    row_img = alpha[y0:y1, :]
    # 对整行做垂直投影，找空白列
    col_proj = row_img.max(axis=0)
    # 找空白间隔
    gaps = []
    in_gap = False
    start = 0
    for x in range(w):
        if col_proj[x] < 30:
            if not in_gap:
                in_gap = True
                start = x
        else:
            if in_gap:
                gaps.append((start, x-1, x-start))
                in_gap = False
    if in_gap:
        gaps.append((start, w-1, w-start))
    print(f"Detected gaps between frames (x, width): {gaps[:20]}")

# 尝试 64x64 + 1px 间距 = 65 的网格
# 也尝试 64x64 无间距
# 生成两种网格预览对比
from PIL import ImageDraw

for frame_h in [64, 65]:
    preview = img.copy().convert('RGBA')
    draw = ImageDraw.Draw(preview)
    for c in range(10):
        x = c * 65
        if x <= w:
            draw.line([(x, 0), (x, h)], fill=(255, 0, 0, 128), width=1)
    for r in range(5):
        y = r * frame_h + (0 if frame_h == 65 else 0)
        if y <= h:
            draw.line([(0, y), (w, y)], fill=(255, 0, 0, 128), width=1)
    preview.save(rf"F:\GodotProduction\character-design\_candidates\player_sheet_grid_{frame_h}h.png")
    print(f"Saved grid {frame_h}h preview")
