# Lua 展示规则

在 **设置 → 关于 BITree** 中连续点击五次图标，返回设置后打开 **开发者模式 → 自动化**。

可以加载 UTF-8 编码的 `.lua` 文件，也可以直接编辑脚本，点击 **保存并应用**。加载文件后会立即保存并运行脚本；文件内容保存在应用本地，不会继续监听外部文件。关闭 **启用脚本** 可以恢复原始展示。已保存的规则和启用状态会在重启后恢复，开发者入口仍按原有逻辑在每次启动时隐藏。

## 入口

```lua
function filter(data)
    local aliases = {
        ["某个非常长的课程名称"] = "简称",
    }

    for _, course in ipairs(data.courses) do
        course.name = aliases[course.name] or course.name
    end

    local deadlines = {}
    for _, ddl in ipairs(data.deadlines) do
        local ignored =
            ddl.source == "lexue"
            and ddl.course == "某门课程"

        if not ignored then
            ddl.course = aliases[ddl.course] or ddl.course
            table.insert(deadlines, ddl)
        end
    end

    data.deadlines = deadlines
    return data
end
```

脚本必须定义全局函数 `filter(data)`，并返回含有 `courses`、`deadlines`、`events`、`exams` 的 table。这些字段都是从 1 开始、连续编号的数组；即使列表为空也要保留对应 table。删除展示项目时可以构建新数组，也可以设置项目的 `hidden = true`。兼容已有脚本：返回值省略 `events` 或 `exams` 时，保留对应原始列表；显式返回空 table 则隐藏该类全部项目。

`courses` 包含所有已保存学期的课程，`deadlines`、`events`、`exams` 分别包含未删除的 DDL、活动、考试，包括已完成的项目。脚本先处理完整集合，页面再按学期、周次、日期和完成状态筛选。

## 字段

| 课程字段 | 含义 | 可修改 |
| --- | --- | --- |
| `id`、`term` | 原始记录编号、所属学期，二者共同标识课程 | 否 |
| `local` | 是否为用户添加或编辑的课程 | 否 |
| `name`、`teacher` | 课程名、教师 | 是 |
| `room`、`campus` | 教室、校区 | 是 |
| `number`、`description` | 课程编号、描述 | 是 |
| `weekday` | 星期，1–7；未安排时为 nil | 是 |
| `startSection`、`endSection` | 起止节次，未安排时为 nil | 是 |
| `weeks` | 上课周次数组，不含第 0 周 | 是 |

| DDL、活动、考试字段 | 含义 | 可修改 |
| --- | --- | --- |
| `id` | 原始记录编号 | 否 |
| `source` | `lexue`、`eclass`、`mooc`，或无平台来源时为 nil | 否 |
| `kind`、`done`、`deleted`、`term`、`local`、`url`、`details` | 类型、状态和来源元数据 | 否 |
| `title`、`course` | 标题、课程名 | 是 |
| `location`、`notes` | 地点、备注 | 是 |
| `startsAt`、`endsAt`、`allDay` | 开始时间、结束时间、是否全天；DDL 可不填结束时间，活动和考试的结束必须晚于开始 | 是 |

日期使用模型现有的 ISO 8601 字符串格式。时间沿用应用的校园北京时间约定：例如 `2026-09-07T12:00:00.000Z` 表示校园钟表上的 12:00，不要再加 8 小时。修改展示时间会影响页面位置、排序、当天提醒和过期判断。

已有项目保留原始身份和状态字段，不能复制同一编号或将课程移到另一学期。新增展示项时省略 `id`，由应用分配临时编号：课程需要指定已保存的 `term` 和 `name`，可补充星期、节次、周次；日程需要 `title`、`startsAt`，活动与考试还需要 `endsAt`。类型由所在数组决定，不可冒用同步来源或完成状态。新增项目不会进入原始数据，详情可查看，不提供编辑、完成或删除操作；通过修改脚本管理。

```lua
function filter(data)
    table.insert(data.events, {
        title = "复习小组",
        startsAt = "2026-09-07T19:00:00.000Z",
        endsAt = "2026-09-07T20:00:00.000Z",
        location = "图书馆",
    })
    for _, exam in ipairs(data.exams) do
        exam.title = "考试：" .. exam.title
    end
    return data
end
```

运行结果统计全部四类项目相对原始数据的新增、删除、修改数量，仅显示非零项，例如 `2.3ms · 增 1 删 2 改 3`；全部不变时显示 `2.3ms · 无变更`。隐藏和移除都计为删除，修改后隐藏只计一次删除；同一项目无论改多少字段都只计一次修改，新增项只计新增。返回不合法记录时，本次处理整体失败并恢复原始展示。未支持的自定义字段不参与渲染或统计。

## 展示与原始数据

规则作用于应用内首页课表、日程列表和时间线、详情以及首页日程提醒。数量统计使用同一份结果。关闭脚本会恢复被隐藏的记录。

同步、原始数据文件、课表导出、课程编辑器、DDL 编辑器、完成和删除操作使用原始记录。脚本改过名称后再标记完成，不会把显示名称保存回原始记录。Android 桌面小组件使用同一份处理结果，包含课程、DDL、活动和考试的新增、修改与隐藏。小组件的 `widget.json` 仅包含最终展示数据，在脚本、原始数据或所选学期变化时重新生成，应用退出后仍可按日期显示。停用脚本或执行失败时，用原始展示数据重新生成该文件。

## 运行方式

运行库为 [puredartlua](https://pub.dev/packages/puredartlua)。应用注册 `table`、`math`、`pairs`、`ipairs`、`tostring`、`type`、基础类型与元表操作。当前 1.0.16 支持字符串值和 `..` 拼接，但没有 `string` 标准库模块，`string.find`、`string.gsub`、`string.sub` 等函数不可用。`print` 不输出内容，不提供文件、网络、`require`、协程或应用内部对象访问。

每次执行都会创建独立的 Dart isolate 和运行时，从原始数据快照重新计算，不保留上次执行的 Lua 全局变量。脚本或原始数据变化时自动重算，单纯切换周次不会重复执行。

脚本限制为 128 KiB，每次执行限时 2 秒，超时会终止工作 isolate。返回数据另有字段类型、大小与深度检查。puredartlua 使用 Dart 内存管理，这些限制不等于独立的 Lua 堆内存配额。运行错误、超时和校验失败会在自动化页面显示，应用回退到原始展示。
