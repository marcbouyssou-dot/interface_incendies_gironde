import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/theme/coordinator_identity.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/widgets/responsible_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  test('light V5 functional colors meet AA for small text', () {
    const colors = V5Colors.light;

    _expectAa(colors.onAccent, colors.accent, 'Responsable orange CTA');
    _expectAa(colors.accent, colors.warningContainer, 'selected orange state');
    _expectAa(colors.success, colors.successContainer, 'success state');
    _expectAa(colors.warning, colors.warningContainer, 'warning state');
    _expectAa(colors.danger, colors.dangerContainer, 'danger state');
    _expectAa(colors.textSecondary, colors.canvas, 'secondary text on canvas');
    _expectAa(
      colors.textSecondary,
      colors.surface,
      'secondary text on surface',
    );
    _expectAa(
      colors.disabledForeground,
      colors.disabledBackground,
      'disabled text',
    );
  });

  test('role identities remain distinct and AA compliant', () {
    const colors = V5Colors.light;

    _expectAa(Colors.white, colors.info, 'Professionnel blue');
    _expectAa(colors.onAccent, colors.accent, 'Responsable orange');
    _expectAa(
      CoordinatorIdentity.light.onAccent,
      CoordinatorIdentity.light.accent,
      'Coordinateur purple',
    );
    _expectAa(Colors.white, AppColors.red, 'urgent red');
    _expectAa(AppColors.green, AppColors.greenSoft, 'legacy success');
    _expectAa(AppColors.orange, AppColors.orangeSoft, 'legacy warning');
    _expectAa(AppColors.red, AppColors.redSoft, 'legacy danger');
    _expectAa(AppColors.textMuted, AppColors.background, 'legacy secondary');
  });

  test('dark V5 semantic and disabled colors remain AA compliant', () {
    const colors = V5Colors.dark;

    _expectAa(colors.onAccent, colors.accent, 'dark CTA');
    _expectAa(colors.success, colors.successContainer, 'dark success');
    _expectAa(colors.warning, colors.warningContainer, 'dark warning');
    _expectAa(colors.danger, colors.dangerContainer, 'dark danger');
    _expectAa(colors.textSecondary, colors.canvas, 'dark secondary');
    _expectAa(
      colors.disabledForeground,
      colors.disabledBackground,
      'dark disabled',
    );
  });

  testWidgets('responsible selected tab uses the AA orange token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: ResponsibleBottomNavigation(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    final selectedLabel = tester.widget<Text>(find.text('Accueil'));
    expect(selectedLabel.style?.color, V5Colors.light.accent);
    _expectAa(
      selectedLabel.style!.color!,
      V5Colors.light.canvas,
      'selected Responsable tab',
    );
  });

  testWidgets('publication CTA keeps white text with AA contrast', (
    tester,
  ) async {
    final center = places.firstWhere(
      (place) => place.isOperational && place.isEnabled,
    );
    final repository = MockCoordinationRepository(
      responsibleAccess: ResponsibleAccess(
        uid: 'contrast-responsible',
        role: ResponsibleRole.siteManager,
        locationIds: {center.id},
        active: true,
      ),
      initialLocations: [center],
    );
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('responsible-create-need')));
    await tester.pumpAndSettle();

    final publish = tester.widget<V5Button>(
      find.byKey(const Key('publish-mission')),
    );
    expect(publish.foregroundColor, Colors.white);
    _expectAa(
      publish.foregroundColor!,
      publish.backgroundColor!,
      'publication CTA',
    );
  });

  testWidgets('disabled V5 button uses opaque accessible neutral colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: V5Button(
            key: Key('disabled-button'),
            onPressed: null,
            label: 'Indisponible',
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('disabled-button')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    final label = tester.widget<Text>(find.text('Indisponible'));
    expect(decoration.color, V5Colors.light.disabledBackground);
    expect(label.style?.color, V5Colors.light.disabledForeground);
    _expectAa(label.style!.color!, decoration.color!, 'disabled V5 button');
  });
}

void _expectAa(Color foreground, Color background, String usage) {
  expect(
    _contrastRatio(foreground, background),
    greaterThanOrEqualTo(4.5),
    reason: '$usage must meet WCAG AA for small text',
  );
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lightest = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darkest = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lightest + 0.05) / (darkest + 0.05);
}
