import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';

void main() {
  Widget app(
    Widget child, {
    ThemeMode themeMode = ThemeMode.light,
    Size size = const Size(390, 844),
  }) {
    return MaterialApp(
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 20),
        ),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('fields and section use V5 dark colors', (tester) async {
    await tester.pumpWidget(
      app(
        ListView(
          padding: const EdgeInsets.all(V5Spacing.lg),
          children: [
            const V5TextField(
              key: Key('text-field'),
              label: 'Email',
              hint: 'nom@exemple.fr',
            ),
            const SizedBox(height: V5Spacing.md),
            V5SelectField<String>(
              label: 'Profession',
              value: 'medecin',
              options: const [
                V5SelectOption(value: 'medecin', label: 'Médecin'),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: V5Spacing.md),
            V5DateField(
              label: 'Date',
              value: DateTime(2026, 8, 8),
              onChanged: (_) {},
            ),
            const SizedBox(height: V5Spacing.md),
            V5TimeField(
              label: 'Heure',
              value: const TimeOfDay(hour: 14, minute: 30),
              onChanged: (_) {},
            ),
            const SizedBox(height: V5Spacing.lg),
            const V5Section(
              key: Key('section'),
              title: 'Informations',
              subtitle: 'Champs autorisés',
              leading: Icon(Icons.person_outline_rounded),
              child: Text('Contenu'),
            ),
          ],
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.fillColor, V5Colors.dark.surfaceElevated);
    expect(
      Theme.of(tester.element(find.byKey(const Key('text-field')))).brightness,
      Brightness.dark,
    );
    final section = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('section')),
        matching: find.byType(Container),
      ),
    );
    expect(
      (section.decoration! as BoxDecoration).color,
      V5Colors.dark.surfaceElevated,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('V5TextField supports input and form validation', (tester) async {
    final semantics = tester.ensureSemantics();
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      app(
        Padding(
          padding: const EdgeInsets.all(V5Spacing.lg),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                V5TextField(
                  label: 'Email',
                  semanticLabel: 'Email professionnel',
                  isRequired: true,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Adresse email invalide'
                      : null,
                ),
                FilledButton(
                  onPressed: () => formKey.currentState!.validate(),
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse email invalide'), findsOneWidget);
    final invalidField = tester.getSemantics(
      find.bySemanticsLabel(
        RegExp(
          r'Email professionnel, obligatoire, Erreur : Adresse email invalide',
        ),
      ),
    );
    expect(invalidField.flagsCollection.isTextField, isTrue);
    expect('Email professionnel'.allMatches(invalidField.label), hasLength(1));
    expect(
      'Adresse email invalide'.allMatches(invalidField.label),
      hasLength(1),
    );
    expect(find.bySemanticsLabel('Email'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse email invalide'), findsNothing);
    expect(
      find.bySemanticsLabel('Email professionnel, obligatoire'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byType(TextFormField)).value,
      contains('123456'),
    );
    semantics.dispose();
  });

  testWidgets('V5SelectField opens its safe sheet and returns a value', (
    tester,
  ) async {
    String? selection;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => Padding(
            padding: const EdgeInsets.all(V5Spacing.lg),
            child: V5SelectField<String>(
              key: const Key('select'),
              label: 'Profession',
              sheetTitle: 'Choisir une profession',
              value: selection,
              options: const [
                V5SelectOption(value: 'medecin', label: 'Médecin'),
                V5SelectOption(
                  value: 'infirmier',
                  label: 'Infirmier',
                  subtitle: 'Diplôme d’État',
                ),
              ],
              onChanged: (value) => setState(() => selection = value),
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('select')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choisir une profession'), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);

    await tester.tap(find.text('Infirmier').last);
    await tester.pumpAndSettle();
    expect(selection, 'infirmier');
    expect(find.text('Infirmier'), findsOneWidget);
  });

  testWidgets('V5SelectField options expose selected state', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        Padding(
          padding: const EdgeInsets.all(V5Spacing.lg),
          child: V5SelectField<String>(
            key: const Key('selected-state-select'),
            label: 'Profession',
            value: 'medecin',
            options: const [
              V5SelectOption(value: 'medecin', label: 'Médecin'),
              V5SelectOption(value: 'infirmier', label: 'Infirmier'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('selected-state-select')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    final selected = tester.getSemantics(find.bySemanticsLabel('Médecin'));
    final unselected = tester.getSemantics(find.bySemanticsLabel('Infirmier'));
    expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(unselected.flagsCollection.isSelected, ui.Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('V5DateField and V5TimeField use Cupertino pickers', (
    tester,
  ) async {
    DateTime? selectedDate = DateTime(2026, 8, 8);
    TimeOfDay? selectedTime = const TimeOfDay(hour: 14, minute: 32);
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => ListView(
            padding: const EdgeInsets.all(V5Spacing.lg),
            children: [
              V5DateField(
                key: const Key('date'),
                label: 'Date',
                value: selectedDate,
                firstDate: DateTime(2026),
                lastDate: DateTime(2027),
                onChanged: (value) => setState(() => selectedDate = value),
              ),
              const SizedBox(height: V5Spacing.md),
              V5TimeField(
                key: const Key('time'),
                label: 'Heure',
                value: selectedTime,
                minuteInterval: 5,
                use24HourFormat: true,
                onChanged: (value) => setState(() => selectedTime = value),
              ),
            ],
          ),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('date')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(
      CupertinoTheme.of(
        tester.element(find.byType(CupertinoDatePicker)),
      ).brightness,
      Brightness.dark,
    );
    expect(
      tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).mode,
      CupertinoDatePickerMode.date,
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(selectedDate, DateTime(2026, 8, 8));

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('time')),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).mode,
      CupertinoDatePickerMode.time,
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(selectedTime, const TimeOfDay(hour: 14, minute: 30));
  });

  testWidgets('empty and loading states are safe and non-Material', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Column(
          children: [
            Expanded(
              child: V5EmptyState(
                title: 'Aucun résultat',
                message: 'Les éléments apparaîtront ici.',
              ),
            ),
            Expanded(child: V5LoadingState(label: 'Synchronisation…')),
          ],
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    expect(find.byType(SafeArea), findsNWidgets(2));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Aucun résultat'), findsOneWidget);
    expect(find.text('Synchronisation…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('V5Dialog and V5Confirmation return explicit results', (
    tester,
  ) async {
    bool? confirmation;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                key: const Key('open-dialog'),
                onPressed: () => showV5Dialog<void>(
                  context: context,
                  builder: (dialogContext) => V5Dialog(
                    title: 'Information',
                    message: 'Le profil est enregistré.',
                    actions: [
                      V5DialogAction(
                        label: 'Fermer',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: V5DialogActionStyle.primary,
                      ),
                    ],
                  ),
                ),
                child: const Text('Dialogue'),
              ),
              TextButton(
                key: const Key('open-confirmation'),
                onPressed: () async {
                  confirmation = await showV5Confirmation(
                    context: context,
                    title: 'Confirmer',
                    message: 'Voulez-vous continuer ?',
                    destructive: true,
                  );
                },
                child: const Text('Confirmation'),
              ),
            ],
          ),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.tap(find.byKey(const Key('open-dialog')));
    await tester.pumpAndSettle();
    expect(find.byType(V5Dialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SafeArea), findsWidgets);
    expect(
      Theme.of(tester.element(find.byType(V5Dialog))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-confirmation')));
    await tester.pumpAndSettle();
    expect(find.byType(V5Confirmation), findsOneWidget);
    await tester.tap(find.text('Confirmer').last);
    await tester.pumpAndSettle();
    expect(confirmation, isTrue);
  });

  testWidgets('V5Toast uses an overlay, safe area and controller dismissal', (
    tester,
  ) async {
    V5ToastController? toast;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              toast = V5Toast.show(
                context,
                message: 'Profil enregistré.',
                tone: V5ToastTone.success,
                duration: const Duration(seconds: 10),
              );
            },
            child: const Text('Afficher'),
          ),
        ),
        themeMode: ThemeMode.dark,
      ),
    );

    await tester.tap(find.text('Afficher'));
    await tester.pumpAndSettle();
    expect(find.byType(V5Toast), findsOneWidget);
    expect(find.text('Profil enregistré.'), findsOneWidget);
    expect(find.byType(SafeArea), findsWidgets);
    expect(
      Theme.of(tester.element(find.byType(V5Toast))).brightness,
      Brightness.dark,
    );

    toast!.dismiss();
    await tester.pumpAndSettle();
    expect(find.byType(V5Toast), findsNothing);
  });
}
