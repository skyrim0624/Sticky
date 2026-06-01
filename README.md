# Obsidian-sticker

**Obsidian-sticker** 是一款深度集成在桌面环境与 Obsidian 中的原生极简待办事项（To-Do）悬浮应用。

## 🌟 核心理念与简介

这个项目的核心目的是**方便我们在 `agent-obsidian` 体系下，以最轻量化的方式记录“待办事项”。**
我们经常身处不同的上下文环境中（如终端、浏览器、或其他代码编辑器），传统的 Obsidian 笔记切换需要破坏当前的心流（Flow）。

Obsidian-sticker 以一个常驻在 macOS 全局悬浮窗的形式出现，采用了顶级克制留白设计（Things 3 Vibe）。
它能够确保待办事项以最“原生、通透、且不干扰视线”的形态常驻桌面，让你随时记录灵感或任务，同时它的底层依然能够轻松连击你的本地 Obsidian 的工作流进行同步。

## 🎯 亮点特性 (Features)
- 极致原生材质：硬编码亮色模式，纯白高透底漆搭配 `.ultraThinMaterial`，永远保持雪白晶莹的高级质感。
- 轻量级交互：丝滑的连线删除小动画、1px 细边的打勾提示，没有花哨的功能，只有不可或缺的纯白描极简。
- Obsidian 插件集成：配合 `floating-todo-launcher` 插件随 Obsidian 一同静默启动。不会污染 Dock 栏，只会成为桌面右侧不显眼却至关重要的便利贴（Sticker）。

## ⚙️ 编译运行 (Installation)

本项目基于 Swift 构建：
```bash
git clone https://github.com/LovIce4ev/Obsidian-sticker.git
cd Obsidian-sticker
swift build
./.build/debug/FloatingTodo
```
为了实现随 Obsidian 一起启动，您可以配置相关的 Obsidian 本地 Plugin (如上文提供的 JS launcher 代码即可)。

## 📦 打包安装原生 macOS App

```bash
./script/install_swift_app.sh
```

这个脚本只打包 Swift 原生版：会先 release 构建，再生成 `dist/FloatingTodo.app`，替换 `/Applications/FloatingTodo.app` 前会校验目标 bundle id 必须是 `com.cmi.floatingtodo`，旧版本会移动到废纸篓备份。

## License
MIT
