# Taskloop

Claude Code 的会话内任务队列与连续执行插件。随时添加任务，AI 自动逐个开发直到完成。

## 功能

- **随时添加任务** — 自然语言描述即可，支持类型和优先级
- **双视图管理** — 终端 TUI（fzf）或浏览器看板（拖拽排序、实时编辑）
- **连续自动执行** — AI 自动从队列取任务逐个开发，无需手动触发
- **任务锁定** — 开发中的任务自动锁定，防止并发编辑冲突

## 安装

### 通过 Marketplace 安装（推荐）

在 Claude Code 中执行：

```bash
claude plugins add-marketplace elonliu/cc-utils
claude plugins install taskloop@elonliu
```

重启 Claude Code 即可使用。

### 手动安装

```bash
git clone git@github.com:elonliu/cc-utils.git ~/.claude/plugins/local/taskloop
```

然后在 `~/.claude/settings.json` 中启用：

```json
{
  "enabledPlugins": {
    "taskloop@local": true
  }
}
```

## 使用方法

### 添加任务

```
添加任务：修复登录页面空白问题
添加任务：支持 OAuth 登录 --type feature --priority high
```

### 查看任务

| 命令 | 效果 |
|------|------|
| `任务队列` | 终端 TUI 视图（fzf 交互） |
| `任务队列 --html` | 浏览器打开看板（可拖拽排序、编辑） |
| `同步任务变更` | 将 HTML 视图中的修改同步回 Task 系统 |

### 执行任务

| 命令 | 效果 |
|------|------|
| `开始执行` | 从队列取首个 pending 任务开始开发 |
| `暂停` | 暂停自动循环，当前任务保持锁定 |

### 管理任务

| 命令 | 效果 |
|------|------|
| `删除任务 #N` | 从队列删除指定任务 |
| `调整任务 #3 到 #1` | 调整任务执行顺序 |

## 任务参数

| 参数 | 说明 | 可选值 |
|------|------|--------|
| `--type` | 任务类型 | `bug`, `feature` |
| `--priority` | 优先级 | `high`, `medium`, `low` |

示例：`添加任务：修复登录 bug --type bug --priority high`

## 浏览器看板

通过 `任务队列 --html` 打开后：

- **拖拽排序**：拖拽卡片调整执行顺序，跨栏拖拽变更状态
- **双击编辑**：双击卡片打开编辑弹窗
- **自动保存**：变更后自动同步到本地服务器
- **锁定显示**：开发中的任务灰显且不可操作
- **离线降级**：服务器不可用时可导出 JSON 手动同步

## 架构

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Claude Code │────▶│  Task 系统       │◀────│ HTML 看板       │
│ Task Tools  │     │ (metadata 标记)  │     │ (浏览器)        │
└─────────────┘     └────────┬─────────┘     └────────┬────────┘
                             │                        │
                             ▼                        ▼
                      taskloop-data.json ◀──▶ HTTP 服务器 (8765)
```

## 文件结构

```
cc-utils/
├── .claude-plugin/plugin.json       # 插件元信息
├── skills/taskloop/
│   ├── SKILL.md                     # 技能定义
│   ├── scripts/
│   │   ├── server.py                # HTTP 服务器（数据桥）
│   │   └── tui.sh                   # TUI 脚本（fzf）
│   └── assets/
│       └── template.html            # HTML 看板模板
├── README.md
└── LICENSE
```
