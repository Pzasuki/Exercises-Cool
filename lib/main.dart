import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/models/exercise.dart';
import 'data/repositories/exercise_repository.dart';
import 'state/favorites_service.dart';
import 'state/library_controller.dart';
import 'state/workout_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 对应原版 Capacitor StatusBar 设置：内容延伸到状态栏后、浅色底深色图标。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 立即出首帧（加载态），1.8MB JSON 的读取 + 解析在 UI 就绪后进行；
  // 对应原版 init()，加载失败时展示错误页并提供「重试」。
  runApp(const ExerciseBootstrap());
}

/// 数据加载函数，测试可注入；默认从打包 assets 读取。
typedef ExerciseLoader = Future<List<Exercise>> Function();

/// 启动引导：加载态 → 总览页 / 可重试错误页。
class ExerciseBootstrap extends StatefulWidget {
  const ExerciseBootstrap({super.key, this.loader});

  final ExerciseLoader? loader;

  @override
  State<ExerciseBootstrap> createState() => _ExerciseBootstrapState();
}

class _ExerciseBootstrapState extends State<ExerciseBootstrap> {
  late Future<List<Exercise>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Exercise>> _load() =>
      (widget.loader ?? ExerciseRepository().loadAll)();

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Exercise>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }
        if (snapshot.hasError) {
          return _BootstrapError(error: snapshot.error!, onRetry: _retry);
        }
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LibraryController(snapshot.data!),
            ),
            ChangeNotifierProvider(create: (_) => FavoritesService()),
            ChangeNotifierProvider(create: (_) => WorkoutController()),
          ],
          child: const ExercisesApp(),
        );
      },
    );
  }
}

/// 数据加载期间的过渡页，衔接原生 splash（同底色，视觉上无缝）。
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// 数据加载失败时的兜底界面，带重试入口（原版只有错误提示）。
class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '动作数据加载失败',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '请确认 assets/data/exercises.json 是否存在。\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
