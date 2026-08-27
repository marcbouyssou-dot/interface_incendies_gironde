import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/web_push_diagnostics_stub.dart'
    if (dart.library.html) '../services/web_push_diagnostics_web.dart'
    as diagnostics;

class DiagnosticPushRegistrationScreen extends StatefulWidget {
  const DiagnosticPushRegistrationScreen({super.key, this.diagnosticsReader});

  final Future<Map<String, dynamic>> Function()? diagnosticsReader;

  @override
  State<DiagnosticPushRegistrationScreen> createState() =>
      _DiagnosticPushRegistrationScreenState();
}

class _DiagnosticPushRegistrationScreenState
    extends State<DiagnosticPushRegistrationScreen> {
  bool _initialReadStarted = false;
  bool _loading = true;
  Map<String, dynamic>? _diagnostics;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialReadStarted) return;
    _initialReadStarted = true;
    unawaited(_readDiagnostics());
  }

  Future<void> _readDiagnostics() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final reader = widget.diagnosticsReader ?? _readPlatformDiagnostics;
      final result = Map<String, dynamic>.of(await reader());
      final installationValue = result['installationId'];
      final installationId =
          installationValue is String &&
              installationValue.isNotEmpty &&
              installationValue != 'ABSENT'
          ? installationValue
          : null;
      if (installationId == null) result['installationId'] = 'ABSENT';

      if (!mounted) return;
      setState(() {
        _diagnostics = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final json = _diagnostics == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(_diagnostics);

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic Push')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Écran de diagnostic temporaire — lecture seule — à retirer '
                'après la recette.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null)
                      Text('Lecture impossible : $_error')
                    else if (json != null)
                      SelectableText(
                        json,
                        key: const Key('push-diagnostics-json'),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _loading ? null : _readDiagnostics,
                        child: const Text('Relire l’état'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>> _readPlatformDiagnostics() async {
  final installationId = diagnostics.peekInstallationId();
  final controller = diagnostics.serviceWorkerController();
  return {
    'origin': diagnostics.currentOrigin(),
    'installationId': installationId ?? 'ABSENT',
    'notificationPermission': diagnostics.notificationPermission(),
    'standalone': diagnostics.isStandaloneDisplayMode(),
    'navigatorStandalone': diagnostics.navigatorStandaloneLegacy(),
    'serviceWorkerController': controller == null
        ? null
        : {
            'present': controller['present'] == 'true',
            'scriptURL': controller['scriptURL'],
          },
    'serviceWorkerRegistrations': await diagnostics
        .serviceWorkerRegistrations(),
  };
}
