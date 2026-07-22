from PIL import Image
import numpy as np
from collections import deque

path = r"F:\GodotProduction\character-design\Assets\Sprites\Characters\Player\player_sheet.png"
img = Image.open(path).convert('RGBA')
arr = np.array(img)
h, w = arr.shape[:2]
rgb = arr[:, :, :3].astype(int)

out = arr.copy().copy()
keep = np.ones((h, w), bool)  # True = 保留(人物)

def is_bg(y, x):
    c = rgb[y, x]
    # 必须是近灰度（排除带色相的角色）
    if max(abs(c[0]-c[1]), abs(c[1]-c[2]), abs(c[0]-c[2])) > 16:
        return False
    lum = (int(c[0]) + int(c[1]) + int(c[2])) // 3
    return 185 <= lum <= 230  # 棋盘格背景的两种灰范围

visited = np.zeros((h, w), bool)
q = deque()
# 边缘种子
for x in range(w):
    for y in (0, h-1):
        if is_bg(y, x):
            visited[y, x] = True
            q.append((y, x))
for y in range(h):
    for x in (0, w-1):
        if is_bg(y, x):
            visited[y, x] = True
            q.append((y, x))

# flood fill 背景
while q:
    y, x = q.popleft()
    keep[y, x] = False  # 标记为背景 -> 透明
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = y + dy, x + dx
        if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_bg(ny, nx):
            visited[ny, nx] = True
            q.append((ny, nx))

# 应用：背景像素 alpha 置 0
new_alpha = np.where(keep, arr[:, :, 3], 0)
out[:, :, 3] = new_alpha

out_img = Image.fromarray(out, 'RGBA')
out_img.save(path)

prev = out_img.resize((w * 2, h * 2), Image.NEAREST)
prev.save(r"F:\GodotProduction\character-design\_candidates\player_sheet_clean_preview.png")

print(f"size={w}x{h}")
print(f"transparent pixels after: {int((~keep).sum())} / {h*w} = {100*(~keep).sum()/(h*w):.1f}%")
print("kept (character) pixels: ", int(keep.sum()))

# 边缘残留检查：被删像素中是否有"被人物包围"的（误删风险），粗略统计孤立透明块
# 这里只输出预览，供人工查看
