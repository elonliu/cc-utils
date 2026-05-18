---
name: taskloop
description: >
  Task queue and continuous execution loop for Claude Code. Use this skill whenever
  the user wants to manage multiple tasks, create a task queue, add/remove tasks,
  track task progress, or auto-execute tasks one by one. Triggers: "add task",
  "task queue", "start loop", "taskloop", "/taskloop", "任务队列", "执行任务",
  "添加任务", "任务列表", "看板", "kanban", "task board", "task management",
  "任务管理", "批量执行", "连续执行", or when the user mentions wanting to organize
  work into a queue, track multiple items, or run tasks sequentially. Also use when
  the user wants a visual task board (TUI or HTML) to drag-and-drop tasks between
  columns. If the user mentions anything about organizing work, managing todos, or
  automating a sequence of tasks, use this skill.
---

# Taskloop — 任务队列与连续执行
## 概述

管理任务队列并在 Claude Code 中自动循环执行。支持两种视图：TUI（终端）和 HTML（浏览器）。

## 数据源

所有任务存储在 Claude Code 原生 Task 系统中，通过 `metadata.taskloop: true` 标记过滤。
JSON 导出文件：`taskloop-data.json`（位于当前工作目录）。

## 命令接口

### 添加任务

用户说"添加任务：标题"或"添加任务：标题 --type bug --priority high"时：
1. 解析标题、`--type`（bug/feature）、`--priority`（high/medium/low）
2. 调用 `TaskCreate` 创建任务，设置：
   - `subject`: 标题
   - `description`: 描述（用户提供时）
   - `metadata`: `{ "taskloop": true, "type": "...", "priority": "..." }`
3. 刷新 `taskloop-data.json`（调用 `TaskList` → 导出 JSON）
4. 确认添加，显示当前队列数量

### 查看任务队列

用户说"任务队列"或"task queue"时：
1. 调用 `TaskList` 获取所有 taskloop 任务
2. 导出为 `taskloop-data.json`
3. 默认展示 TUI 视图（见下方）

用户说"任务队列 --html"时：
1. 导出 `taskloop-data.json`
2. 启动 HTTP 服务器：`python <skill_dir>/scripts/server.py --dir <skill_dir>/assets --port 8765`
   （`<skill_dir>` 为 SKILL.md 所在目录）
3. 浏览器打开 `http://127.0.0.1:8765`（或使用 `open` / `xdg-open` 命令）

### 同步任务变更

用户说"同步任务变更"时：
1. 读取 `taskloop-data.json`
2. 对比 Task 系统中对应任务的差异
3. 调用 `TaskUpdate` 同步变更（subject、description、metadata）
4. 确认同步结果

### 开始执行任务队列

用户说"开始执行"或"start loop"时：
1. 检查是否有 `in_progress` + `locked` 的任务（中断恢复）
2. 如果有 `failed` + `locked` 的任务，向用户报告失败任务并询问是否重试
3. 如果没有，找到首个 `pending` 任务
4. **锁定**：`TaskUpdate(id, metadata.locked=true, metadata.locked_at=now)`
5. 导出更新后的 `taskloop-data.json`
6. `TaskUpdate(id, status=in_progress)`
7. 执行该任务（正常开发流程）
8. 完成后：`TaskUpdate(id, status=completed, metadata.locked=false)`
9. 调用 `ScheduleWakeup({ prompt: "从任务队列取下一个 pending 任务并执行。如果队列为空，报告'所有任务已完成'。", delaySeconds: 5, reason: "taskloop 执行下一个任务" })`

### 暂停

用户说"暂停"时：
1. 不调用 ScheduleWakeup
2. 当前 `in_progress` 任务保持锁定状态

### 删除任务

用户说"删除任务 #N"时：
1. `TaskUpdate(id="N", status=deleted)`
2. 刷新 `taskloop-data.json`

## 输出格式

每次用户交互后，使用以下固定格式回复，确保一致性：

### 添加任务
```
✅ 已添加任务: [标题]
   类型: [bug/feature/未设置]  优先级: [high/medium/low/未设置]
📋 当前队列: pending=N, in_progress=N, completed=N (共N个)
```

### 查看任务队列
```
📋 任务队列 (共N个):

⏳ Pending (N个):
  #1 [标题] [类型] [优先级]
  #2 [标题]

🔄 In Progress (N个):
  #3 [标题]

✅ Completed (N个):
  #4 [标题]
```

### 开始执行
```
🚀 开始执行任务队列
▶️ 正在执行: #[ID] [标题] (已锁定)
完成后将自动执行下一个任务...
```

### 暂停
```
⏸️ 任务队列已暂停
当前任务 #[ID] [标题] 保持锁定状态
发送"开始执行"以继续
```

### 删除任务
```
🗑️ 已删除任务: #[ID] [标题]
📋 剩余队列: pending=N, in_progress=N, completed=N (共N个)
```

### 同步任务变更
```
🔄 同步完成: 更新了N个任务
  - #[ID] [标题]: [变更内容]
```

### 任务完成
```
✅ 任务完成: #[ID] [标题]
   耗时: [时间]
📋 剩余: pending=N 个任务
```

## TUI 视图

使用 `scripts/tui.sh` 脚本（需要 `fzf` 和 `jq`）：
```bash
bash <skill_dir>/scripts/tui.sh list
```

快捷键：Enter 选择 | q 退出

## HTML 视图

使用 `scripts/server.py` 启动本地 HTTP 服务器：
```bash
python <skill_dir>/scripts/server.py --dir <skill_dir>/assets --port 8765
```

`<skill_dir>` 为 SKILL.md 所在目录。

服务器提供：
- `GET /` — HTML 页面
- `GET /api/tasks` — 返回 JSON 数据
- `POST /api/tasks` — 接收编辑后的数据并写入

## 锁定机制

任务执行前必须锁定：
- `metadata.locked = true` — 标记为锁定
- HTML 视图中锁定的任务灰显且不可编辑
- TUI 视图中锁定的任务显示 `[🔒]` 标记
- 执行完成后解锁并标记为 completed
- 失败任务（`status=failed`）保持锁定，供用户检查；用户可手动重试（解锁 + 设回 pending）或删除

## 边界处理

- **任务执行失败**：标记 `status=failed`（不标记 completed），subject 加 `[FAILED]` 前缀，description 追加失败原因。任务保持锁定状态，用户可以选择：
  - 重试：解锁并设置 `status=pending`
  - 删除：`TaskUpdate(id, status=deleted)`
- **中断恢复**：检查 `in_progress` + `locked` 任务，从断点继续；同时检查 `failed` + `locked` 任务并向用户报告
- **端口冲突**：server.py 自动递增端口（8765→8766→8767）

## 文件路径

所有脚本和资源路径相对于 SKILL.md 所在目录（`<skill_dir>`）。
在 Claude Code 中，可以通过 skill 上下文自动定位 skill 目录，无需写死绝对路径或安装路径。

例如：
- HTTP 服务器：`<skill_dir>/scripts/server.py`
- TUI 脚本：`<skill_dir>/scripts/tui.sh`
- HTML 模板：`<skill_dir>/assets/template.html`

安装到 Claude Code：将 `taskloop/` 目录软链接或复制到 `~/.claude/plugins/local/taskloop/`，或放在项目根目录下作为 local plugin。
