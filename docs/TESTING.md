# GoPredator 测试清单

## 离线检查

构建器自动验证：

- 定义 1243 与 1245 分别解析为运行时内部标签。
- 两个标签均只写入 3 的终结族星球作用域行。
- 重复更新不会重复添加标签。
- 127 与 268 的标签、阵营和任务记录不被修改。
- 3 的动态阵营与可用字段写入会回读验证。
- 3 可从非 268、无特殊星球标签的中立星球获得任务模板。
- owner 变化、非法定义、只读内存和部分写入失败均安全停止或回滚。
- 最终 ZIP 的 Loader 声明、LuaJIT 字节码、归档边界、清单、哈希和文件白名单正确。

## 实机检查

对最终 `GoPredator-v5.0-preview.zip` 的精确 SHA-256 测试：

1. 干净部署 Loader v15 与 GoPredator，确认 Gosporebrust 已禁用。
2. 进入银河战争地图，确认 3（寡妇港 / WIDOW'S HARBOR）可以点击。
3. 确认 3 出现任务列表并可选择、进入任务。
4. 在关卡内确认掠食变种敌人实际出现。
5. 返回地图并再次进入 3，确认连续覆写后仍正常且没有重复条目或崩溃。
6. 检查 127、268 和至少一个普通星球，确认其入口、任务和标签未被改变。

精确测试包完成以上实机检查前，`runtime_verified` 保持 `false`。若失败，请提供 `GoPredator.log` 以及失败发生在点击星球、显示任务、选择任务还是进入关卡阶段。

## Hash-mismatch diagnostic

A module hash mismatch must produce `identity=warning` in GoPredator.log and must
not stop the patch by itself.  A genuinely incompatible build must instead fail
structural checks and report `gopredator_waiting`.
