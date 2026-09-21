# GoPredator 技术说明

## 支持的游戏构建

- Steam build：`24826606`
- EXE：`1.8.45317.0`
- `helldivers2.exe` SHA-256：`A09FF52663E73B94FB0CAC0DCB5BA84FFD10ECF44F74A8921AC66AF923988CC3`
- `game.dll` SHA-256：`CC75948D90FDFDE259DCB519E9933DB7FFA3CCB281CE4FB89E6B1B011557470C`

构建器与运行时均核对完整哈希；任一不匹配时不修改数据。

## 目标与标签

GoPredator 只以星球 3（寡妇港 / WIDOW'S HARBOR）为目标。运行时分别查找定义 `1243`“掠食变种”和 `1245`“掠食变种（图标）”，校验定义的 kind `40`、category `13`，再从当前构建的标签哈希表解析内部标签 ID。实现不把测试夹具中的标签编号当作游戏常量。

两个标签会写入 `scope=0`、`value=3`、终结族过滤器 `2` 的战役修饰行。每次更新都会重新检查，缺失时补齐，已经存在时不重复添加。修改过程验证 owner、内存类型、原字节与写入回读；双标签批次中途失败时回滚已完成字段。

## 星球入口与任务

3 的动态阵营字段从预期值 `1` 改为终结族 `2`，可用字段从 `0` 改为 `1`。只有字段仍为预期原值或已应用值时才会写入。

任务模板从当前本地任务表选择一个没有星球特殊标签的中立星球。3 和 268 均被排除为模板来源，因此 GoPredator 不依赖 268。只有当前活动或悬停星球为 3 时，才将缓存模板完整复制到空闲任务槽并把星球字段改为 3；不写 active planet、selection ID 或网络包。

## 互斥关系与安全边界

GoPredator 使用独立管理器 GUID `eefcedc1-ebd4-4662-91d6-14ed32f8133b`、发现资源 `mods/natsun/gopredator`、实现资源 `mods/natsun/gopredator_impl`、全局状态 `_G.GoPredator` 和 `9ba626afa44a3aa3.patch_1` 归档，可与 Gosporebrust 的 `patch_0` 同时安装、部署并被 Loader 同时发现。两个版本各自写入不同的目标星球。

模组不修改可执行页、反作弊代码、队列索引、队列元素或实时人口计数器，也不调用重建参数的原生任务/生成函数。新构建包在完成精确 ZIP 实机验证前保持 `runtime_verified: false`。
