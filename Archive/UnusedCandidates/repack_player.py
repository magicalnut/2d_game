from PIL import Image

src = r"C:\Users\86189\.workbuddy\clipboard-images\clipboard-2026-07-15T06-16-27-229Z-9d482db6.png"
dst = r"F:\GodotProduction\character-design\Assets\Sprites\Characters\Player\player_sheet.png"

img = Image.open(src).convert('RGBA')
w, h = img.size
print(f"Source: {w}x{h}")

COLS = 9
ROWS = 4
CELL = 65        # 源图每格大小（含 1px 透明间距）
FRAME = 64       # 实际人物帧大小

out_w = COLS * FRAME
out_h = ROWS * FRAME
out = Image.new('RGBA', (out_w, out_h), (0, 0, 0, 0))

for r in range(ROWS):
    for c in range(COLS):
        sx = c * CELL
        sy = r * CELL
        frame = img.crop((sx, sy, sx + FRAME, sy + FRAME))
        dx = c * FRAME
        dy = r * FRAME
        out.paste(frame, (dx, dy))

out.save(dst)
print(f"Saved {dst}: {out_w}x{out_h}")

# 同时生成一个 2x 放大预览
preview = out.resize((out_w * 2, out_h * 2), Image.NEAREST)
preview.save(r"F:\GodotProduction\character-design\_candidates\player_sheet_preview.png")
print("Saved 2x preview to _candidates/player_sheet_preview.png")
