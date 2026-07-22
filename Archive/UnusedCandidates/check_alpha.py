from PIL import Image
import numpy as np

paths = [
    r"F:\GodotProduction\character-design\Assets\Sprites\Characters\Player\player_sheet.png",
    r"C:\Users\86189\.workbuddy\clipboard-images\clipboard-2026-07-15T06-16-27-229Z-9d482db6.png",
]

for p in paths:
    try:
        img = Image.open(p).convert('RGBA')
    except Exception as e:
        print(f"[skip] {p}: {e}")
        continue
    arr = np.array(img)
    alpha = arr[:,:,3]
    print(f"\n=== {p} ===")
    print(f"size={img.size}  alpha min={alpha.min()} max={alpha.max()} mean={alpha.mean():.1f}")
    # 透明像素比例
    transparent = (alpha < 30).mean()
    print(f"transparent(<30 alpha) ratio = {transparent:.3f}")
    # 看四个角和中心的 RGB（仅不透明像素区域附近）
    h, w = arr.shape[:2]
    # 采样左上角 5x5
    corner = arr[0:5, 0:5, :]
    print(f"top-left 5x5 RGBA (first 3 px):")
    for yy in range(3):
        for xx in range(3):
            print(f"  ({xx},{yy}) = {tuple(corner[yy,xx])}")
    # 统计颜色直方图（量化），找最常见的非透明颜色
    opaque = arr[alpha >= 30].reshape(-1, 4)
    if len(opaque) > 0:
        quant = (opaque // 32) * 32
        uniq, cnt = np.unique(quant, axis=0, return_counts=True)
        order = np.argsort(-cnt)
        print("Top opaque colors (quantized):")
        for i in range(min(5, len(order))):
            print(f"  {tuple(uniq[order[i]])}  count={cnt[order[i]]}")
