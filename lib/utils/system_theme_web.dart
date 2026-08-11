// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _applicationBackground = '#F6F7F8';
const _darkApplicationBackground = '#0D1622';
const _splashBackground = '#10233E';
const _splashClass = 'mobsante-splash-active';

void activateLightApplicationChrome() {
  dismissNativeStartupSplash();
  _setApplicationChrome(
    background: _applicationBackground,
    splashActive: false,
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
    splashActive: false,
    appleStatusBarStyle: 'black-translucent',
  );
  _markStartupMilestone(
    'mobsante-application-ready',
    measureName: 'mobsante-initialization',
    startMark: 'mobsante-flutter-first-frame',
  );
}

void activateSplashApplicationChrome() {
  _setApplicationChrome(
    background: _splashBackground,
    splashActive: true,
    appleStatusBarStyle: 'black-translucent',
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

void _setApplicationChrome({
  required String background,
  required bool splashActive,
  required String appleStatusBarStyle,
  bool updateThemeColor = true,
}) {
  if (updateThemeColor) {
    html.document
        .querySelector('meta[name="theme-color"]')
        ?.setAttribute('content', background);
  }
  html.document
      .querySelector('meta[name="apple-mobile-web-app-status-bar-style"]')
      ?.setAttribute('content', appleStatusBarStyle);
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
