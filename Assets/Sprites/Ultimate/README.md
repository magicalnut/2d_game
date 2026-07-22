# 终极技能素材放置说明

四个专属终极技能的可选美术素材放这里。**不放也能正常运行**（代码会自动回退到现有贴图或程序生成的圆环）；
把对应文件名的 PNG 放进对应子目录后，游戏会自动改用你的素材（无需改代码）。

放入图片后，请让我重新跑一次无头导入校验（或在编辑器里打开一次项目让 Godot 重新导入），素材才会被识别。

命名必须完全一致（英文 ASCII，透明背景 PNG）。

---

## blast/  —— 双枪绝杀（特工）
- `execution_bomb.png`  绝杀爆弹的弹体（一颗醒目的大子弹/能量弹）。建议 128×128。
- `blast.png`           绝杀弹命中时的爆炸光团（圆形，中心亮、边缘淡）。建议 256×256。
  （缺失回退：execution_bomb → 普通子弹贴图；blast → 现有 fire_effect.png）

## rain/  —— 万箭齐发（游侠）
- `big_arrow.png`       从天而降的巨箭（箭头朝右，代码会自动旋转指向下方）。建议 256×256。
- `target_ring.png`     落点预警环（空心圆环，落箭前短暂闪现）。建议 128×128。
- `arrow_splash.png`    箭落地的溅射/冲击效果。建议 128×128。
  （缺失回退：big_arrow → 现有 arrow.png；target_ring → 程序圆环；arrow_splash → 现有 hit.png）

## shockwave/  —— 毁灭重拳（壮汉）
- `shockwave_ring.png`  扩张的环形冲击波（空心圆环，从中心向外扩散）。建议 256×256。
- `big_fist.png`        砸地的巨拳（圆形冲击拳影亦可）。建议 256×256。
  （缺失回退：shockwave_ring → 程序圆环；big_fist → 现有 fist.png）

## thunder/  —— 连锁雷暴（学者）
- `strike.png`          天降落雷的竖直光柱（星芒/尖端在两端，代码会拉伸旋转）。建议 64×512。
- `strike_ring.png`     落雷落点的冲击环（空心圆环）。建议 128×128。
- `arc.png`             敌人之间连锁的电弧光束（细长闪电）。建议 256×64。
  （缺失回退：strike → 现有 bolt.png；strike_ring → 程序圆环；arc → 现有 bolt.png）
