# GoPredator

GoPredator 是 Gosporebrust 的互斥分支版本，只修改 125 星球：开放星球点击与本地任务列表，并为终结族任务添加定义 `1243`“掠食变种”和 `1245`“掠食变种（图标）”两个星球标签。

任务模板从当前战役地图中没有特殊星球标签的中立星球读取，明确排除 268，因此不依赖 268 是否可攻打。模组每 0.1 秒检查并补齐 125 的阵营、入口、任务和双标签数据，以应对游戏运行中对表项的刷新。

GoPredator 与 Gosporebrust 使用相同的 Loader 资源身份和管理器 GUID，二者只能启用一个。

## 安装

1. 关闭游戏。
2. 安装并启用 [Bingus Shared Loader v15 或更新版本](https://github.com/CowboyBingus/BingusSharedLoader/releases)。
3. 在 HDArsenal 或 HD2MM 中导入 `GoPredator-v1.0.zip`。
4. 只启用 GoPredator，Purge 后重新 Deploy，并重启游戏。

本测试包支持 Steam build `24826606`、EXE `1.8.45317.0`。离线测试通过不等于实机验证，精确 ZIP 完成游戏内测试前，`runtime_verified` 保持 `false`。

详见 [安装与卸载](INSTALL.txt)、[技术说明](docs/TECHNICAL.md) 和 [测试清单](docs/TESTING.md)。
