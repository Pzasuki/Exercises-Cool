/// 全局常量，对应 www/index.html 中的行为参数。
library;

/// 筛选结果每页加载数量（对应 JS `state.pageSize`）。
const int kPageSize = 60;

/// 搜索输入防抖时长（对应 `wireEvents()` 里的 debounce 250ms）。
const Duration kSearchDebounce = Duration(milliseconds: 250);

/// 宽窄屏断点（对应 CSS `@media (max-width: 768px)`）。
const double kNarrowBreakpoint = 768;

/// 侧栏宽度（对应 `--sidebar-w`）。
const double kSidebarWidth = 260;

/// 总览页内容区最大宽度（宽屏时分类卡片网格居中，避免铺满超宽屏）。
const double kOverviewMaxWidth = 960;
