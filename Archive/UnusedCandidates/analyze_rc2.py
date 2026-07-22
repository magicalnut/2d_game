from PIL import Image
import numpy as np

img_path = r"F:\GodotProduction\R-C.png"
img = Image.open(img_path).convert('RGBA')
arr = np.array(img)
h, w = arr.shape[:2]

# 1. 找背景色：最常见颜色（4通道量化）
pixels = arr.reshape(-1, 4)
# 量化到降低噪声
quant = (pixels // 16) * 16
unique, counts = np.unique(quant, axis=0, return_counts=True)
order = np.argsort(-counts)
print("Top background candidates (RGBA quantized):")
for i in range(min(5, len(order))):
    idx = order[i]
    c = unique[idx]
    print(f"  color=({c[0]},{c[1]},{c[2]},{c[3]}) count={counts[idx]} ({100*counts[idx]/len(pixels):.1f}%)")

bg_color = tuple(unique[order[0]])
print(f"\nTreating dominant color as background: {bg_color}")

# 2. 构建非背景 mask（任一通道与背景差距>24 视为内容）
diff = np.abs(arr.astype(int) - np.array(bg_color).astype(int)).max(axis=2)
mask = diff > 24  # True=内容

# 3. 检测行周期：每行的平均内容密度，找谷值（帧间分隔）
row_density = mask.mean(axis=1)
# 找局部最小
print("\nRow content density (sampled every 5px), low values ~ frame gaps:")
for y in range(0, h, 5):
    bar = '#' * int(row_density[y] * 40)
    print(f"  y={y:3d}: {row_density[y]:.2f} {bar}")

# 4. 检测列周期
col_density = mask.mean(axis=0)
print("\nColumn content density (sampled every 8px):")
for x in range(0, w, 8):
    bar = '#' * int(col_density[x] * 40)
    print(f"  x={x:3d}: {col_density[x]:.2f} {bar}")
