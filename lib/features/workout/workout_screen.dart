import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/workout_controller.dart';
import 'views/idle_view.dart';
import 'views/planning_view.dart';
import 'views/running_view.dart';
import 'views/summary_view.dart';

/// 训练 Tab：按控制器状态机分流
/// idle（模板 + 历史 + 开始入口）→ planning（挑动作/组次/重量/间歇）→
/// running（做组打点 + 间歇倒计时）→ finished（感受 + 总结/存模板）。
/// 各视图见 views/，共用小组件见 widgets/。
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return switch (controller.status) {
      WorkoutStatus.idle => const IdleView(),
      WorkoutStatus.planning => const PlanningView(),
      WorkoutStatus.running => const RunningView(),
      WorkoutStatus.finished => const SummaryView(),
    };
  }
}
