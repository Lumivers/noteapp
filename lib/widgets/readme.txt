# widgets

这个目录放可复用的 UI 组件（Widget），用于拼装页面。

## 这个目录里有什么

- markdown_editor.dart：Markdown 文本编辑组件，含格式化工具栏与保存回调。
- markdown_preview.dart：Markdown 渲染预览组件，负责将文本转换为可读视图。
- split_view.dart：可拖拽分栏组件，用于编辑区与预览区的分割布局。

## 这个目录是干什么用的

- 抽离可复用界面模块，减少 screens 中的重复 UI 代码。
- 保持页面结构清晰：screens 负责流程，widgets 负责组件。
- 便于独立优化和替换具体交互组件。
