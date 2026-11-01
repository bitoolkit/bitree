# 调色板文件

在「设置 → 外观」中选择「导入调色板」。每个 UTF-8 JSON 文件定义一个适用于浅色或深色模式的配色：

```json
{
  "name": "Mocha",
  "brightness": "dark",
  "base": "#1E1E2E",
  "text": "#CDD6F4",
  "northTeaching": "#89B4FA",
  "wencui": "#A6E3A1",
  "southScience": "#F9E2AF",
  "eastFacilities": "#CBA6F7",
  "southEngineering": "#FAB387",
  "neutral": "#BAC2DE",
  "agenda": "#B4BEFE"
}
```

所有字段均必填。`name` 为非空字符串，`brightness` 只接受 `light` 或 `dark`，所有颜色只接受不透明的 `#RRGGBB` 格式（大小写均可）。`brightness` 表示配色适用的模式，导入文件不会切换应用的明暗模式。

| 字段 | 用途 |
| --- | --- |
| `base` | 课程和普通日程混色的基础色 |
| `text` | 所有这些块的文字颜色 |
| `northTeaching` | 北部教学区课程强调色 |
| `wencui` | 文萃楼课程强调色 |
| `southScience` | 南部理学区课程强调色 |
| `eastFacilities` | 东部设施区课程强调色 |
| `southEngineering` | 南部工学区课程强调色 |
| `neutral` | 无法识别区域的课程强调色 |
| `agenda` | 普通日程及手动 DDL 强调色 |

底色统一为 `base` 向对应强调色混入 24% 的结果，边框使用强调色，文字使用 `text`。浅色配色通常应选择浅基础色、深文字和深强调色，深色配色通常相反。

浅色和深色模式分别保存所选配色。导入成功后自动选中对应模式的配色；应用内保存完整内容，可以移动或删除原文件。导入失败或取消选择文件会保留原选择。每个自定义配色旁有删除按钮；删除正在使用的配色后，该模式恢复为默认。内置配色无法删除。

配色只影响课程和普通日程块；页面背景、全局控件、主页考试和时间轴平台来源色沿用原有规则。启用全局系统调色板且系统提供可用颜色时，系统颜色优先。Android 小组件独立的系统课程配色开关同样具有优先级。
