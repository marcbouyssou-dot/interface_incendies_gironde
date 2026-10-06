// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _applicationBackground = '#F6F7F8';
const _splashClass = 'mobsante-splash-active';
var _pendingApplicationBackground = _applicationBackground;
var _applicationRevealed = false;

void activateLightApplicationChrome() {
  _pendingApplicationBackground = _applicationBackground;
  if (_applicationRevealed) _applyPendingApplicationChrome();
}

void activateDarkApplicationChrome() {
  // iOS standalone PWAs can retain launch chrome across background/resume.
  // Keep the outer Web chrome light even when Flutter renders a dark surface.
  _pendingApplicationBackground = _applicationBackground;
  if (_applicationRevealed) _applyPendingApplicationChrome();
}

void activateSplashApplicationChrome() {
  _setApplicationChrome(
    background: _applicationBackground,
    splashActive: true,
    updateThemeColor: false,
  );
}

void dismissNativeStartupSplash() {
  final splash = html.document.getElementById('startup-splash');
  splash?.remove();
}

void markFlutterFirstFrame() {
  _markStartupMilestone(
    'mobsante-flutter-first-frame',
    measureName: 'mobsante-bootstrap',
    startMark: 'mobsante-launch-shell-visible',
  );
}

void markFlutterSplashComposed() {
  _markStartupMilestone(
    'mobsante-flutter-splash-composed',
    measureName: 'mobsante-splash-composition',
    startMark: 'mobsante-flutter-first-frame',
  );
}

void markStartupEvent(String name) {
  final performance = html.window.performance;
  if (performance.getEntriesByName(name, 'mark').isEmpty) {
    performance.mark(name);
  }
}

void revealApplication() {
  _applicationRevealed = true;
  _applyPendingApplicationChrome();
  dismissNativeStartupSplash();
  _markStartupMilestone(
    'mobsante-application-ready',
    measureName: 'mobsante-initialization',
    startMark: 'mobsante-flutter-first-frame',
  );
}

void _applyPendingApplicationChrome() {
  _setApplicationChrome(
    background: _pendingApplicationBackground,
    splashActive: false,
  );
}

void _setApplicationChrome({
  required String background,
  required bool splashActive,
  bool updateThemeColor = true,
}) {
  if (updateThemeColor) {
    html.document
        .querySelector('meta[name="theme-color"]')
        ?.setAttribute('content', background);
  }
  final documentElement = html.document.documentElement;
  documentElement?.classes.toggle(_splashClass, splashActive);
  documentElement?.style.backgroundColor = background;
  html.document.body?.style.backgroundColor = background;
}

void _markStartupMilestone(
  String markName, {
  required String measureName,
  required String startMark,
}) {
  final performance = html.window.performance;
  if (performance.getEntriesByName(markName, 'mark').isNotEmpty) return;
  performance.mark(markName);
  if (performance.getEntriesByName(startMark, 'mark').isNotEmpty) {
    performance.measure(measureName, startMark, markName);
  }
}
