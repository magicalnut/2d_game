# 美术资源丢图位置对照表

> 用法：
> - **静态图**（背景 / 拾取物 / 火焰 / 敌弹 / 技能图标 / UI 图）= 保持表里写的**文件名**直接覆盖，进游戏立即生效，无需改代码。
> - **精灵表**（玩家 / 敌人 / BOSS）= 放好图后**告诉我**文件名、每张表几帧、怎么排列（横排/分文件），由我把帧配进对应 `.tscn` 的 `sprite_frames`，你不用动 Godot。
> - 所有文件名统一用**英文 ASCII**，避免中文路径 `preload` 编码坑。
> - 代码要求的角色动画名固定为：`idle` / `left` / `right` / `toward`(朝下) / `back`(朝上)；敌人额外需要 `death`。

---

## A. 角色与敌人（精灵表，需配帧）

| 资源 | 放置路径 | 建议文件名 | 类型 | 动画/帧 | 大概样子 | 状态 |
|---|---|---|---|---|---|---|
| 玩家/流浪者(默认英雄) | `Assets/Sprites/Heroes/wanderer/sheet.png` | `sheet.png` | 精灵表 | 见各英雄 README(228×300,3列×4行,76×75) | 俯视小英雄，单帧48~64px，朝下可见头顶 | ⭐待替换(现占位图)；战斗内玩家单位场景在 `Scenes/player.tscn` |
| 狐狸 Fox | `Assets/Sprites/Enemies/Fox/` | `fox_sheet.png` | 精灵表 | idle + 四向 + death | 小体型、跑得欢的狐狸(脆皮海) | 待替换 |
| 特工 Agent | `Assets/Sprites/Enemies/Agent/` | `agent_sheet.png` | 精灵表 | idle + 四向 + death | 远程单位，可持枪/法杖，区别于狐狸 | 待替换 |
| 壮汉 Mario | `Assets/Sprites/Enemies/Mario/` | `mario_sheet.png` | 精灵表 | idle + 四向 + death | 大体型笨重近战 | 待替换 |
| 重甲 Armored | `Assets/Sprites/Enemies/ArmoredPerson/` | `armored_sheet.png` | 精灵表 | idle + 四向 + death | 厚重装甲兵 | 待替换 |
| BOSS | `Assets/Sprites/Bosses/` | `boss_sheet.png` | 精灵表 | idle + 四向 + death/attack | 体型明显大于小兵，可带光环/大武器 | 🆕新增(现复用重甲放大) |

> 注：现有 `Fox/fox.tscn`、`Agent/agent.tscn`、`Mario/mario.tscn`、`Armored Person/armored_person.tscn` 是 WaveManager 实际刷怪用的场景；给图后我会把这些 `.tscn` 里的 `AnimatedSprite2D.sprite_frames` 指向新精灵表。

---

## B. 武器与弹体

| 资源 | 放置路径 | 文件名 | 类型 | 大概样子 | 状态 |
|---|---|---|---|---|---|
| 无人机 | `Assets/Sprites/Skills/` | `active_drone.png` | 静态 | 悬浮无人机 | 存在·可美化 |
| 燃烧瓶 | `Assets/Sprites/Skills/` | `active_firebomb.png` | 静态 | 燃烧瓶 | 存在·可美化 |
| 篮球 | `Assets/Sprites/Skills/` | `active_basketball.png` | 静态 | 篮球 | 存在·可美化 |
| 魔法书弹 | `Assets/Sprites/Skills/` | `active_book.png` / `star_bullet.png` | 静态 | 书/星弹 | 存在·可美化 |
| 专用弹体(可选) | `Assets/Sprites/Weapons/` | `laser.png` `firebomb.png` `basketball.png` `star.png` 等 | 静态·新建 | 独立飞行弹体(替代复用图标) | 🆕可选，需我改 `active_weapon.gd` 的 tex 指向 |
| 敌方子弹 | `Assets/Sprites/Weapons/Bullet/` | `EnemyBullet.png` | 静态 | 小圆弹/能量弹，青或红，16px | 存在·可替换 |

---

## C. 拾取物（覆盖即用）

| 资源 | 放置路径 | 文件名 | 大概样子 | 状态 |
|---|---|---|---|---|
| 经验球 | `Assets/Sprites/Pickups/` | `exp_orb.png` | 发光小宝石/星点，16~24px | 存在·可替换 |
| 血瓶 | `Assets/Sprites/Pickups/` | `health_bottle.png` | 红心/血瓶，24px | 存在·可替换 |

---

## D. 环境与特效

| 资源 | 放置路径 | 文件名 | 类型 | 大概样子 | 状态 |
|---|---|---|---|---|---|
| 战斗背景 | `Assets/Sprites/Backgrounds/` | `battle_bg.png` | 静态(5120×2880) | 废墟地牢俯视，暗色调不抢角色 | 存在·可重画 |
| 火焰特效 | `Assets/Sprites/Effects/` | `fire_effect.png` | 静态(64px,半透明) | 橙红火团，会缩放闪烁 | 存在·可替换 |
| 受击火花(可选) | `Assets/Sprites/Effects/` | `hit.png` | 静态·新建 | 小爆点 | 🆕可选 |
| 死亡烟尘(可选) | `Assets/Sprites/Effects/` | `poof.png` | 静态·新建 | 烟/碎屑 | 🆕可选 |
| 升级闪光(可选) | `Assets/Sprites/Effects/` | `levelup.png` | 静态·新建 | 光圈/星芒 | 🆕可选 |

---

## E. 界面 UI（当前全代码画，缺口最大）

| 资源 | 放置路径 | 建议文件名 | 类型 | 大概样子 | 状态 |
|---|---|---|---|---|---|
| 主菜单背景 | `Assets/Sprites/UI/` | `menu_bg.png` | 静态(1920×1080) | 暗色氛围图 | 🆕新增 |
| HUD 外框 | `Assets/Sprites/UI/` | `hud_frame.png` | 静态·新建 | 屏幕四周装饰框 | 🆕新增 |
| 血条底/填充 | `Assets/Sprites/UI/` | `hp_frame.png` `hp_fill.png` | 静态·新建 | 红血条 | 🆕新增 |
| 经验条底/填充 | `Assets/Sprites/UI/` | `xp_frame.png` `xp_fill.png` | 静态·新建 | 经验条 | 🆕新增 |
| 升级卡底 | `Assets/Sprites/UI/` | `card_bg.png` | 静态(216×264圆角) | 卡片底图 | 🆕新增 |
| 暂停底 | `Assets/Sprites/UI/` | `pause_bg.png` | 静态·新建 | 半透明遮罩 | 🆕新增 |
| 结算底 | `Assets/Sprites/UI/` | `gameover_bg.png` | 静态·新建 | 半透明遮罩+标题位 | 🆕新增 |

---

## F. 技能 / 被动图标（升级卡 & 特殊技能）

| 资源 | 放置路径 | 文件名 | 状态 |
|---|---|---|---|
| 球鞋/吸铁石/书籍/股票(被动) | `Assets/Sprites/Skills/` | `passive_shoe.png` `passive_magnet.png` `passive_book.png` `passive_stock.png` | 存在·可美化 |
| 无人机/燃烧瓶/篮球/魔法书(主动) | `Assets/Sprites/Skills/` | `active_drone.png` `active_firebomb.png` `active_basketball.png` `active_book.png` | 存在·可美化 |
| 守护圣盾/时空沙漏/雷电法杖(特殊) | `Assets/Sprites/Skills/` | `special_shield.png` `special_hourglass.png` `special_thunder.png` | 存在·图标占位(逻辑TODO未实装) |
| 超武图标 ×5 | `Assets/Sprites/Skills/` | `super_*.png` | 存在·超武已移除，可删可不删 |

---

## 优先级建议
1. **玩家 + 4 敌人精灵表**（主体，一眼可见）
2. **背景 + 拾取物 + 火焰 + 敌弹**（静态图，覆盖即用，零接线）
3. **UI 背景与卡底**（决定"成不成熟"的观感）
4. BOSS 专属图、武器专用弹体、特效（锦上添花）

> 给图后，把"放哪个路径 + 文件名 + 帧数/排列"告诉我，我负责接线到游戏里。
