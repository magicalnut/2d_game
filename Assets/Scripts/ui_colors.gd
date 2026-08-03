# 语义化文字配色（class_name 全局可用，无需注册 Autoload）
#
# 仅允许使用以下四种颜色（用户规定），颜色只表示「层级」，不再用颜色区分好坏/导航语义：
#   GOLD   标题 / 角色名 / 关卡名 / 分区小标题 / 主行动按钮（确认出战·继续游戏）/ 强调状态（已通关·胜利）
#   WHITE  正文 / 数值 / 名称 / 普通按钮（返回·重开·重选·返回战备·返回主菜单）
#   GRAY   次要说明 / 描述 / 提示 / 资源信息文字
#   MUTED  禁用 / 空槽 / 未解锁 / 弱提示
class_name UIColors

const GOLD   := Color(1.00, 0.90, 0.60)
const WHITE  := Color(0.93, 0.95, 0.99)
const GRAY   := Color(0.80, 0.84, 0.92)
const MUTED  := Color(0.55, 0.60, 0.70)
