/// 展示格式化工具：训练相关数值 → 用户可读文本。
library;

/// 重量显示：整数不带小数位，其余保留 1 位。
String formatWeight(double? weight) {
  if (weight == null) return '';
  return weight % 1 == 0
      ? weight.toStringAsFixed(0)
      : weight.toStringAsFixed(1);
}

/// 秒数 → m:ss（组间倒计时等）。
String formatClock(int total) {
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
