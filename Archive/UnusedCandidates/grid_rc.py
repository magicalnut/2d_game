from PIL import Image, ImageDraw

img_path = r"F:\GodotProduction\R-C.png"
out_path = r"F:\GodotProduction\character-design\_candidates\R-C_grid.png"

img = Image.open(img_path).convert('RGBA')
w, h = img.size
draw = ImageDraw.Draw(img)

# 检测到的横向空白带（深灰分隔）
row_gaps = [(45, 172), (575, 697)]
col_gaps = [(8, 48), (960, 1008)]

# 画横向分隔线
for y0, y1 in row_gaps:
    mid = (y0 + y1) // 2
    draw.line([(0, mid), (w, mid)], fill=(255, 0, 0, 200), width=2)

# 画纵向分隔线
for x0, x1 in col_gaps:
    mid = (x0 + x1) // 2
    draw.line([(mid, 0), (mid, h)], fill=(0, 128, 255, 200), width=2)

# 标注内容区边界
draw.rectangle([48, 0, 960, 723], outline=(0, 255, 0, 160), width=2)

# 顶部/底部段边界
draw.rectangle([0, 0, w, 44], outline=(255, 255, 0, 180), width=2)
draw.rectangle([0, 698, w, 722], outline=(255, 255, 0, 180), width=2)

# 中间大块边界
draw.rectangle([48, 175, 960, 574], outline=(255, 0, 255, 180), width=2)

img.save(out_path)
print(f"Saved annotated grid to {out_path}")
print(f"Image size: {w}x{h}")
print("Red lines = horizontal gaps (rows), Blue lines = vertical gaps (cols)")
print("Yellow boxes = top/bottom small segments, Magenta box = middle big block")
