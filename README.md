# GoPredator

GoPredator 是 Gosporebrust 的独立分支版本，只修改 寡妇港 星球：开放星球并更新本地任务列表，并为终结族任务添加 `“掠食变种”`。

不会对其他星球游玩造成影响

---需要主机客机同时安装---
GoPredator 使用独立管理器 GUID、独立 Loader 资源名 `mods/natsun/gopredator`、实现资源名 `mods/natsun/gopredator_impl` 和全局状态 `_G.GoPredator`。它遵循 HDArsenal/HD2MM 的标准 `9ba626afa44a3aa3.patch_0` 包名；真正的独立性来自归档内部资源身份，而不是修改 patch 文件名。

## 安装

1. 关闭游戏。
2. 安装并启用 [Bingus Shared Loader v15 或更新版本](https://github.com/CowboyBingus/BingusSharedLoader/releases)。
3. 在 HDArsenal 或 HD2MM 中导入 `GoPredator-v1.3.zip`。
4. 启用 GoPredator，Purge 后重新 Deploy，并重启游戏。

本测试包支持 Steam build `24826606`、EXE `1.8.45317.0`。离线测试通过不等于实机验证，精确 ZIP 完成游戏内测试前，`runtime_verified` 保持 `false`。

## 🤝 参与贡献

欢迎任何形式的贡献！以下是标准贡献流程：

1. **Fork 仓库** - 点击右上角 Fork 按钮创建您的副本
2. **创建分支** - 基于开发分支创建特性分支：
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **提交修改** - 编写清晰的提交信息：
   ```bash
   git commit -m "feat: 添加新功能" -m "详细描述..."
   ```
4. **推送更改** - 将分支推送到您的远程仓库：
   ```bash
   git push origin feature/your-feature-name
   ```
5. **发起 PR** - 在 GitHub 上创建 Pull Request 到原仓库的 `main` 分支
   
详见 [安装与卸载](INSTALL.txt)、[技术说明](docs/TECHNICAL.md) 和 [测试清单](docs/TESTING.md)。
