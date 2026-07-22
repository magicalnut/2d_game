import base64
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BG = os.path.join(HERE, "backgrounds")

themes = [
    ("stone_dungeon", "Stone Dungeon · 石牢",
     "灰白石砖地板 + 规整石墙，带零星装饰与石柱。整体偏明亮、规整，像城堡地牢。"),
    ("cave", "Cave · 洞窟",
     "泥土/岩石质感地板，墙体更自然不规则，偶有水晶点缀。氛围更接近自然洞穴。"),
    ("dark_dungeon", "Dark Dungeon · 暗牢",
     "深灰近黑墙体，地板低对比，阴森压抑。适合恐怖/潜行基调。"),
    ("ruins", "Ruins · 废墟",
     "破碎石柱与瓦砾散布，墙体斑驳。营造古老遗迹、坍塌地宫的感觉。"),
]

cards = []
for key, title, desc in themes:
    path = os.path.join(BG, f"preview_{key}.png")
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    cards.append(f"""
    <div class="card">
      <div class="thumb"><img src="data:image/png;base64,{b64}" alt="{title}"></div>
      <div class="meta">
        <h2>{title}</h2>
        <p class="dim">分辨率 2560 × 1440（预览图 1280 × 720）· CC0 授权</p>
        <p>{desc}</p>
        <p class="file">文件名：<code>{key}.png</code></p>
      </div>
    </div>""")

html = f"""<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>地牢背景候选画廊</title>
<style>
  :root {{ --bg:#1c1c22; --card:#26262e; --line:#3a3a44; --txt:#e8e8ec; --dim:#9aa0aa; --accent:#7cc4ff; }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--txt);
         font-family:-apple-system,"Segoe UI",Roboto,"PingFang SC","Microsoft YaHei",sans-serif; }}
  header {{ padding:24px 28px 8px; }}
  header h1 {{ margin:0 0 6px; font-size:22px; }}
  header p {{ margin:0; color:var(--dim); font-size:14px; }}
  .grid {{ display:grid; grid-template-columns:repeat(2,1fr); gap:18px; padding:18px 28px 40px; }}
  .card {{ background:var(--card); border:1px solid var(--line); border-radius:12px;
          overflow:hidden; display:flex; flex-direction:column; }}
  .thumb img {{ display:block; width:100%; height:auto; image-rendering:pixelated; }}
  .meta {{ padding:14px 16px 16px; }}
  .meta h2 {{ margin:0 0 6px; font-size:17px; }}
  .meta p {{ margin:6px 0 0; font-size:13px; line-height:1.5; }}
  .dim {{ color:var(--dim); }}
  .file code {{ color:var(--accent); background:#1b2733; padding:1px 6px; border-radius:4px; }}
  footer {{ padding:0 28px 30px; color:var(--dim); font-size:12px; }}
  @media (max-width:760px) {{ .grid {{ grid-template-columns:1fr; }} }}
</style>
</head>
<body>
<header>
  <h1>地牢像素背景 · 候选画廊</h1>
  <p>4 张均为 2560×1440 大图（约 16:9），由 Kenney Roguelike Caves & Dungeons 瓦片包（CC0）拼接生成。请选择其中一张作为主场景背景，选定后由我负责插入 Godot 场景并实现「画面中心跟随人物移动」。</p>
</header>
<div class="grid">
{''.join(cards)}
</div>
<footer>提示：在对话框里回复你选中的主题名（stone_dungeon / cave / dark_dungeon / ruins）即可。若都不满意，我可重新生成其他配色或更大尺寸。</footer>
</body>
</html>"""

out = os.path.join(BG, "gallery.html")
with open(out, "w", encoding="utf-8") as f:
    f.write(html)
print("written:", out, os.path.getsize(out), "bytes")
