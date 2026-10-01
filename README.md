# 动作库（Exercises App · Flutter）

健身动作浏览应用：1324 个动作，两级浏览（分类总览 → 分类内筛选）、
按分类/器材/目标肌肉筛选（芯片带计数与 0 结果置灰），搜索、无限滚动、
动图预览与步骤说明。由 `www/` 网页版（Capacitor PWA）重构为 Flutter，
目标平台 **Android**。

> 原网页版 `www/` 与 Flutter Web 目录 `web/` 已在重构完成后删除；
> 未翻译的原始版本在旁边的 `exercises-pzasuki233-main` / `-test` 仓库仍有完整备份。

## 目录结构

```
├── lib/
│   ├── main.dart                  # 入口：状态栏设置 + 数据加载
│   ├── app.dart                   # MaterialApp + 主题
│   ├── core/
│   │   ├── constants/             # 行为常量（分页、防抖、断点）
│   │   ├── theme/                 # CSS tokens 映射的颜色/尺寸/主题
│   │   └── i18n/                  # 中文术语表（zh()）
│   ├── data/
│   │   ├── models/                # Exercise 模型
│   │   └── repositories/          # 数据仓库（当前读 assets）
│   ├── state/
│   │   └── library_controller.dart # 搜索/筛选/facet 计数/分页状态
│   └── features/
│       ├── overview/              # 一级：分类总览首页（部位卡片 + 搜索）
│       ├── library/               # 二级：分类浏览页
│       │   └── widgets/           # 结果视图、快捷行、卡片、筛选面板等
│       └── detail/                # 动作详情弹窗
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
