import 'package:campura_one_student/src/demo_data.dart';
import 'package:campura_one_student/src/app_shell.dart';
import 'package:campura_one_student/src/home_page.dart';
import 'package:campura_one_student/src/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo search respects product and shop modes', () {
    expect(
      searchDemo('咖啡', SearchMode.product).map((e) => e.kind),
      contains('product'),
    );
    expect(
      searchDemo('咖啡', SearchMode.product).map((e) => e.kind),
      isNot(contains('shop')),
    );
    expect(
      searchDemo('咖啡', SearchMode.shop).map((e) => e.kind),
      contains('shop'),
    );
  });

  testWidgets('home course tile expands into course detail', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: HomePage(onOpenProfile: () {})),
      ),
    );
    expect(find.text('Today和精选'), findsOneWidget);
    await tester.tap(find.text('课程表').first);
    await tester.pumpAndSettle();
    expect(find.text('当天共'), findsNothing);
    expect(find.textContaining('演示课表'), findsOneWidget);
  });

  testWidgets('search history is shown after a submitted query', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SearchPage()));
    await tester.enterText(find.byType(SearchBar), '咖啡');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('拿铁咖啡'), findsWidgets);
  });

  testWidgets('Markdown notices and short notices have separate entry pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomePage(onOpenProfile: () {})),
      ),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('important-notice-entry')))
          .height,
      tester.getSize(find.byKey(const ValueKey('short-notice-entry'))).height,
    );
    await tester.tap(find.byIcon(Icons.priority_high_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('重要通知'), findsOneWidget);
    expect(find.text('短通知'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('摘要不可用 · 演示通知'));
    await tester.pumpAndSettle();
    expect(find.text('短通知'), findsOneWidget);
    expect(find.text('重要通知'), findsNothing);
  });

  testWidgets('floating tab bar keeps dashboard left and map right', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData(useMaterial3: true), home: const AppShell()),
    );
    await tester.pump();

    final bar = tester.getRect(find.byKey(const ValueKey('floating-tab-bar')));
    expect(bar.left, greaterThan(0));
    expect(bar.right, lessThan(393));
    expect(
      tester.getCenter(find.text('仪表盘')).dx,
      lessThan(tester.getCenter(find.text('地图')).dx),
    );

    await tester.tap(find.text('地图'));
    await tester.pumpAndSettle();
    expect(find.text('搜索促销、商品和商户'), findsOneWidget);
  });
}
