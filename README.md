# NoteApp

一个本地优先的 Markdown 笔记应用，支持实时预览、全文搜索、暗色主题，以及 OpenAI 协议兼容的 AI 能力。

## 快速使用（发布版）

如果你已经拿到发布压缩包，按下面步骤即可使用：

1. 解压发布包到任意目录（建议非系统目录）。
2. 双击运行 `noteapp.exe`（或包内同名主程序）。
3. 首次启动会自动生成一篇欢迎笔记（新手引导）。
4. 如需 AI 功能，点击右上角 Settings 完成配置（可选）。

说明：

- 不需要安装 Flutter 或 Dart。
- 笔记是本地 `.md` 文件，不依赖云端。
- 默认存储目录为系统文档目录下的 `docs` 文件夹，可在 Settings 中修改。

## 首次启动说明

- 当笔记目录为空时，应用会自动创建一篇 `Welcome to NoteApp.md`。
- 这篇文档包含基础操作、AI 配置提示和 Markdown 示例。
- 只会在“空目录首次启动”时创建，不会反复覆盖你的已有笔记。

## 首次配置 AI（可选）

点击右上角 Settings，填写以下内容：

- API Base URL：例如 `https://api.openai.com/v1`
- API Key：你的密钥
- Model：例如 `gpt-4o-mini`、`deepseek-chat`、`qwen-plus`
- 全局 System Prompt：可选

然后点击“测试连接”确认可用，再点击“保存配置”。

说明：

- 应用会请求 `/chat/completions` 接口。
- 只要服务兼容 OpenAI 协议即可接入，不限厂商。
- API Key 使用安全存储（`flutter_secure_storage`）保存。

## 从源码构建（开发者）

### 1. 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Git

按目标平台补充工具链：

- Windows 桌面：Visual Studio 2022（含 Desktop development with C++）
- Android：Android Studio + Android SDK

先确认环境正常：

```bash
flutter doctor -v
```

### 2. 获取项目

如果你已经在本地有项目目录，直接进入目录即可；否则先克隆：

```bash
git clone <your-repo-url>
cd noteapp
```

### 3. 安装依赖

```bash
flutter pub get
```

## 开发运行

### 运行命令

```bash
# 查看可用设备
flutter devices

# Windows 桌面
flutter run -d windows

# Android（连接设备或启动模拟器后）
flutter run -d android
```

## 使用说明

### 笔记管理

- 新建：主页右下角“新建笔记”
- 编辑：点击笔记进入编辑器
- 自动保存：编辑后会自动防抖保存
- 删除：列表卡片菜单中删除
- 搜索：主页顶部搜索框支持标题与正文检索

### 存储目录

- 默认存储在系统文档目录下的 `docs` 文件夹
- 可在 Settings 中切换到任意本地目录
- 可一键恢复默认目录

### AI 能力

编辑器内支持：

- 润色
- 摘要
- 续写
- 自定义指令改写

AI 结果支持逐块审阅后再应用，避免整段覆盖。

## 项目结构

```text
lib/
   main.dart                # 应用入口
   models/                  # 数据模型
   screens/                 # 页面（主页、编辑器）
   services/                # 文件、设置、主题、AI 服务
   widgets/                 # 编辑器/预览/分栏组件
   utils/                   # 常量与工具
test/
   widget_test.dart
```

## 常用命令

```bash
# 代码检查
flutter analyze

# 单元/组件测试
flutter test

# 构建 Windows
flutter build windows

# 构建 Android APK
flutter build apk
```

## 常见问题

### 1. AI 调用失败

- 检查 Base URL 是否包含正确前缀（通常是 `/v1`）
- 检查 API Key 是否有效、有额度
- 检查 Model 名称是否正确
- 先在设置页点击“测试连接”定位问题

### 2. 看不到笔记或保存失败

- 检查当前存储目录是否存在、是否有读写权限
- 在设置页切换到一个可写目录后重试

### 3. 发布包会包含我的 API Key 吗

- 正常不会。
- API Key 是用户在本机运行后填写并保存在系统安全存储中，不会写入发布产物目录。
- 打包时建议只分发 `build/windows/x64/runner/Release` 的完整内容，不要混入你本机用户目录文件。

### 4. Windows 无法运行

- 确认已安装 Visual Studio C++ 桌面开发组件
- 执行 `flutter doctor -v` 按提示修复

## 依赖概览

核心依赖包括：

- `dio`：AI 网络请求
- `flutter_markdown` / `markdown`：Markdown 渲染
- `path_provider`：本地目录访问
- `shared_preferences`：普通设置存储
- `flutter_secure_storage`：敏感信息安全存储
- `file_selector`：本地目录选择

## 贡献

欢迎提交 Issue 和 Pull Request。
