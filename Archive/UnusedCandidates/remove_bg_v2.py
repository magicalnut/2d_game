from PIL import Image
import numpy as np

src = r"C:\Users\86189\.workbuddy\clipboard-images\clipboard-2026-07-15T06-16-27-229Z-9d482db6.png"
dst = r"F:\GodotProduction\character-design\Assets\Sprites\Characters\Player\player_sheet.png"
prev_dst = r"F:\GodotProduction\character-design\_candidates\player_sheet_clean_preview.png"

img = Image.open(src).convert('RGBA')
src_arr = np.array(img)
H, W = src_arr.shape[:2]
print(f"source {W}x{H}")

COLS, ROWS = 9, 4
CELL = 65
FRAME = 64
ow, oh = COLS * FRAME, ROWS * FRAME
print(f"output {ow}x{oh}")

out_arr = np.zeros((oh, ow, 4), dtype=np.uint8)
for r in range(ROWS):
    for c in range(COLS):
        sy, sx = r * CELL, c * CELL
        frame = src_arr[sy:sy+FRAME, sx:sx+FRAME]
        out_arr[r*FRAME:(r+1)*FRAME, c*FRAME:(c+1)*FRAME] = frame

rgb = out_arr[:, :, :3].astype(int)

def is_bg(c):
    # 背景：近灰度 + 亮度落在棋盘格背景区间
    if max(abs(c[0]-c[1]), abs(c[1]-c[2]), abs(c[0]-c[2])) > 18:
        return False
    lum = (int(c[0]) + int(c[1]) + int(c[2])) // 3
    return 178 <= lum <= 235

bg = np.zeros((oh, ow), bool)
for y in range(oh):
    for x in range(ow):
        bg[y, x] = is_bg(rgb[y, x])

print(f"bg pixels (chroma key): {int(bg.sum())} / {oh*ow} = {100*bg.sum()/(oh*ow):.1f}%")

# 应用透明
alpha = np.where(bg, 0, out_arr[:, :, 3])
out_arr[:, :, 3] = alpha

out_img = Image.fromarray(out_arr, 'RGBA')
out_img.save(dst)
prev = out_img.resize((ow*2, oh*2), Image.NEAREST)
prev.save(prev_dst)
print("saved", dst)
