from PIL import Image
import numpy as np

img_path = r"F:\GodotProduction\R-C.png"
img = Image.open(img_path)
print(f"Size: {img.size}")
print(f"Mode: {img.mode}")
w, h = img.size
arr = np.array(img.convert('RGBA'))
alpha = arr[:, :, 3]

# 检测内容行
row_ranges = []
y = 0
while y < h:
    while y < h and alpha[y, :].max() < 30:
        y += 1
    if y >= h:
        break
    y_start = y
    while y < h and alpha[y, :].max() >= 30:
        y += 1
    row_ranges.append((y_start, y))
    y += 1

print(f"Detected {len(row_ranges)} content rows:")
for i, (y0, y1) in enumerate(row_ranges):
    print(f"  Row {i}: y={y0}-{y1-1}, height={y1-y0}")

# 检测每行的帧列数：用第一行
if row_ranges:
    y0, y1 = row_ranges[0]
    rh = y1 - y0
    print(f"\nRow 0 height: {rh}")
    # 找列边界：投影到 x 轴，找空白列
    col_proj = alpha[y0:y1, :].max(axis=0)
    # 找连续有内容的块
    in_content = False
    frames = []
    start = 0
    for x in range(w):
        if col_proj[x] >= 30 and not in_content:
            in_content = True
            start = x
        elif col_proj[x] < 30 and in_content:
            in_content = False
            frames.append((start, x-1, x-start))
    if in_content:
        frames.append((start, w-1, w-start))
    print(f"Row 0 detected {len(frames)} frames by gap detection:")
    for f in frames:
        print(f"  x={f[0]}-{f[1]}, width={f[2]}")

    # 用均分估算
    for nframes in [8, 9, 10, 11, 12]:
        print(f"  If {nframes} frames: {w/nframes:.2f}px each")
