# Build DMG

构建 Claude Glance 的 DMG 安装包。

## 执行步骤

请执行以下操作：

1. 运行打包脚本：
   ```bash
   ./Scripts/build-dmg.sh --open
   ```

2. 等待构建完成，脚本会：
   - 编译 Release 版本
   - 创建 DMG 安装包
   - 自动打开生成的 DMG

3. 如果构建失败，请检查错误信息并修复问题。

4. 构建成功后，告诉用户 DMG 文件的位置和大小。

## 可选参数

- `--skip-build`: 跳过编译，使用现有的构建
- `--open`: 构建完成后自动打开 DMG

## 注意事项

- 确保 Xcode 命令行工具已安装
- 如果想要更漂亮的 DMG（带拖拽图标），可以先安装 `brew install create-dmg`
