import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/widgets/action_theme_mark.dart';
import 'package:interface_incendies_gironde/widgets/brand_mark.dart';

void main() {
  testWidgets('the global MobSanté mark stays neutral', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark())),
    );

    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(assets, [BrandMark.officialAssetPath]);
  });

  testWidgets('fire decorates only the Action context', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ActionThemeMark(themeKey: 'fire')),
      ),
    );

    expect(find.byKey(const Key('action-theme-fire')), findsOneWidget);
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName);
    expect(assets, [
      BrandMark.officialAssetPath,
      ActionThemeMark.fireAssetPath,
    ]);
    expect(actionThemeLabel('fire'), 'Thème feu');
  });

  for (final themeKey in <String?>[null, 'neutral', 'unknown']) {
    testWidgets('Action $themeKey keeps a neutral mark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActionThemeMark(themeKey: themeKey)),
        ),
      );

      expect(find.byKey(const Key('action-theme-neutral')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(actionThemeLabel(themeKey), isNull);
    });
  }

  testWidgets('other themes use generic symbols without the fire asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ActionThemeMark(themeKey: 'flood')),
      ),
    );

    expect(find.byKey(const Key('action-theme-flood')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.water_outlined), findsOneWidget);
  });
}
