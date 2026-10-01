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

测试 16 → 30 项（新增 `overview_test.dart` 两级浏览 6 项、facet/enterCategory/
分类索引等状态层 4 项、长按预览 1 项），`flutter analyze` 0 issue。

> 设计取舍：从总览进入分类会**重置**其他筛选（每次进入都是干净浏览态）；
> 总览搜索结果不带侧栏，筛选需清搜索后从部位进入（暂定，若高频再议）。

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
flutter test               # 单元+组件测试（当前 30 项全过）
flutter build apk --release --split-per-abi
```

## 五、注意事项

- `exercises.json` 为 UTF-8 中文，**不要**用会转码的编辑器/工具处理；Dart 侧统一 `utf8` 读取。
- `videos/` 目录实际是 **Animated WebP 动图**（非视频文件），Flutter 图片解码器原生支持，无需视频播放器。
- JSON（1.8MB）在移动端由后台 isolate 解析；若日后重新启用 Web 平台，`compute` 会自动回退主线程。
- 网格卡片用固定 `childAspectRatio: 0.55` + 媒体区 `Expanded` 吸收高度，不会溢出；
  若未来要「名称行数不一致的瀑布流」，再引入 staggered grid 包。
