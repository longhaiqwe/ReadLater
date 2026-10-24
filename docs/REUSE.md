# Skill 复用记录

本工程由 clothesline-ui/scripts/scaffold.py 生成。经过文件拖放能力回补后，下列 7 个通用组件与技能模板逐字节相同。

- ScreenEdge.swift
- RailState.swift
- RailPresentation.swift
- RailDecoration.swift
- ClotheslineView.swift
- RailWindowController.swift
- FileDropHostingView.swift

新增业务层为 ShelfRepository、ShelfStore、FileDragView、ReadingViews，以及应用入口和测试用视图渲染器。

回补通用模板的部分包括可选文件接收、拖文件时的边缘展开、扩展业务菜单、文件选择器期间的显隐暂停，以及来源授权随应用打包。

实机复用另外回补：启动／重新打开保留 10 秒操作时间。验证详情见 VERIFICATION.md；Finder 双向拖放由用户亲自确认通过。
