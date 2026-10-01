/// 尺寸 tokens，对应 `:root` 的 `--radius-*` 与 index.html 中的布局尺寸。
abstract final class AppDimens {
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
  static const double radiusXl = 18;

  /// 卡片媒体区比例（`.card-media { aspect-ratio: 3/4 }`）。
  static const double cardMediaAspectRatio = 3 / 4;

  // ── 网格：桌面 minmax(190px,1fr)/gap14；≤768px minmax(148px,1fr)/gap10 ──
  static const double gridCardMaxExtent = 190;
  static const double gridCardMaxExtentNarrow = 148;
  static const double gridSpacing = 14;
  static const double gridSpacingNarrow = 10;

  /// 网格水平内边距：桌面 20 / 移动 12（`.grid-wrapper`）。
  static const double gridHPadding = 20;
  static const double gridHPaddingNarrow = 12;
}
