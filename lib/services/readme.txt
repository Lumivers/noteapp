# services

这个目录放服务层代码（Service），负责与外部资源或系统能力交互。

## 这个目录里有什么

- file_service.dart：本地笔记文件的初始化、读取、保存、删除、重命名、搜索、导出。
- ai_service.dart：AI 接口调用封装（请求构建、超时、流式/非流式返回、错误处理等）。
- settings_service.dart：应用设置读写（SharedPreferences + 安全存储）。
- theme_service.dart：主题模式状态与主题对象生成。

## 这个目录是干什么用的

- 把 I/O、网络、配置存储等能力与 UI 解耦。
- 统一封装业务可复用能力，减少页面中的重复代码。
- 提供清晰边界，方便后续测试与维护。
