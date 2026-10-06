import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/rest_alarm_service.dart';
import '../favorites/favorites_screen.dart';
import '../overview/overview_screen.dart';
import '../workout/workout_screen.dart';

/// 应用主框架：底部 3 Tab（动作库 / 训练 / 收藏），见 MIGRATION.md 阶段9。
/// IndexedStack 保持各 Tab 状态（滚动位置、训练进行中的状态等）。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
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
  }

  @override
  void dispose() {
    RestAlarmService.onOpenWorkoutRequested = null;
    super.dispose();
  }

  void _openWorkoutTab() {
    if (!mounted) return;
    setState(() => _tab = 1);
  }

  static const _tabs = [
    ('动作库', Icons.grid_view_rounded),
    ('训练', Icons.play_circle_outline_rounded),
    ('收藏', Icons.favorite_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    // 系统返回键：主页 Tab 走系统默认（退出应用）；训练/收藏 Tab 被拦截，
    // 切回主页 Tab。压在根路由之上的页面（浏览页/收藏夹内页/弹层）由
    // Navigator 正常逐层 pop，不受影响。
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: const [
            // 「动作库」Tab：分类总览（浏览页仍经 Navigator push，保持两级浏览）
            OverviewScreen(),
            WorkoutScreen(),
            FavoritesScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          height: 64,
          backgroundColor: AppColors.bgSurface,
          indicatorColor: AppColors.accentMuted,
          destinations: [
            for (final (label, icon) in _tabs)
              NavigationDestination(
                icon: Icon(icon, size: 22),
                label: label,
              ),
          ],
        ),
      ),
    );
  }
}
