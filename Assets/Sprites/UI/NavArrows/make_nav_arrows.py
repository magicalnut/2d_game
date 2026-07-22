import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
LEFT = os.path.join(HERE, "nav_arrow_left.png")
RIGHT = os.path.join(HERE, "nav_arrow_right.png")

TARGET = (118, 118)  # 显示用固定尺寸（初版 64px 的约 1.84 倍；源图 384 下采样到 118 仍清晰）


def make_placeholder():
    """占位图（仅当左图不存在时生成）：圆角药丸 + 白色左箭头。"""
    W, H = 128, 128
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 8
    d.rounded_rectangle([pad, pad, W - pad, H - pad], radius=26,
                        fill=(38, 70, 110, 210), outline=(110, 200, 255, 230), width=4)
    cx, cy = W * 0.56, H * 0.5
    s = 40
    d.polygon([(cx + s, cy - s), (cx - s * 0.2, cy), (cx + s, cy + s)], fill=(255, 255, 255, 255))
    d.rectangle([cx - s * 0.2, cy - 8, cx + s * 0.35, cy + 8], fill=(255, 255, 255, 255))
    img = img.resize(TARGET, Image.LANCZOS)
    img.save(LEFT)
    print("placeholder ->", LEFT)


def resize_left():
    im = Image.open(LEFT).convert("RGBA")
    im = im.resize(TARGET, Image.LANCZOS)
    im.save(LEFT)
    print("resized left ->", LEFT, im.size)


def flip():
    im = Image.open(LEFT).convert("RGBA")
    im.transpose(Image.FLIP_LEFT_RIGHT).save(RIGHT)
    print("flipped     ->", RIGHT, im.size)


if __name__ == "__main__":
    if not os.path.exists(LEFT):
        make_placeholder()
    else:
        resize_left()
    flip()
