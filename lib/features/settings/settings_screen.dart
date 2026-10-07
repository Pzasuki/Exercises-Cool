import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/theme_service.dart';
import '../../state/workout_controller.dart';
import '../workout/widgets/steppers.dart';
import '../workout/widgets/workout_header.dart';

/// 设置 Tab：外观（主题颜色）、训练（默认训练参数）、关于（应用介绍）。
/// 主题色切换由 [ThemeService] 持久化，切换后整树重建生效。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WorkoutHeader(title: '设置'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: const [
                  _SectionHeader('外观'),
                  _ThemeColorCard(),
                  _SectionHeader('训练'),
                  _DefaultParamsCard(),
                  _SectionHeader('关于'),
                  _AboutCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分区标题（与训练页的分区标题同款）。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppText.sectionTitle),
      ),
    );
  }
}

/// 主题色选择卡：预设色板圆形色块，选中带对勾与描边环，点击即切换。
class _ThemeColorCard extends StatelessWidget {
  const _ThemeColorCard();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ThemeService>();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.presetName ?? '自定义',
            style: const TextStyle(
              fontSize: AppText.fsCaption,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (name, color) in ThemeService.presets)
                _ThemeSwatch(
                  color: color,
                  name: name,
                  selected: service.accentColor == color,
                  onTap: () => service.setAccent(color),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.textPrimary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 20, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: AppText.fsMicro,
              color:
                  selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 默认训练参数卡：组数/次数/重量步进，改动即保存并套用到之后的动作。
class _DefaultParamsCard extends StatelessWidget {
  const _DefaultParamsCard();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutController>();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '添加动作时自动套用的组数、次数与重量',
            style: TextStyle(
              fontSize: AppText.fsCaption,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              NumberStepper(
                label: '组',
                value: controller.defaultSets,
                min: 1,
                max: 20,
                onChanged: (v) => controller.saveDefaults(
                  sets: v,
                  reps: controller.defaultReps,
                  weight: controller.defaultWeight,
                ),
              ),
              NumberStepper(
                label: '次/组',
                value: controller.defaultReps,
                min: 1,
                max: 100,
                onChanged: (v) => controller.saveDefaults(
                  sets: controller.defaultSets,
                  reps: v,
                  weight: controller.defaultWeight,
                ),
              ),
              WeightStepper(
                weight: controller.defaultWeight,
                onChanged: (v) => controller.saveDefaults(
                  sets: controller.defaultSets,
                  reps: controller.defaultReps,
                  weight: v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 关于卡：应用介绍 + 版本 + 数据说明。
class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  text: '动作',
                  style: const TextStyle(
                    fontSize: AppText.fsHeading,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(text: '库', style: TextStyle(color: AppColors.accent)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: AppText.fsCaption,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '离线健身动作库：内置全量动作的动图演示与分步说明，'
            '支持按部位/器材/目标肌肉筛选、训练规划与打点、组间倒计时提醒、'
            '收藏夹管理。所有数据保存在本机，无需联网。',
            style: TextStyle(
              fontSize: AppText.fsBodySm,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置卡片统一装饰：白底 + 细边框 + 圆角。
BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      border: Border.all(color: AppColors.border),
    );
