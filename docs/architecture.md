# DeeepList 架构边界

## 页面和编辑状态

`EditingController` 是页面作用域编辑意图的唯一所有者，保存编辑节点、阶段、保存中状态及日期交互状态。普通页面的 `NodePageController` 只把这个对象的不可变快照映射给 Riverpod；智能页面订阅同一 Controller 实现。页面之间不共享全局编辑目标。

`EditorSession` 执行显式焦点请求，维护注册的 Flutter 控件、待执行请求和焦点代次；实际获得焦点不会自行选择编辑目标。`EditorKeyboardPolicy` 解释 IME 高度变化，不执行保存或删除。`EditorLifecycle` 将路由、应用生命周期和键盘通知交给编辑协调器。

`NodeEditingCoordinator` 负责自动保存、保存串行队列和编辑结束。`NodeListController` 编排普通列表的 Enter、Backspace、新建、缩进、反缩进和乐观排序。`NodeActionsController` 编排两类列表共享的节点操作，并返回完成撤销或复制源不存在等结果。页面负责呈现结果、菜单和导航，不在 Widget 回调中执行整套业务流程。

## 查询和依赖组装

Feature 的 Provider 定义位于 `features/nodes/providers.dart`，由 App 的 `nodeRepositoryOverride` 注入 Drift 实现；Feature 不导入 App。内部剪贴板和页面状态 Controller 均位于 Presentation。

`SmartListQuery` 位于 Application，统一筛选和日期分类；中文分组标题、路径文案和 `VisibleNodeItem` 位于 Presentation。主页数量直接汇总相同分组结果。`todayProvider` 在本地午夜刷新，恢复前台立即校准，并每分钟检查前台系统日期变化；日期格式化和列表判断使用同一来源。

智能列表通过 `watchAncestorPaths` 一次订阅整批节点路径，递归 SQL 保留祖先顺序和循环防护，并监听祖先重命名、节点移动。实验中 100 个节点、每个 5 层祖先，原实现需要 1,100 次单节点查询；新路径查询回归测试确认初始批次只执行一次 SQL。这是查询次数证据，不等同于设备延迟测量。

## 刻意保留的边界

- `TreeCommandService` 暂不拆分；结构写入、树规则和事务保持集中。
- `NodeRepository` 的读接口与 `TreeMutationRepository` 保留；依赖注入已通过静态类型明确 mutation 能力，不再运行时猜测。没有增加四套 Reader 接口。
- 数据库仍在 `core/database`，被视为项目基础设施，而非严格的通用 Core。目录迁移不改变运行行为，当前不为目录整洁改 schema 或迁移。
- 全局 child count 保持共享聚合查询。执行计划使用 `nodes_parent_archive_position` 索引；这不证明大数据量下没有瓶颈，是否改为范围订阅需设备数据量和耗时证据。
- `NodeFailure` 为不存在、已归档、父级不一致提供类型；树规则继续使用 `TreeRuleViolation`。底层持久化异常保留原始原因，不统一吞成无信息的失败。

## 验证约束

保留 Domain、数据库迁移和 UI 回归测试；新增编辑状态、无 Widget 的操作 Controller、路径查询次数与响应式更新测试。架构测试防止 Feature 反向导入 App 和 Application 导入 Presentation。

重构不等同于真机 IME 验证：软键盘、平台生命周期与实际设备布局仍需要设备验收。
