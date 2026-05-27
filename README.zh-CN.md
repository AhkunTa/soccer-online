# Soccer Online

`Soccer Online` 是一个基于 Godot 4.6 的 2D 像素风街机足球项目，源自 [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course)。当前目标是复刻小队制街机足球的手感：身体对抗、铲球抢断、必杀射门、场地与天气影响、本地对战、锦标赛和在线比赛。

简体中文 -  [English](./README.md)


## 项目状态

- 引擎：Godot 4.6，GL Compatibility 渲染
- 语言：GDScript
- 主场景：`scenes/soccer_game.tscn`
- 原生分辨率：`280x180`，整数缩放
- 本地模式：单人对 AI、本地双人、锦标赛
- 在线模式：大厅、房间、队伍选择、输入快照、世界快照同步已具备基础，仍在持续完善

## 功能特性

- **6 人制足球**：每队 6 名球员，包含守门员、后卫、中场和前锋。
- **9 支国家队**：法国、阿根廷、巴西、英格兰、德国、意大利、西班牙、美国和加拿大。
- **街机动作**：移动、传球、蓄力射门、铲球、跳跃、头球、凌空、倒钩和胸停。
- **必杀射门**：普通、强力、上升、弧线、隐形、跳跃、画笔轨迹、鱼跃、太极、双子等。
- **球员状态机**：移动、铲球、跳跃、射门、受伤、庆祝、重置等状态独立处理。
- **按位置分工的 AI**：守门员、后卫、中场和前锋使用不同的行为逻辑。
- **场地与天气基础**：已有 `FieldCondition`、天气粒子和场地贴片系统，用于速度、摩擦、滑倒和球路影响。
- **锦标赛模式**：本地 bracket 流程，支持晋级和冠军显示。
- **在线房间**：基于 ENet 的房间列表、创建/加入房间、队伍与位置选择、比赛加载同步。

## 操作方式

| 动作 | 玩家 1 | 玩家 2 |
| --- | --- | --- |
| 移动 | `W` `A` `S` `D` | 方向键 |
| 传球 | `J` | `[` |
| 射门 / 确认 | `K` | `]` |
| 跳跃 | `Space` 或 `J + K` | `Insert` 或 `[ + ]` |
| 铲球 | 移动中按射门 | 移动中按射门 |

提示：

- 按住射门可蓄力。当力量达到阈值且球员面向球门时，可触发配置好的必杀射门。
- 无球时按传球可切换球员或请求队友配合。
- 空中球的时机判断可触发头球、凌空、倒钩等空中动作。

## 快速开始

1. 安装 Godot 4.6 或更高版本。
2. 在 Godot 中打开仓库根目录下的 `project.godot`。
3. 按 `F5` 运行主场景。
4. 按 `F6` 可单独运行当前打开的场景，便于调试。

## 在线对战

项目使用 Godot 内置的 `ENetMultiplayerPeer`，默认端口为 `7000`。

满足以下任一条件时，会自动进入专用服务端模式：

- 使用 `--headless` 无头运行
- 使用 `--server` 命令行参数运行
- 使用 Godot 特性标签 `server` 运行

典型流程：

1. 启动一个服务端实例。
2. 打开客户端，进入在线模式并连接服务端 IP。
3. 创建或加入房间。
4. 在在线队伍选择界面选择队伍和位置。
5. 所有玩家准备完成后，加载比赛场景并开始比赛。

## 项目结构

```text
.
├── assets/                  # 美术、字体、队伍数据、音乐、音效
│   ├── art/                 # 像素素材、UI、球场、球员、国家旗帜
│   ├── fonts/               # Daydream、Pixeled
│   ├── json/                # squads_en.json / squads_zh.json
│   ├── music/               # 菜单、比赛、锦标赛、胜利音乐
│   └── sfx/                 # 射门、传球、铲球、UI 和比赛音效
├── docs/                    # 中文设计文档和实施计划
├── resources/               # 自定义 Resource，例如球员和场地条件
├── scenes/
│   ├── audio/               # AudioPlayer、MusicPlayer
│   ├── ball/                # 足球实体、球状态机、必杀球状态
│   ├── characters/          # 球员实体、球员状态机、AI 行为
│   ├── game_manager/        # 比赛状态机、比分、时间、开球、比赛结束
│   ├── network/             # RoomManager、SyncManager、在线数据流
│   ├── screens/             # 主菜单、队伍选择、在线大厅、锦标赛、比赛世界
│   └── ui/                  # HUD 和主题资源
├── shaders/                 # 替色、环境遮罩等 shader
├── utils/                   # 数据加载、输入、旗帜、比分、时间等工具
├── export_presets.cfg       # Godot 导出配置
└── project.godot            # Godot 项目配置
```

## 架构说明

项目主要使用状态机和工厂类：

- `PlayerStateFactory` 管理球员动作状态。
- `BallStateFactory` 管理持球、自由移动、射门和必杀射门状态。
- `GameStateFactory` 管理开球、比赛中、进球、加时、比赛结束等比赛流程状态。
- `ScreenFactory` 管理主菜单、队伍选择、锦标赛和在线大厅等界面。

全局单例通过 Godot Autoload 注册：

- `DataLoader`：加载英文和中文队伍数据。
- `GameEvents`：全局信号总线。
- `GameManager`：比赛状态、比分和当前对阵。
- `AudioPlayer` / `MusicPlayer`：音效和音乐。
- `InputManager`：组合键输入和网络输入注入。
- `RoomManager`：ENet 连接、房间、大厅和队伍选择。
- `SyncManager`：在线比赛生命周期、客户端输入上行、世界快照和可靠事件同步。



## 致谢

本项目基于 [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course) 扩展开发，加入了必杀射门、空中动作、按位置分工的 AI、锦标赛流程和在线对战。
