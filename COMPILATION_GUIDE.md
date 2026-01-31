# ClaudeGlance 编译指南

> 更新时间: 2026-01-31
> 状态: 源代码已修复，等待编译

---

## 当前状态

✅ **源代码修复完成**
- 文件: `ClaudeGlance/Views/HUDWindowController.swift`
- 修复: 固定窗口宽度 320px，消除 X 坐标偏移

❌ **编译环境限制**
- 当前系统: 只有 Command Line Tools
- 需要: 完整的 Xcode

---

## 编译方法选择

### 方法 1: 使用 Xcode (推荐) ⭐

**适用情况**: 您可以安装完整 Xcode

**步骤**:

```bash
# 1. 安装 Xcode (从 App Store)
# 或使用已安装的 Xcode

# 2. 配置开发者工具
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 3. 运行编译脚本
cd "/Volumes/research/效率技能/ClaudeGlance"
./build_and_install.sh
```

**或在 Xcode 中手动编译**:
```bash
# 打开项目
open "/Volumes/research/效率技能/ClaudeGlance/ClaudeGlance.xcodeproj"

# 在 Xcode 中:
# 1. 选择 ClaudeGlance scheme
# 2. 选择 Release 配置
# 3. Product -> Build (⌘B)
# 4. 产品 -> 显示构建位置
# 5. 复制 .app 到 /Applications
```

---

### 方法 2: 云端编译 (GitHub Actions) ☁️

**适用情况**: 无法安装 Xcode，可以使用 GitHub

**步骤**:

1. **Fork 项目到您的 GitHub**
   ```bash
   # 访问 https://github.com/MJYKIM99/ClaudeGlance
   # 点击 Fork 按钮
   ```

2. **创建 GitHub Actions 工作流**
   ```yaml
   # .github/workflows/build.yml
   name: Build ClaudeGlance

   on:
     workflow_dispatch:

   jobs:
     build:
       runs-on: macos-latest

       steps:
         - uses: actions/checkout@v4

         - name: Build
           run: |
             xcodebuild -scheme ClaudeGlance \
               -configuration Release \
               -derivedDataPath build \
               build

         - name: Upload App
           uses: actions/upload-artifact@v4
           with:
             name: ClaudeGlance.app
             path: build/Build/Products/Release/ClaudeGlance.app
   ```

3. **运行工作流并下载产物**

---

### 方法 3: 请求原作者发布修复版本 📧

**适用情况**: 等待官方修复

**步骤**:

1. 访问 [GitHub Issues](https://github.com/MJYKIM99/ClaudeGlance/issues)
2. 搜索是否有相似的偏移问题报告
3. 如果没有，创建新 Issue:
   - 标题: "HUD position shifts right (72px) when session count changes"
   - 描述: 附上 `HUD_OFFSET_ANALYSIS.md` 的内容
   - 建议: 提供修复方案

---

### 方法 4: 手动修改已安装应用 (临时方案) 🔧

**警告**: 这是临时方案，可能影响应用签名

**原理**: 修改应用配置文件，强制固定窗口大小

**步骤**:

```bash
# 1. 停止应用
killall ClaudeGlance

# 2. 备份应用
cp -R /Applications/ClaudeGlance.app ~/ClaudeGlance.backup.app

# 3. 编辑配置文件 (临时修复偏移)
# 这不会修复源代码，但可以重置位置
defaults delete yikong.ClaudeGlance hudPositionX
defaults delete yikong.ClaudeGlance hudPositionY

# 4. 重启应用
open /Applications/ClaudeGlance.app

# 5. 拖动 HUD 到想要的位置
# 下次重启时会保持这个位置
```

**注意**: 这只是临时方案，偏移问题仍会在会话数量变化时出现。

---

## 快速决策指南

| 您的情况 | 推荐方法 | 时间成本 |
|---------|---------|---------|
| 可以安装 Xcode | 方法 1 (Xcode) | 15-30 分钟 |
| 有 GitHub 账号 | 方法 2 (云端) | 10-20 分钟 |
| 不想安装任何工具 | 方法 3 (等待官方) | 取决于作者 |
| 只想临时使用 | 方法 4 (配置重置) | 1 分钟 |

---

## 验证修复

编译并安装后，运行验证脚本：

```bash
/Volumes/research/效率技能/ClaudeGlance/verify_fix.sh
```

预期结果:
- ✅ 应用已安装
- ✅ 应用正在运行
- ✅ Socket 连接正常
- ✅ 使用 Claude Code 时，HUD 位置保持稳定

---

## 故障排查

### 问题: "xcodebuild: error: tool 'xcodebuild' requires Xcode"

**原因**: Command Line Tools 不足，需要完整 Xcode

**解决**:
```bash
# 从 App Store 安装 Xcode
# 然后运行:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### 问题: "Code sign error"

**原因**: 代码签名问题

**解决**:
```bash
# 重新签名
codesign --force --deep -s - /Applications/ClaudeGlance.app
```

### 问题: 编译成功但应用无法启动

**原因**: 权限或隔离属性问题

**解决**:
```bash
# 移除隔离属性
xattr -d com.apple.quarantine /Applications/ClaudeGlance.app

# 设置正确权限
chmod -R u+rwX,go+rX,go-w /Applications/ClaudeGlance.app
```

---

## 相关文件

| 文件 | 说明 |
|------|------|
| `build_and_install.sh` | 自动化编译脚本 |
| `verify_fix.sh` | 验证脚本 |
| `HUD_OFFSET_ANALYSIS.md` | 详细问题分析 |
| `FIX_INSTRUCTIONS.md` | 修复说明 |
| `FIX_SUMMARY.md` | 修复总结 |

---

## 下一步

1. **选择编译方法** (根据您的环境)
2. **执行编译**
3. **运行验证脚本**
4. **测试修复效果**

---

*编译指南生成于 2026-01-31 | Claude (GLM-4.7)*
