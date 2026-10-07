import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../state/library_controller.dart';

/// 搜索框（对应 .search-box）：输入经 LibraryController 防抖后过滤。
/// 总览页顶栏与侧栏面板共用同一 controller.search，输入框文本双向同步——
/// 「清除全部」等入口清空时这里同步清空（对应原版 searchEl.value = ''）；
/// 从其他页面带搜索返回时（未聚焦状态）也回填显示。
///
/// 同步不变量：每屏同时最多一个可见搜索框。聚焦态只接受自己的打字回声
/// （防抖生效后 search == 文本），未聚焦态负责镜像其他入口对搜索词的
/// 改动；「search 为空」的外部清空即使在聚焦态也强制回写。
class SearchField extends StatefulWidget {
  const SearchField({super.key});

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 本输入框所在视图（didChangeDependencies 时缓存，供观察器读取）。
  FlutterView? _view;

  /// 上一时刻键盘是否可见，用于识别「键盘已收起但焦点仍在」的时刻。
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = _view;
    if (view == null) return;
    // 注意不能用 widget 树的 MediaQuery 判断：Scaffold
    // （resizeToAvoidBottomInset）会把 body 内的 viewInsets 清零，
    // 必须读视图的原始 insets。
    final visible = view.viewInsets.bottom > 0;
    // 系统返回/收起键只会隐藏键盘、不会清掉焦点；焦点悬空时，之后切
    // Tab、开弹层、返回等任意操作都会把输入法再拉起来。这里在
    // 「键盘可见 → 不可见」的跳变时刻主动释放焦点。
    if (_keyboardVisible && !visible && _focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _keyboardVisible = visible;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LibraryController>();
    // 外部改了搜索词且输入框不在编辑态时，用 postFrame 同步，避免构建期触发监听器。
    final needsSync = controller.search != _textController.text &&
        (controller.search.isEmpty || !_focusNode.hasFocus);
    if (needsSync) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textController.text != controller.search) {
          _textController.text = controller.search;
        }
      });
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textController,
      builder: (context, value, _) => TextField(
        controller: _textController,
        focusNode: _focusNode,
        onChanged: (v) => context.read<LibraryController>().setSearch(v),
        decoration: InputDecoration(
          hintText: '搜索动作…',
          prefixIcon: const Icon(
            Icons.search,
            size: 16,
            color: AppColors.textTertiary,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: () {
                    _textController.clear();
                    context.read<LibraryController>().clearSearch();
                  },
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ),
        ),
      ),
    );
  }
}
