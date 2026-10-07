import 'package:flutter/material.dart'
    show AlertDialog, Icons, Offset, Size, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exercises_app/state/favorites_service.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FavoritesService', () {
    test('默认收藏夹：内置存在、点收藏直接进、不可改名/删除', () async {
      final service = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 服务加载后内置默认收藏夹始终存在
      expect(service.folders.first.id, FavoritesService.defaultFolderId);
      expect(service.folders.first.name, '默认收藏');

      service.toggleDefault('e1');
      expect(service.isFavorite('e1'), isTrue);
      expect(
        service.folderIdsOf('e1'),
        <String>{FavoritesService.defaultFolderId},
      );

      // 默认夹不可改名/删除
      service.renameFolder(FavoritesService.defaultFolderId, '改名');
      service.deleteFolder(FavoritesService.defaultFolderId);
      expect(service.folders.first.name, '默认收藏');
      expect(service.isFavorite('e1'), isTrue);
    });

    test('新建收藏夹 + 多夹收藏 + 查询', () async {
      final service = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final f1 = service.createFolder('腿部日');
      final f2 = service.createFolder('推举日');
      service.addToFolder(f1, 'e1');
      service.toggleInFolder(f2, 'e1');
      service.addToFolder(f1, 'e2');

      // 默认夹 + 两个新建夹
      expect(service.folders, hasLength(3));
      expect(service.isFavorite('e1'), isTrue);
      expect(service.isFavorite('e2'), isTrue);
      expect(service.isFavorite('e3'), isFalse);
      // e1 只进了 f1/f2，未进默认夹
      expect(service.folderIdsOf('e1'), <String>{f1, f2});
    });

    test('移除收藏与删除收藏夹', () async {
      final service = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final f1 = service.createFolder('夹A');
      service.addToFolder(f1, 'e1');
      service.removeFromFolder(f1, 'e1');
      expect(service.isFavorite('e1'), isFalse);

      service.addToFolder(f1, 'e2');
      service.deleteFolder(f1);
      // 默认夹仍在
      expect(service.folders.single.id, FavoritesService.defaultFolderId);
      expect(service.isFavorite('e2'), isFalse);
    });

    test('重命名收藏夹', () async {
      final service = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final f1 = service.createFolder('旧名');
      service.renameFolder(f1, '新名');
      expect(
        service.folders.where((f) => f.id == f1).single.name,
        '新名',
      );
    });

    test('移动动作到其他收藏夹', () async {
      final service = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final f1 = service.createFolder('夹A');
      final f2 = service.createFolder('夹B');
      service.addToFolder(f1, 'e1');

      service.moveExercise(f1, f2, 'e1');
      expect(service.folderIdsOf('e1'), <String>{f2});
      expect(
        service.folders.where((f) => f.id == f1).single.exerciseIds,
        isEmpty,
      );

      // 目标夹已含该动作：源夹移除、目标夹不重复
      service.addToFolder(f2, 'e2');
      service.addToFolder(f1, 'e2');
      service.moveExercise(f1, f2, 'e2');
      expect(service.folderIdsOf('e2'), <String>{f2});
      expect(
        service.folders.where((f) => f.id == f2).single.exerciseIds,
        ['e1', 'e2'],
      );
    });

    test('持久化：重建服务后数据还原', () async {
      final service = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final f1 = service.createFolder('持久');
      service.addToFolder(f1, 'e1');

      final reloaded = FavoritesService();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final persisted =
          reloaded.folders.where((f) => f.id == f1).single;
      expect(persisted.name, '持久');
      expect(persisted.exerciseIds, ['e1']);
    });
  });

  group('收藏 Tab 组件', () {
    testWidgets('点收藏进默认列表，长按选收藏夹，收藏页可见并可移除', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));

      // 进入收藏 Tab：内置默认收藏夹
      await tester.tap(find.text('收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('默认收藏'), findsOneWidget);
      expect(find.text('0 个动作'), findsOneWidget);

      // 回动作库，打开第一个动作详情
      await tester.tap(find.text('动作库'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await enterBrowse(tester);
      await tester.tap(find.text('四分之三仰卧起坐'));
      await pumpFor(tester, const Duration(milliseconds: 300));

      // 点收藏按钮 → 直接收进默认收藏（不弹收藏夹选择）
      await tester.tap(find.byIcon(Icons.favorite_outline));
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('收藏到收藏夹'), findsNothing);

      // 长按收藏按钮 → 收藏夹弹层（默认收藏已勾选）→ 新建收藏夹并收入
      await tester.longPress(find.byIcon(Icons.favorite));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('收藏到收藏夹'), findsOneWidget);
      // 弹层里的「默认收藏」行（收藏页 Tab 处于非选中 IndexedStack 子树，finder 跳过）
      expect(find.text('默认收藏'), findsOneWidget);

      await tester.tap(find.text('新建收藏夹'));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '腹部基础',
      );
      await tester.tap(find.text('确定'));
      await pumpFor(tester, const Duration(milliseconds: 200));

      // 弹层里新夹已被勾选；点遮罩关闭弹层
      expect(find.text('腹部基础'), findsOneWidget);
      await tester.tapAt(const Offset(30, 100));
      await pumpFor(tester, const Duration(milliseconds: 300));

      // 关闭详情并返回总览（浏览页没有底部导航）
      await tester.tap(find.byIcon(Icons.close));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(backButton());
      await pumpFor(tester, const Duration(milliseconds: 400));

      // 收藏 Tab：两个夹各 1 个动作，进「腹部基础」可见并可移除
      await tester.tap(find.text('收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('腹部基础'), findsOneWidget);
      expect(find.text('1 个动作'), findsNWidgets(2));

      await tester.tap(find.text('腹部基础'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('四分之三仰卧起坐'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.textContaining('收藏夹还是空的'), findsOneWidget);
    });

    testWidgets('多收藏夹时点收藏：弹出收藏夹选择（不静默加默认）', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));

      // 先建一个非默认收藏夹
      await tester.tap(find.text('收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '测试夹',
      );
      await tester.tap(find.text('确定'));
      await pumpFor(tester, const Duration(milliseconds: 200));

      // 打开动作详情，点收藏 → 弹出选择弹层（而非直接进默认收藏）
      await tester.tap(find.text('动作库'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await enterBrowse(tester);
      await tester.tap(find.text('四分之三仰卧起坐'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.favorite_outline));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('收藏到收藏夹'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // 弹层里勾选「默认收藏」→ 收藏生效
      await tester.tap(find.text('默认收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.favorite), findsNWidgets(2)); // 详情按钮 + 弹层行

      // 点遮罩关闭弹层 → 关闭详情 → 收藏 Tab 验证
      await tester.tapAt(const Offset(30, 100));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.close));
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(backButton());
      await pumpFor(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      expect(find.text('1 个动作'), findsOneWidget); // 仅默认收藏含该动作
    });

    testWidgets('收藏夹内移动动作到其他收藏夹', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(tester, await loadExercises(tester));

      // 准备：新建「测试夹」；收藏动作（多夹存在 → 弹层里勾选默认收藏）
      await tester.tap(find.text('收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await pumpFor(tester, const Duration(milliseconds: 200));
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        '测试夹',
      );
      await tester.tap(find.text('确定'));
      await pumpFor(tester, const Duration(milliseconds: 200));

      await tester.tap(find.text('动作库'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await enterBrowse(tester);
      await tester.tap(find.text('四分之三仰卧起坐'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.favorite_outline));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('默认收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(30, 100));
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byIcon(Icons.close));
      await pumpFor(tester, const Duration(milliseconds: 400));
      // 返回总览（浏览页没有底部导航），再切收藏 Tab
      await tester.tap(backButton());
      await pumpFor(tester, const Duration(milliseconds: 400));

      // 进「默认收藏」夹内页：动作条目带移动入口
      await tester.tap(find.text('收藏'));
      await pumpFor(tester, const Duration(milliseconds: 100));
      await tester.tap(find.text('默认收藏'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('四分之三仰卧起坐'), findsOneWidget);

      // 点移动 → 弹层选「测试夹」→ 从当前夹消失
      await tester.tap(find.byIcon(Icons.drive_file_move_outlined));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('移动到其他收藏夹'), findsOneWidget);
      await tester.tap(find.text('测试夹'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.textContaining('收藏夹还是空的'), findsOneWidget);

      // 「测试夹」内可见该动作
      await tester.tap(backButton());
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('测试夹'));
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(find.text('四分之三仰卧起坐'), findsOneWidget);
    });
  });
}
