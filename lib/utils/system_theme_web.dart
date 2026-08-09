// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _applicationBackground = '#F6F7F8';
const _darkApplicationBackground = '#0D1622';

void activateLightApplicationChrome() {
  dismissNativeStartupSplash();
  _setApplicationChrome(
    background: _applicationBackground,
    appleStatusBarStyle: 'default',
  );
  _markStartupMilestone(
    'mobsante-application-ready',
    measureName: 'mobsante-initialization',
    startMark: 'mobsante-flutter-first-frame',
  );
}

void activateDarkApplicationChrome() {
  dismissNativeStartupSplash();
  _setApplicationChrome(
    background: _darkApplicationBackground,
    appleStatusBarStyle: 'black-translucent',
  );
  _markStartupMilestone(
    'mobsante-application-ready',
    measureName: 'mobsante-initialization',
    startMark: 'mobsante-flutter-first-frame',
  );
}

void activateSplashApplicationChrome() {}

void dismissNativeStartupSplash() {
  _markStartupMilestone(
    'mobsante-flutter-first-frame',
    measureName: 'mobsante-bootstrap',
    startMark: 'mobsante-launch-shell-visible',
  );
  final splash = html.document.getElementById('startup-splash');
  splash?.remove();
}

void _setApplicationChrome({
  required String background,
  required String appleStatusBarStyle,
}) {
  html.document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', background);
  html.document
      .querySelector('meta[name="apple-mobile-web-app-status-bar-style"]')
      ?.setAttribute('content', appleStatusBarStyle);
  html.document.documentElement?.style.backgroundColor = background;
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
