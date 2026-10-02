# 黑客帝国风格的贪吃蛇

> 蛇身是数据字符，在终端里清除恶意数据包。

一个用 [Godot](https://godotengine.org) 4.7 + GDScript 做的终端风格贪吃蛇。整个棋盘是一块 CRT 屏幕，蛇身由随机十六进制字符和片假名组成，在网格上爬行、吞噬数据包；背景是 Matrix 数字雨，屏幕叠加扫描线、噪点、闪烁与暗角。

纯 `_draw()` 实现，没有任何美术资源文件 —— 所有视觉都由代码逐帧绘制，只依赖系统等宽字体。

![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-4.x-355570)
![License](https://img.shields.io/badge/license-MIT-blue)

## 玩法

| 操作 | 按键 |
| --- | --- |
| 移动 | `W` `A` `S` `D` / 方向键 |
| 开始 / 重开 | 任意键 |

终端术语包装：

- **SCORE** —— 得分，每包 +10
- **KILLS** —— 已清除的数据包数
- 蛇头是 `@`，数据包是 `$`
- 撞击后整条蛇变红闪烁，屏幕报`[ERR] segfault at 0x...`

## 运行

需要 Godot **4.7+**（4.x 线内）。

```bash
git clone https://github.com/DBinK/snake_case.git
cd snake_case
godot scenes/main.tscn
```

或用 Godot 编辑器打开项目目录后按 `F5`。

### 依赖说明

字体走 `SystemFont`，按 `Menlo → Consolas → Courier New → monospace` 顺序回退，**无需安装任何字体资源**。蛇身用到片假名字符，在没有日文字体的环境下会显示为豆腐块，但不影响玩法 —— 想彻底解决可以给 `scripts/mono_font.gd` 的 `font_names` 补一个 CJK 等宽字体。

## 结构

```
scenes/main.tscn      极简场景，只挂一个 Node2D
scripts/
  main.gd             外壳：背景雨、棋盘、CRT 叠加层、命令行 HUD
  snake_game.gd       核心玩法：网格、蛇、食物、碰撞、计分、冲击波
  matrix_rain.gd      背景数字雨
  crt_overlay.gd      扫描线 / 噪点 / 闪烁 / 暗角叠加层
  mono_font.gd        等宽字体统一入口
addons/godot_ai/      Godot AI MCP 插件（见下）
```

`main.gd` 用 `preload` 挂载三个子节点，通过信号 `score_changed` / `game_over` / `game_started` / `cell_eaten` 与 `snake_game.gd` 通信 —— 玩法逻辑与视觉外壳是解耦的，HUD 只订阅信号、不反写状态。

## 实现细节

**速度曲线** —— 起始 5 格/秒，每吃一个包乘以 0.95，下限 13 格/秒。

**冲击波** —— 吃掉数据包时，以该格为圆心扩散一圈字符。用切比雪夫距离算出方形波前（`max(|dx|, |dy|)`），前缘洋红、尾迹红色，`ease(progress, 0.6)` 做缓出，0.55 秒后消失。所有字符严格落在格子中心、字号与棋盘一致，所以看起来是棋盘本身被点亮了，而不是浮在上面。

**噪声层** —— 每个空格固定一个残留字符，亮度按 `sin` 轻微呼吸，模拟屏幕残留数据。

**布局** —— 棋盘水平居中，垂直方向夹在标题区（110px）和提示区（80px）之间；窗口尺寸变化时重新布局。

## Godot AI MCP

项目自带 [Godot AI](https://github.com/hi-godot/godot-ai) v4.2.3 插件（MIT），把编辑器接给 AI 编码助手，让它直接读写场景树、改属性、跑测试。

启用：编辑器内 **项目 → 项目设置 → 插件 → Godot AI**，然后在 **Godot AI** dock 点 **Configure** 写入你的 MCP 客户端配置。

> `addons/` 目录已随仓库提交，所以 clone 下来即可直接用。如果不想带上，可在 `.gitignore` 里加 `/addons/` 后自行安装。

## 许可

代码采用 MIT 许可。`addons/godot_ai/` 为第三方插件，遵循其自带的 MIT 许可。