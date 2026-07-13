# Floating To Do

Floating To Do 是一个原生 macOS 菜单栏浮窗 App。它用于在终端、浏览器、编辑器或 Obsidian 之外快速记录待办，不占用 Dock，并将当前待办单向写入本地 Obsidian Markdown。

它不是 Obsidian 插件本体。当前项目的主体是 Swift 原生 App；`web/` 仅用于验证交互的浏览器原型。

## 当前能力

- 菜单栏左键呼出或隐藏浮窗，鼠标离开后自动收起。
- 全局悬浮，支持多个桌面空间和全屏应用。
- 多便贴页、双击编辑页面标题、快速添加待办。
- 点击完成、双击编辑任务、拖拽抓手排序未完成任务。
- 任务备注入口、完成音效和彩纸反馈。
- 删除后可在 6 秒内撤销。
- 菜单栏右键可复制当前工作区的 Markdown。
- 本地 JSON 保存、最近一次成功数据备份和 Obsidian Markdown 单向同步。

## 运行与安装

开发运行：

```bash
swift build
./.build/debug/FloatingTodo
```

安装原生 App：

```bash
./script/install_swift_app.sh
```

脚本会 release 构建并安装到 `/Applications/FloatingTodo.app`。替换前会核验 Bundle ID `com.cmi.floatingtodo`，旧版本会移入废纸篓备份。

## 数据与 Obsidian 同步

本地数据位于：

```text
~/.floating-todo/todos.json
```

每次成功保存前会保留上一份数据：

```text
~/.floating-todo/todos.json.bak
```

默认 Markdown 输出位置：

```text
/Users/andreas/cmi社区知识库/CMI/Obsidian sticker.md
```

同步为 App 到 Markdown 的单向写入。直接编辑 Markdown 不会回写到 App，也没有冲突合并能力。

若 Obsidian 文件路径不同，可创建：

```text
~/.floating-todo/config.json
```

内容如下：

```json
{
  "obsidianMarkdownPath": "/你的/Obsidian/仓库/Floating Todo.md"
}
```

保存或同步失败时，浮窗顶部会显示数据提醒图标，菜单栏右键菜单会显示具体状态。主数据无法读取时，App 会尝试使用最近一次备份恢复。

## Obsidian Launcher 边界

README 历史上提到过 `floating-todo-launcher`。该 launcher 不在本仓库中，因此不能视为当前项目已交付的一部分。Floating To Do 可独立启动；如需随 Obsidian 启动，应在 launcher 所在项目中单独维护安装方式和路径。

## 开发验证

```bash
swift build
```

当前本机 Command Line Tools 未提供 `XCTest` 或 Swift `Testing` 模块。数据层以一次性同模块验证程序覆盖了删除撤销、Markdown 写入和备份恢复；后续接入完整 Xcode 后，应将这三条验证迁移为正式单元测试。

## License

MIT
