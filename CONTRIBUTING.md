# Build from source

需要 Windows x64、Python 3.10+、目标游戏文件，以及与游戏兼容的非 GC64 LuaJIT。默认会复用同一工作区中 `EnemySpawnMultiplier/tools/src/LuaJIT/src/luajit.exe`；也可以通过 `HD2_LUAJIT` 指定。

从项目目录执行：

```powershell
$env:HD2_GAME_ROOT = 'D:\SteamLibrary\steamapps\common\Helldivers 2'
$env:HD2_LUAJIT = (Resolve-Path '..\EnemySpawnMultiplier\tools\src\LuaJIT\src\luajit.exe').Path
python -B scripts/build.py
```

构建器会先核对 EXE 与 `game.dll` 的完整 SHA-256，然后编译 LuaJIT 字节码、运行合成内存测试、生成两个 Loader v15 资源、写入 HD2 归档和空 sidecar、创建 V1 管理器清单，并独立解析最终 ZIP。成功产物为 `releases/GoPredator-v1.3.zip`。

构建不会安装模组、启动游戏或上传 GitHub。`runtime_verified` 在精确 ZIP 完成实机测试前必须保持 `false`。
