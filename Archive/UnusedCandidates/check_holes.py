from PIL import Image
import numpy as np
from collections import deque

path = r"F:\GodotProduction\character-design\Assets\Sprites\Characters\Player\player_sheet.png"
arr = np.array(Image.open(path).convert('RGBA'))
h, w = arr.shape[:2]
bg = arr[:, :, 3] < 30  # 透明 = 背景

# flood fill from edge over bg -> outer background
visited = np.zeros((h, w), bool)
q = deque()
for x in range(w):
    for y in (0, h-1):
        if bg[y, x]:
            visited[y, x] = True; q.append((y, x))
for y in range(h):
    for x in (0, w-1):
        if bg[y, x]:
            visited[y, x] = True; q.append((y, x))
while q:
    y, x = q.popleft()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ny, nx = y+dy, x+dx
        if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and bg[ny, nx]:
            visited[ny, nx] = True
            q.append((ny, nx))

outer_bg = visited.copy()
holes = bg & ~outer_bg  # 内部透明岛
print(f"total transparent: {int(bg.sum())}")
print(f"outer background (edge-connected): {int(outer_bg.sum())}")
print(f"internal holes (enclosed): {int(holes.sum())}")

# 连通分量 of holes
lab = np.zeros((h, w), int)
cur = 1
sizes = []
for y0 in range(h):
    for x0 in range(w):
        if holes[y0, x0] and not lab[y0, x0]:
            # bfs
            q = deque([(y0, x0)])
            lab[y0, x0] = cur
            cnt = 0
            while q:
                y, x = q.popleft()
                cnt += 1
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y+dy, x+dx
                    if 0 <= ny < h and 0 <= nx < w and holes[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = cur
                        q.append((ny, nx))
            sizes.append(cnt)
            cur += 1
sizes.sort(reverse=True)
print(f"internal hole components: {len(sizes)}")
print(f"top hole sizes: {sizes[:10]}")
print("If top holes are small (<100px), character is likely intact (minor artifacts only).")
