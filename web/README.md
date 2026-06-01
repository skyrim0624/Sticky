# Floating Todo Web

浏览器测试版用于先验证任务体验、完成反馈和交互节奏。Electron 阶段再接菜单栏、悬浮窗、置顶、文件同步等桌面能力。

## 运行

```bash
npm install
npm run dev
```

默认地址：

```text
http://127.0.0.1:5173/
```

## 当前范围

- [x] 添加、删除、完成、取消完成
- [x] 完成任务后的彩纸动效
- [x] 完成任务后的本地成功音效
- [x] 备注展开与编辑
- [x] 未完成任务拖拽排序
- [x] 浏览器本地保存
- [x] 复制 / 下载 Markdown

## 音效来源

- `public/sounds/task-complete-success.mp3`
- 来源：[OpenGameArt - Basic Sound Effects](https://opengameart.org/content/basic-sound-effects)
- 作者：n4
- 文件：`success.mp3`
- 许可：CC0

## 暂不放进 Web 版

- macOS 菜单栏图标
- 原生悬浮窗与置顶
- 离开鼠标自动隐藏
- 直接写入 Obsidian 文件

这些能力留到 Electron 封装阶段处理，避免浏览器原型被桌面权限细节拖慢。
