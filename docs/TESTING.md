# Test matrix

## Offline checks

构建时自动执行：

- 定义 1244 解析为内部标签 9
- 为 173 和 268 创建独立的星球作用域行（`scope=0`）
- 追加到已有目标星球行并保留已有标签
- 未过滤目标行不被扩展到其他阵营
- 满行改用新的空行，并继续保持正确的星球 ID
- 重复更新不重复写入
- 定义变化、空 owner、非私有可写页均失败关闭
- 字段写入失败与 owner 更换均回滚
- Loader 回调保留包含 nil 的返回元组
- 最终 ZIP 白名单、归档结构、发现声明、字节码、哈希、隐私与可迁移性检查

## Required live test before release

对 `releases/Gosporebrust-v2.4.zip` 的精确 SHA-256 执行以下测试并保存完整日志：

1. 干净部署 Loader v15 与 Gosporebrust，启动到飞船，确认日志只有一次发现与初始化。
2. 确认日志出现 `task_rows=disabled`，并先验证 268 的原生任务列表恢复正常。
3. 进入 173（盖尔崔亚），记录任务、难度、单人/主机状态，确认出现孢裂变种敌人并完成撤离。
4. 不退出游戏，返回飞船并进入 268（富源），确认标签仍有效且没有重复或崩溃。
5. 进入其他可用星球，确认没有因本模组出现孢裂变种。
6. 如果 173 当前不可攻打，记录地图状态；v2.4 不修改任务表、active planet 或服务器 selection ID，173 入口问题需要单独研究。
7. 覆盖低难度和预期最高难度；至少观察初始驻防、巡逻、增援/虫潮与撤离阶段。
8. 正常退出游戏，确认关卡切换、撤离和关闭阶段无崩溃。

实机通过前，包内 `runtime_verified` 必须保持 `false`。如果日志显示 `gosporebrust_waiting`，请提供 `Gosporebrust.log`；如果显示 `gosporebrust_applied` 或 `gosporebrust_ready` 但敌人池未变化，请同时提供任务星球、难度、是否主机及关卡内观察结果。
