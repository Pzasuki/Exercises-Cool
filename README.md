# 动作库（Exercises App · Flutter）

健身动作应用：1324 个动作，两级浏览（分类总览 → 分类内筛选）、
按分类/器材/目标肌肉筛选（芯片带计数，0 结果隐藏），搜索、无限滚动、
动图预览与步骤说明；收藏夹、训练做组计数（组间可选倒计时）。
由 `www/` 网页版（Capacitor PWA）重构为 Flutter，目标平台 **Android**。

> 原网页版 `www/` 与 Flutter Web 目录 `web/` 已在重构完成后删除；
> 未翻译的原始版本在旁边的 `exercises-pzasuki233-main` / `-test` 仓库仍有完整备份。

## 目录结构

```
├── lib/
│   ├── main.dart                  # 入口：状态栏 + 启动引导（加载态/错误重试）
│   ├── app.dart                   # MaterialApp + 主题
│   ├── core/
│   │   ├── constants/             # 行为常量（分页、防抖、断点）
│   │   ├── theme/                 # CSS tokens 映射的颜色/尺寸/主题
│   │   └── i18n/                  # 中文术语表（zh()）
│   ├── data/
│   │   ├── models/                # Exercise / FavoriteFolder / 训练模板
│   │   └── repositories/          # 数据仓库（当前读 assets）
│   ├── state/
│   │   ├── library_controller.dart # 搜索/筛选/facet 计数/分页状态
│   │   ├── favorites_service.dart  # 收藏夹 CRUD + 持久化
│   │   └── workout_controller.dart # 训练状态机 + 模板持久化
│   └── features/
│       ├── home/                  # 底部 3 Tab 框架（动作库/训练/收藏）
│       ├── overview/              # 动作库 Tab：分类总览首页
│       ├── library/               # 分类浏览页（搜索/筛选/结果视图）
│       ├── detail/                # 动作详情弹窗（含收藏按钮）
│       ├── favorites/             # 收藏 Tab + 收藏夹选择弹层
│       └── workout/               # 训练 Tab（规划/做组/倒计时/模板）
├── assets/
│   ├── data/exercises.json        # 1324 条动作数据
│   ├── images/                    # 静态缩略图 ×1324
│   └── videos/                    # Animated WebP 动图 ×1324
├── docs/exercises.schema.json     # 数据 schema
└── test/                          # 单元+组件测试
```

## 运行

```bash
flutter pub get
flutter run               # 连接的安卓设备/模拟器
```

## 检查与测试

```bash
flutter analyze
flutter test
```
