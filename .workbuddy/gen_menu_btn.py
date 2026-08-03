#!/usr/bin/env python3
# Dependency-free RGBA PNG writer -> rounded dark panel for main-menu buttons.
# Chinese label is drawn by a Godot Label on top, so this texture carries no text.
import struct, zlib, math, os

W, H = 280, 72
R = 14.0
FEATHER = 1.5
BORDER_T = 2.5

TOP   = (46, 60, 86)
BOTTOM= (26, 34, 50)
BORDER= (120, 140, 172)
HILITE= (74, 92, 124)

def clamp(v, a, b):
    return max(a, min(b, v))

def smoothstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def sdf(px, py):
    # signed distance to rounded rect centered, negative inside
    cx, cy = W / 2.0, H / 2.0
    qx = abs(px - cx) - (W / 2.0 - R)
    qy = abs(py - cy) - (H / 2.0 - R)
    outside = math.sqrt(max(qx, 0.0) ** 2 + max(qy, 0.0) ** 2)
    inside = min(max(qx, qy), 0.0)
    return outside + inside - R

def build():
    buf = bytearray()
    for y in range(H):
        py = y + 0.5
        t = py / H
        for x in range(W):
            px = x + 0.5
            d = sdf(px, py)
            alpha = 1.0 - smoothstep(-FEATHER, FEATHER, d)
            if alpha <= 0.0:
                buf.extend((0, 0, 0, 0))
                continue
            # vertical gradient fill
            fr = TOP[0] + (BOTTOM[0] - TOP[0]) * t
            fg = TOP[1] + (BOTTOM[1] - TOP[1]) * t
            fb = TOP[2] + (BOTTOM[2] - TOP[2]) * t
            # border ring (outer edge_dist = -d)
            edge_dist = -d
            if edge_dist < BORDER_T:
                bf = 1.0 - edge_dist / BORDER_T
                fr = fr + (BORDER[0] - fr) * bf
                fg = fg + (BORDER[1] - fg) * bf
                fb = fb + (BORDER[2] - fb) * bf
            # subtle top highlight
            if py < H * 0.22:
                hf = (1.0 - py / (H * 0.22)) * 0.45
                fr = fr + (HILITE[0] - fr) * hf
                fg = fg + (HILITE[1] - fg) * hf
                fb = fb + (HILITE[2] - fb) * hf
            buf.extend((int(clamp(fr, 0, 255)), int(clamp(fg, 0, 255)),
                       int(clamp(fb, 0, 255)), int(clamp(alpha * 255, 0, 255))))

    raw = bytearray()
    for y in range(H):
        raw.append(0)  # filter type 0
        raw.extend(buf[y * W * 4:(y + 1) * W * 4])
    comp = zlib.compress(bytes(raw), 9)

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        c += struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff)
        return c

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)  # 8-bit, RGBA
    png = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")
    return png

if __name__ == "__main__":
    out = r"D:\2d_game\Assets\Sprites\UI\Buttons\menu_btn_base.png"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "wb") as f:
        f.write(build())
    print("wrote", out, os.path.getsize(out), "bytes")
