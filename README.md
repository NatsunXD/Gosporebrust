# Gosporebrust

Gosporebrust v2.4 是恢复测试版：为 173（盖尔崔亚 / GATRIA）和 268（富源 / LUXURIANT）的终结族任务加入“孢裂变种”标签，并保留 173 的动态阵营实验写入（1→2）。为避免破坏共享任务状态，本版完全停用任务表复制和 active planet 写入。

词条映射来自用户提供的《星球词条 ID 表》：定义 ID `1244` 为孢裂。模组不会直接写死内部标签编号，而是在游戏启动时读取定义 `1244`，校验其结构和标签哈希，再解析当前构建中的内部标签 ID。

## 安装要求

- Helldivers 2 Steam build `24826606`
- EXE `1.8.45317.0`
- Bingus Shared Loader v15 或更新版本，API 1
- HDArsenal 或 HD2MM

Loader v15 官方下载：https://github.com/CowboyBingus/BingusSharedLoader/releases/tag/v15

本项目目前是 v2.4 恢复测试版。离线逻辑与包结构测试通过并不等于实机验证；本版不修改本地任务表或活动星球。只有用户完成指定的终结族任务测试后，才会把 `runtime_verified` 改为 `true` 并准备 GitHub 发布。

## 目录

- `src/`：运行时 Lua、Windows 只读/数据写入接口、Loader v15 初始化入口
- `tests/`：合成内存逻辑测试与最终 ZIP 独立检查
- `scripts/`：LuaJIT 编译、HD2 资源归档、清单与可复现 ZIP 构建
- `docs/`：技术依据与实机测试清单
- `build/`：构建中间文件与报告（不提交）
- `releases/`：可导入模组管理器的 ZIP（不提交）

详见 [安装与卸载](INSTALL.txt)、[技术说明](docs/TECHNICAL.md) 和 [测试清单](docs/TESTING.md)。
