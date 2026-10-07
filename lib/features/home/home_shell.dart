import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../services/rest_alarm_service.dart';
import '../favorites/favorites_screen.dart';
import '../overview/overview_screen.dart';
import '../settings/settings_screen.dart';
import '../workout/workout_screen.dart';

/// 底部导航的四个 Tab（图标用描边系，选中态由颜色 + 胶囊指示表达）。
const List<(String, IconData)> kHomeTabs = [
  ('动作库', Icons.grid_view_rounded),
  ('训练', Icons.play_circle_outline_rounded),
  ('收藏', Icons.favorite_outline_rounded),
  ('设置', Icons.settings_outlined),
];

/// 应用主框架：底部悬浮玻璃导航（4 Tab）+ PageView 左右滑动切换。
/// 各 Tab 用 KeepAlive 包裹：访问过后保持挂载（滚动位置、表单态等），
/// 训练进行中的状态本体在 WorkoutController（provider 级），不受影响。
/// 系统返回键：主页 Tab 走系统默认（退出应用）；其他 Tab 拦截并切回主页。
/// 压在根路由之上的页面（浏览页/收藏夹内页/弹层）由 Navigator 正常逐层
/// pop，不受影响。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final PageController _pageController;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // 点击系统通知（组间倒计时/休息结束）→ 落到训练 Tab。
    // 冷启动时原生推送可能先于本页注册到达，先消费缓存的跳转请求。
    if (RestAlarmService.instance.consumePendingOpenWorkout()) {
      _tab = 1;
    }
    RestAlarmService.onOpenWorkoutRequested = _openWorkoutTab;
    _pageController = PageController(initialPage: _tab);
  }

  @override
  void dispose() {
    RestAlarmService.onOpenWorkoutRequested = null;
    _pageController.dispose();
    super.dispose();
  }

  void _openWorkoutTab() {
    if (!mounted) return;
    _switchTab(1);
  }

  /// 切 Tab：释放输入焦点（搜索框焦点不释放会跟着 PageView 跑），
  /// 点导航用 jumpToPage（无动画、目标页立即就位），滑动手势由
  /// PageView 自带的拖拽跟手动画承担。
  void _switchTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _switchTab(0);
      },
      child: Scaffold(
        // 内容延伸到悬浮导航栏下方（毛玻璃才有内容可模糊）
        extendBody: true,
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _tab = index);
          },
          children: const [
            _KeepAlivePage(child: OverviewScreen()),
            _KeepAlivePage(child: WorkoutScreen()),
            _KeepAlivePage(child: FavoritesScreen()),
            _KeepAlivePage(child: SettingsScreen()),
          ],
        ),
        bottomNavigationBar: GlassNavBar(
          currentIndex: _tab,
          onTap: _switchTab,
        ),
      ),
    );
  }
}

/// 包一层 KeepAlive：PageView 滑过/切走的页面保持状态不销毁。
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 悬浮玻璃导航栏：胶囊造型 + 毛玻璃（BackdropFilter）+ 半透明白底 +
/// 投影，悬浮于内容之上（Scaffold extendBody 让内容从栏下滚过）。
/// 选中项为主题色图标文字 + 主题色胶囊指示。
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    for (final (index, (label, icon)) in kHomeTabs.indexed)
                      Expanded(
                        child: InkWell(
                          onTap: () => onTap(index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 52,
                                height: 27,
                                alignment: Alignment.center,
                                decoration: index == currentIndex
                                    ? BoxDecoration(
                                        color: AppColors.accentMuted,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      )
                                    : null,
                                child: Icon(
                                  icon,
                                  size: 22,
                                  color: index == currentIndex
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: AppText.fsMicro,
                                  fontWeight: index == currentIndex
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: index == currentIndex
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
