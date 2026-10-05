# MIGRATION — www 网页版 → Flutter 重构步骤

原应用是 `www/index.html` 单文件 SPA（内联 CSS + 原生 JS，经 Capacitor 打包为安卓应用）。
Flutter 项目位于**仓库根目录**（`lib/`、`assets/`、android/）。
重构完成后，原网页版 `www/` 与 Flutter Web 预览目录 `web/` 已删除；
未翻译的原始版本在旁边的 `exercises-pzasuki233-main` / `-test` 仓库仍有完整备份。

| 项目 | 说明 |
| --- | --- |
| 数据 | 1324 条动作，15 个字段（现位于 `assets/data/exercises.json`，schema 见 `docs/exercises.schema.json`） |
| 媒体 | 静态缩略图 `assets/images/*.webp`（1324 张）+ 动图 `assets/videos/*.webp`（1324 张 Animated WebP），共 52MB，已打包进 assets |
| 应用名 | 动作库（Android label / Web title 已设置） |
| 状态管理 | provider + ChangeNotifier（`LibraryController`） |

---

## 一、概念映射表（Web → Flutter）

| 原网页实现 | Flutter 对应 | 位置 |
| --- | --- | --- |
| `:root` CSS 设计变量 | `AppColors` / `AppDimens` / `appTheme` | `lib/core/theme/` |
| `ZH_TERMS` / `zh()` | `kZhTerms` / `zh()` | `lib/core/i18n/zh_terms.dart` |
| `fetch('./data/exercises.json')` | `ExerciseRepository.loadAll()`（rootBundle + compute isolate） | `lib/data/repositories/` |
| `state` + `applyFilters()` + `appendNextPage()` | `LibraryController`（ChangeNotifier） | `lib/state/library_controller.dart` |
| 搜索 debounce 250ms | `LibraryController.setSearch()` 内部 Timer | 同上 |
| `.app-shell` 双栏 / `@media 768px` 单列 | `LibraryScreen` 的 LayoutBuilder | `lib/features/library/` |
| `.exercise-grid` + IntersectionObserver 无限滚动 | `GridView.builder` + ScrollController（每页 60） | 同上 |
| `.card-gif` 悬停换动图 | `MouseRegion` + `Image.asset`（Flutter 原生支持 Animated WebP） | `widgets/exercise_card.dart` |
| `openModal()` 详情弹层 | `showExerciseDetailSheet()`（modal bottom sheet） | `lib/features/detail/` |
| `history.pushState` 返回键关弹窗 | `showModalBottomSheet` 自带导航栈行为 | — |
| `localStorage.sidebarCollapsed` | shared_preferences（阶段6 引入） | — |
| Capacitor `StatusBar` 设置 | `SystemChrome`（已在 main.dart 完成） | `lib/main.dart` |

## 二、已完成（本次骨架，可直接运行）

- [x] `flutter create` 项目骨架（android；iOS/web 目录已先后按需求移除），包名 `com.reexercises.exercises_app`
- [x] 资产迁移：`assets/data` + `assets/images` + `assets/videos`；schema 归档到 `docs/`
- [x] 数据层：`Exercise` 模型（fromJson、assets 路径映射、搜索索引）、`ExerciseRepository`
- [x] 状态层：`LibraryController` —— 搜索防抖、三维筛选（分类/器材/目标肌肉）、选中置顶排序、每页 60 条分页
- [x] 主题：CSS tokens 全量映射（颜色/圆角/网格尺寸）、中文术语表
- [x] 主页面：宽屏「侧栏 260px + 网格」/ 窄屏「可折叠顶部面板 + 网格」、无限滚动、空态
- [x] 卡片：3:4 媒体区、名称、分类/器材标签、桌面端悬停切动图、点击打开详情
- [x] 详情弹窗（简化版）：动图、元信息、主要/次要肌群、编号步骤
- [x] 单元测试（模型解析、筛选、搜索、排序、分页），`flutter analyze` 零告警
- [x] 侧栏筛选面板（阶段3）：三组筛选芯片（分类/器材/目标肌肉），选中置顶、
  选中主题色样式、悬停反馈；宽屏换行流 / 窄屏单行横滑；移动端顶栏折叠按钮
  带已选数量徽章与旋转箭头
- [x] 详情弹窗对齐（阶段4）：宽屏居中弹窗（660px、毛玻璃遮罩、Esc/遮罩点击/×
  关闭），窄屏底部弹层（max-height 92dvh）；≤480px 内边距 16、动图限高
  320/240 按宽度分流；肌群区底部分隔线等样式精调
- [x] 交互细节对齐（阶段5）：结果条已选徽章（× 逐个移除）+「清除全部」（搜索框
  同步清空）；卡片悬停上浮 3px + 阴影 + 静图/动图 200ms 交叉淡入；≤480px
  固定两列网格（间距 8）；网格三档内边距按原版媒体查询对齐
- [x] 持久化与平台打磨（阶段6）：shared_preferences 记忆窄屏面板折叠状态
  （键名与原版一致 `sidebarCollapsed`，并修正了原版读写相反的问题）；应用图标
  （自适应图标，橙色 #FF4F00 底 + 白色「库」）与启动屏（浅灰底 + 标志）已生成，
  素材在 `assets/icon/`，配置在 pubspec.yaml 的 `flutter_launcher_icons` /
  `flutter_native_splash` 段
- [x] 移除 iOS：`ios/` 目录及 `.metadata`、`analysis_options.yaml`、文档中的
  iOS 引用已清理；随后 `web/`（Flutter Web 预览）与 `www/`（原网页版参照）也已删除，
  目标平台仅剩 Android
- [x] 数据名称中文化：动作名全部译为中文（原 1162 个英文名，见 test/ 内两份翻译稿合并）

## 三、后续阶段步骤

### 阶段3 侧栏筛选面板 ✅ 已完成

实现于 `widgets/filter_section.dart` + `filter_panel.dart` + `library_screen.dart` 的
`_NarrowHeader`/`_ToggleChip`，状态全部走 `LibraryController`（`orderedValues` /
`toggleFilter` / `activeFilterCount`），新增 `test/filter_test.dart` 覆盖宽屏点选与窄屏徽章。

> 注意：原版「还有 N 项」展开（`EQUIP_INITIAL=10` + `renderChips(initialLimit)`）在
> 原网页里是**死代码**——`renderFilterSection` 从未传入截断参数，实际行为是三组芯片
> 全部常显。Flutter 版按原版实际行为实现，未做截断；如想要截断交互，给
> `FilterSection` 加 `initialLimit` 参数即可。

### 阶段4 详情弹窗对齐 ✅ 已完成

实现于 `lib/features/detail/exercise_detail_sheet.dart`：`showExerciseDetail()` 按
`kNarrowBreakpoint` 分流——宽屏 `showGeneralDialog` 居中弹窗（barrier 0x73000000 +
`BackdropFilter` 毛玻璃 6px；Esc 用 `Focus.onKeyEvent` 处理；遮罩点击由
`barrierDismissible` 承接），窄屏 `showModalBottomSheet`（max-height 92dvh）。
内容组件两种形态共用，间距/动图限高按原版 CSS 分档。测试见 `test/detail_test.dart`。

> 多语言步骤页签：原版同样只接 `zh`（`const langs = ['zh']`），故未实现页签；
> 数据加入其他语言后在步骤区加 `TabBar` 即可。

### 阶段5 交互细节对齐 ✅ 已完成

- 结果条：`results_bar.dart` 重写——徽章按 分类→器材→目标肌肉 排列（对应
  `updateActiveBadges`），× 调 `toggleFilter` 移除，「清除全部」调 `clearAllFilters`。
- 卡片：`exercise_card.dart` 改用 `AnimatedContainer`（transform 上浮 + 描边 +
  阴影 150ms）与 `AnimatedSwitcher`（静图/动图 200ms 交叉淡入）。
- 网格：`library_screen.dart` 三档（桌面 / <768 / ≤480 两列），内边距按原版对齐。
- 搜索框：面板输入框在「清除全部」后同步清空（postFrame 修改，避开构建期通知）；
  `clearAllFilters` 顺带取消未触发的防抖（原版存在竞态，这里修正）。

> 骨架屏（`.skeleton-card` + `renderSkeletons`）在原版同样是**死代码**（从未调用），
> 数据本地加载无网络延迟，故不实现。

### 阶段6 持久化与平台打磨 ✅ 已完成

1. `shared_preferences`：`LibraryScreen._restorePanelState/_togglePanel` 读写
   `sidebarCollapsed`（'1'=折叠），存取失败（如测试环境）时保持默认展开。
2. 应用图标与启动屏：`assets/icon/` 三张素材由脚本生成（PIL + 微软雅黑粗体），
   `dart run flutter_launcher_icons` 生成自适应图标，`dart run flutter_native_splash:create`
   生成安卓启动屏（`web: false`，只影响 Android）。换图标时改素材重跑这两条命令即可。
3. iOS 相关已按需求整体移除（`ios/`、`.metadata`、analysis exclude、文档引用）。

### 阶段8 两级浏览与筛选降噪 ✅ 已完成（需求调整）

1324 个动作平铺 + 三组芯片常显（10+28+19=57 个）导致页面杂乱、筛选无从下手，
改为「先选部位、再收窄」的两级浏览：

1. **分类总览首页**（`features/overview/overview_screen.dart`）：顶栏 logo + 搜索，
   「全部动作」入口 + 10 个部位大卡（名称 + 全库数量 + 代表图 = 该分类数据顺序
   第一条的缩略图，索引在 `LibraryController` 构建时一次算好）。点卡片调
   `enterCategory()`（重置搜索与其他筛选后仅设该分类）并 push 浏览页。
2. **分类浏览页**（原 `LibraryScreen` 改造）：窄屏顶栏 = 返回键 + 分类名 + 筛选
   折叠按钮；宽屏侧栏顶部加返回键。内容区抽出为共用 `ResultsView`
   （结果条 + 目标肌群快捷行 + 网格），总览页搜索结果也复用它。
3. **目标肌群快捷行**（`widgets/category_target_bar.dart`）：恰好选中一个分类
   且该分类下有 ≥2 个目标肌群时出现（数据上单肌群分类如腰腹/肩部占了 7/10，
   快捷行无收窄价值直接隐藏）。芯片 = 「全部 N」+ 各肌群 facet 计数，
   与侧栏 target 维度共用同一筛选状态。
4. **筛选芯片降噪**（`widgets/filter_section.dart`）：
   - 芯片带 facet 计数（点选后会得到的结果数）；facet 语义为**忽略本维度自身
     已选**（保持多选叠加能力），只对其他维度联动置灰；
   - 0 结果芯片直接隐藏（已选中的除外，保证能取消）；
   - `initialLimit` 折叠：器材 / 目标肌肉默认显示前 8 个有结果的值 +「更多」，
     展开后 0 结果芯片以置灰形态可见；
   - 可选值排序：器材/目标肌肉按**全库数量降序**（同数字母序）——常用值
     稳定靠前；分类维度按固定业务顺序（`kCategoryDisplayOrder`：
     胸→背→肩→腰腹→上臂→大腿→前臂→小腿→颈→有氧），总览卡片与分类芯片共用；
   - 已选中的芯片始终优先显示；
5. **共用搜索框**（`widgets/search_field.dart`）：总览页顶栏与侧栏共用，
   文本双向同步（外部清空时同步清空、带着搜索词返回时回填）。
   总览页搜索生效后正文切换为结果视图，清除后回到部位卡片。
6. **触屏动图预览**：`ExerciseCard` 增加长按手势——长按期间切动图 + 上浮描边，
   松开还原且不触发详情弹窗。原版移动端靠触摸触发 CSS `:hover` 得到同等效果，
   Flutter 的 MouseRegion 对触摸无效，故显式承接；总览页部位卡片不加此交互。
7. **分类页侧栏只留器材**（需求调整）：从总览进入具体分类后（含在「全部动作」
   视图点选任一分类芯片后），侧栏隐藏「分类」与「目标肌肉」两组——前者属于
   总览页的职责，后者由页面顶部快捷行承担，避免重复与误切部位；此时取消分类
   走结果条徽章的 ×，取消后侧栏三组恢复。「全部动作」视图（无分类）三组齐全。
8. **筛选模块视觉合并**（需求调整）：结果条（原灰底）与目标肌群快捷行
   （原白底）合并为一个白色区块（`ResultsView` 内统一容器 + 底部分隔线），
   与上方搜索/器材面板连成一块连续的筛选区，消除三层灰白交替的割裂感；
   `ResultsBar` / `CategoryTargetBar` 自身不再带背景与边框。
9. **分类页不显示结果条**（需求调整）：分类徽章与页面标题（如「背部」）重复，
   分类页形态下整个结果条不再渲染；计数移到快捷行状态行右侧
   （「全部 N」与右侧 N / 1324 均实时反映筛选结果）。「全部动作」视图的
   结果条（徽章 + 清除全部 + 计数）保持原样；快捷行在单肌群分类下只显示计数。
10. **系统返回键与搜索状态**（需求调整，`PopScope`）：
   - 主页搜索态：返回被拦截（canPop=false）→ 清除搜索回到分类总览，
     再次返回才走系统默认（退出应用）；
   - 分类页带搜索词：键盘打开时首次返回由系统收起键盘（文本保留），
     路由 pop 回主页时清除搜索（`onPopInvokedWithResult`），主页回到
     分类总览而非残留的搜索结果。
   注意测试断言：`handlePopRoute()` 返回值语义是「返回事件是否被消费」，
   PopScope 拦截时同样返回 true（应用不退出）；pop 转场约 300ms，断言前需
   泵 ≥800ms 等旧路由出树。
11. **代码审查修复**（2026-10，全量回归通过）：
   - 分类筛选残留（逻辑 bug）：浏览页返回主页由「只清搜索」改为
     `returnToOverview()`（清搜索 + 分类残留）。此前残留分类会把主页搜索
     隐性过滤（实测：胸部残留时搜「深蹲」得 0 / 1324，全库实际 71），而
     结果条又被 hasSingleCategory 隐藏，用户看不到任何提示；器材/目标筛选
     保留，回主页搜索时以徽章形式可见生效。
   - 启动流程：`runApp` 先出加载态，数据读取+解析在 UI 就绪后进行（原先
     await 在 runApp 之前，低端机启动白屏可感知）；错误页增加「重试」。
     `ExerciseBootstrap` 支持注入 loader 供测试。
   - 搜索词语义拆分：`search`（原文，输入框回显同步用）与 `activeQuery`
     （trim 后生效词，筛选匹配与搜索态判定）——纯空白输入不再进入搜索态。
   - `Exercise.searchIndex` 缓存为 `late final`（构造函数相应去 const，
     全库无 const 用法），避免每次筛选变化对全库重复拼串。
   - 测试 32 → 36 项（新增启动引导 2 项、分类残留回归 1 项、空白搜索
     1 项），`flutter analyze` 0 issue。

测试 16 → 30 项（新增 `overview_test.dart` 两级浏览 6 项、facet/enterCategory/
分类索引等状态层 4 项、长按预览 1 项），`flutter analyze` 0 issue。

> 设计取舍：从总览进入分类会**重置**其他筛选（每次进入都是干净浏览态）；
> 总览搜索结果不带侧栏，筛选需清搜索后从部位进入（暂定，若高频再议）。

### 阶段9 收藏与训练 ✅ 已完成（需求调整）

新增两大功能，入口采用**底部 3 Tab**（`features/home/home_shell.dart`，
IndexedStack 保持各 Tab 状态）：动作库（原总览+浏览两级）/ 训练 / 收藏。

1. **收藏夹**（`state/favorites_service.dart`）：
   - 模型 `FavoriteFolder{id, name, exerciseIds}`，持久化到
     shared_preferences（键 `favoriteFolders`，JSON）；存储不可用退化为内存态；
   - 收藏入口在**详情弹窗**：标题旁心形按钮（已收藏实心主题色）→
     收藏夹选择弹层（`features/favorites/folder_picker_sheet.dart`），
     勾选/取消多个收藏夹即时生效，可当场新建；
   - 收藏 Tab：收藏夹列表（新建/重命名/删除）→ 夹内动作列表
     （查看详情 / 从夹内移除）；
   - id 生成 = 时间戳 + 自增序号（纯时间戳在同一微秒内会撞 id，
     曾导致多夹收藏互相覆盖的 bug）。
2. **训练做组计数**（`state/workout_controller.dart` + `features/workout/`）：
   - 状态机 idle（模板列表 + 开始入口）→ planning（挑动作、组数×次数步进器、
     排序/删除、组间倒计时开关+秒数 ±15）→ running（逐动作做组打点：
     组进度圆点、「完成一组」；做完自动切下一个动作；组间可选倒计时大字 +
     +15s / 跳过；支持跳过动作、提前结束）→ finished（总结：动作数/组数，
     可存为模板）→ idle；
   - 挑动作弹层（`exercise_picker_sheet.dart`）：「收藏」页签（收藏夹横滑
     选择 + 夹内动作）/「搜索动作库」页签（本地检索全库，不干扰页面筛选状态），
     点选返回动作 id。**注意：不用 TabBarView**——底部弹层内嵌 PageView 的
     手势竞技场会吞掉列表点击（点击命中但不响应），改用 SegmentedButton 切换；
   - 模板 `WorkoutTemplate{id, name, entries, createdAt}` 持久化（键
     `workoutTemplates`），可加载为规划清单再调整；
   - 间歇倒计时默认**关闭**，开启后默认 60s，±15s 调节；倒计时由控制器的
     `Timer.periodic` 驱动（单测用 fake_async 验证自动结束）。
3. **配套**：`LibraryController` 增加 `exerciseById`（id → 动作反查）与
   `allExercises`（全库只读，供挑动作搜索）；`main.dart` 的 bootstrap 在
   数据就绪后挂三个 provider（LibraryController / FavoritesService /
   WorkoutController）。

测试 36 → 48 项（新增 favorites/workout 服务层单测与组件测试），
`flutter analyze` 0 issue。

### 阶段10 训练功能完善 ✅ 已完成（需求调整）

1. **组间倒计时改分钟制**：规划页步进 1~10 分钟（1 分钟起，`setRestMinutes`
   钳位），内部仍以秒驱动倒计时；执行中 +15s 微调保留，倒计时展示 mm:ss。
2. **挑动作弹层默认有内容**：「搜索动作库」页签不再空白——默认列出全库动作，
   顶部新增部位分类 chips（与主界面同一套 `kCategoryDisplayOrder` 顺序 +
   全库计数），搜索词与部位筛选叠加生效。
3. **规划卡片溢出修复**（附图问题）：组/次/重量控制行改用 Wrap 兜底，
   图标按钮收紧为 32px 点击区（`_MiniIconButton`），排序箭头改为
   上下纵排，窄屏不再出现 RIGHT OVERFLOWED。
4. **训练重量（kg，可选）**：`PlanEntry/SessionEntry/WorkoutRecordEntry`
   增加 `weight`（null = 未设置）；规划卡片的重量步进从「+」起 10kg、
   ±2.5kg、减到底回未设置；执行页与历史明细展示重量。
5. **训练感受**：总结页新增「轻松/刚好/有点累/很累」选择（默认刚好），
   点「完成」随记录写入历史。
6. **历史训练**：`WorkoutRecord{date, duration, feeling, entries}` 持久化
   （键 `workoutHistory`）；训练起始页新增「历史训练」区，卡片显示
   日期/动作数/组数/感受/时长，可展开看动作明细（组数/次数/重量），可删除。
   只有实际完成组数 > 0 的动作才写入记录。

测试 48 → 53 项（分钟制钳位 / 重量设置清空 / 历史写入删除 /
弹层默认列表与分类过滤 / 全流程含重量与感受）。

### 阶段11 收藏默认列表与训练默认参数 ✅ 已完成（需求调整）

1. **默认收藏列表**：`FavoritesService` 内置「默认收藏」夹（id `default`，
   加载时保证存在，**不可重命名/删除**）。详情弹窗心形按钮**点按 = 直接收进
   默认收藏**（不弹层）；**长按 = 打开收藏夹选择弹层**（含默认收藏行，
   可多选/新建）。收藏页默认夹排首位且不显示管理菜单。
2. **挑动作弹层改卡片网格 + 多选**：两个页签均为 2 列图片卡片
   （缩略图 + 名称 + 标签，选中右上角打勾），`showExercisePicker` 改返回
   `List<String>`，底部「添加 N 个动作」批量带回；选中状态两页签共享。
3. **首次添加引导默认参数**：`WorkoutController` 增加用户默认
   组数/次数/重量（键 `workoutDefaults`，未配置时首次添加动作后弹窗引导，
   可跳过=保持 3 组 × 10 次且不再提示）；保存后**同步套用当前清单**并用于
   之后所有 `addExercise`；弹窗控件复用规划卡片的步进器。
   `addExercise` 改用用户默认值（原先写死 3 × 10）。

测试 53 → 56 项（默认夹语义 / 弹层网格与批量加 / 默认参数引导与持久化）。
另：测试助手 pumpApp 用 `tester.runAsync` 放行真实异步，解决
SharedPreferences 在 FakeAsync 环境下加载不完成导致的服务态不确定问题；
finder 对非选中 IndexedStack 子树会跳过（视为离台），涉及跨 Tab 断言时注意。

### 阶段12 挑动作弹层两级浏览 ✅ 已完成（需求调整，后按需求改为按器材分类）

「搜索动作库」页签重构为两级结构，取消「全部」平铺网格，**分类维度为器材**：

- **一级（器材总览）**：28 张器材卡片（代表图 + 名称 + 数量，
  按全库数量降序：徒手/哑铃/拉索/杠铃…），点卡片进入器材页
  （`LibraryController` 增加 `equipmentCounts` / `equipmentRepresentative`）；
- **二级（器材内）**：动作按**部位分组模块**展示（胸部/背部/肩部…，
  固定业务顺序、0 结果的组不显示），每组标题「部位名 N」+ 卡片网格；
- **搜索框两级通用**：总览级搜全库、器材级只搜该器材，有输入时直接展示
  结果网格（忽略分组）；清空搜索回到所在层级；
- **部位筛选 chips**（搜索框下方，两级通用）：选某部位后，一级器材卡片只
  显示有该部位动作的器材（数量为该部位范围、0 结果隐藏），二级只显示该
  部位分组；芯片计数在一级为全库部位数、二级为器材范围内数量；
  「全部」恢复；与搜索叠加生效；
- 多选状态跨层级/跨搜索保留（批量添加的预期行为），底部「添加 N 个动作」
  一次带回；「收藏」页签不变。

测试 56 项不变（重写挑动作交互用例覆盖两级导航、分组与跨层级多选）。

### 阶段13 休息提醒重做、历史再训练、返回键与执行页动图 ✅ 已完成（需求调整）

1. **组间休息到点提醒重做**（原实现实测到点不响）：
   - 原来的问题：a) Android 14 起 `SCHEDULE_EXACT_ALARM` 默认未授予，
     精确预约抛异常被 catch，到点通知从未安排成功；b) 旧桥接在**自然结束**
     时也走了 `cancelAll`——最后一次 tick 后剩余读数是 1，`> 0` 判定误判为
     「未走完」，预约成功也会被自己撤掉；c) 渠道创建后设置不可更改。
   - 新设计（`RestAlarmService` 重写 + `MainActivity.kt` 新增 `rest_alarm`
     MethodChannel）：
     - **主路径 = 本机直接响铃**：app 存活时倒计时走完的瞬间，经
       MethodChannel 调原生 `RingtoneManager` 播放**手机当前设置的默认
       闹铃声**（未设置则回退通知声/铃声，走闹钟音量）+ 波形震动，不依赖
       任何闹钟权限，前台后台都即时；默认音可能很长，4 秒后主动停。
     - **兜底路径 = 系统通知**：休息开始时预约到点通知
       （`canScheduleExactNotifications` 判定，可用则精确闹钟，否则非精确），
       仅当 app 被杀（Dart 不再运行）时触发；预约时刻加 3 秒余量，本机
       路径正常时先到点并撤销它，避免双重提醒。
     - 通知渠道 v2（`rest_alert_v2`）：默认闹铃声 URI +
       `AudioAttributesUsage.alarm` + 震动样式；`+15s` 延长时兜底闹钟按
       新剩余时间重排，常驻通知进度条基准同步。
   - 控制器新增 `RestEndReason`（completed / skipped）：自然走完 = 响铃
     提醒；跳过休息、跳过动作、提前结束 = 静默撤销。桥接按此分流，
     替代旧的「剩余 > 0」误判。
2. **历史训练可重新训练**：`WorkoutController.repeatRecord(id)` 按记录的
   计划值（组/次/重量）载入规划态、进度清零；历史卡片展开后新增
   「再练一次」按钮，可反复点击。
3. **系统返回键统一**（`HomeShell` PopScope）：压在根路由上的页面
   （浏览页/收藏夹内页/弹层）逐层正常 pop；训练/收藏 Tab 的返回被拦截并
   切回主页 Tab；主页 Tab 不拦截（系统默认退出应用）。
4. **训练中按详情样式展示当前动作**：详情弹窗正文抽为共用组件
   `ExerciseDetailBody`（动图媒体区 + 部位/器材/目标肌肉元信息 +
   主要/次要肌群 + 编号步骤），执行页在动作名与组进度/间歇倒计时
   **之后**复用它（向下滚动翻看），两处样式完全一致；动图 Animated
   WebP 循环播放（限高 240）。倒计时保持在正文上方——休息时最需要
   的信息不被长内容挤出首屏。

测试 56 → 58 项（历史重新训练、返回键导航；倒计时用例补充结束原因断言），
`flutter analyze` 0 issue。

### 阶段7 数据与体积优化（可选）

1. 包体积：assets 共 52MB，安卓发布建议 `flutter build apk --release --split-per-abi`；
   进一步优化可将媒体改为首次启动后下载（`assets` 移出包体）。
2. 性能：缩略图是 180×180 webp，卡片网格滚动无压力；如上 2x 高清图再考虑
   `ResizeImage`/`cacheWidth`。
3. 数据更新：只需替换 `assets/data/exercises.json`（字段以 `docs/exercises.schema.json` 为准）；
   将来接数据库/远端时替换 `ExerciseRepository` 实现即可，上层零改动。

## 四、常用命令

```bash
flutter run                # 连接的安卓设备/模拟器
flutter analyze            # 静态检查（当前 0 issue）
flutter test               # 单元+组件测试（当前 58 项全过）
flutter build apk --release --split-per-abi
```

## 五、注意事项

- `exercises.json` 为 UTF-8 中文，**不要**用会转码的编辑器/工具处理；Dart 侧统一 `utf8` 读取。
- `videos/` 目录实际是 **Animated WebP 动图**（非视频文件），Flutter 图片解码器原生支持，无需视频播放器。
- JSON（1.8MB）在移动端由后台 isolate 解析；若日后重新启用 Web 平台，`compute` 会自动回退主线程。
- 网格卡片用固定 `childAspectRatio: 0.55` + 媒体区 `Expanded` 吸收高度，不会溢出；
  若未来要「名称行数不一致的瀑布流」，再引入 staggered grid 包。
