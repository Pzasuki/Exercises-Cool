import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题服务：应用内可切换的主题色（accent），持久化到
/// shared_preferences（键 themeAccent）。全局单例——[AppColors.accent]
/// 等 token 在非 build 上下文也要能读到当前值。
class ThemeService extends ChangeNotifier {
  ThemeService() {
    _load();
  }

  /// 全局单例：静态 token（AppColors.accent）与 provider 共用同一实例。
  static final ThemeService instance = ThemeService();

  static const String _prefKey = 'themeAccent';

  /// 默认主题色（原版品牌橙）。
  static const Color defaultAccent = Color(0xFFFF4F00);

  /// 预设主题色（名称 + 色值），设置页展示。
  static const List<(String, Color)> presets = [
    ('活力橙', defaultAccent),
    ('深海蓝', Color(0xFF2563EB)),
    ('翡翠绿', Color(0xFF16A34A)),
    ('罗兰紫', Color(0xFF7C3AED)),
    ('玫瑰红', Color(0xFFE11D48)),
    ('松石青', Color(0xFF0D9488)),
  ];

  Color _accentColor = defaultAccent;

  /// 当前主题色。
  Color get accentColor => _accentColor;

  /// 当前主题色在预设中的名称（自定义值时返回 null）。
  String? get presetName {
    for (final (name, color) in presets) {
      if (color == _accentColor) return name;
    }
    return null;
  }

  Future<void> setAccent(Color color) async {
    if (color == _accentColor) return;
    _accentColor = color;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, color.toARGB32());
    } catch (_) {
      // 存储不可用（如测试环境）时保持内存态
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_prefKey);
      if (value != null) {
        _accentColor = Color(value);
        notifyListeners();
      }
    } catch (_) {
      // 存储不可用时保持默认
    }
  }
}
