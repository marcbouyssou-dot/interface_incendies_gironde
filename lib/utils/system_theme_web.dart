// ignore: deprecated_member_use
import 'dart:html' as html;

void activateLightApplicationChrome() {
  dismissNativeStartupSplash();
  html.document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute('content', '#F6F7F8');
  html.document
      .querySelector('meta[name="apple-mobile-web-app-status-bar-style"]')
      ?.setAttribute('content', 'default');
  (html.document.querySelector('html') as html.HtmlElement?)
          ?.style
          .backgroundColor =
      '#F6F7F8';
  html.document.body?.style.backgroundColor = '#F6F7F8';
  _markStartupMilestone(
    'mobsante-application-ready',
    measureName: 'mobsante-initialization',
    startMark: 'mobsante-flutter-first-frame',
  );
}

void dismissNativeStartupSplash() {
  _markStartupMilestone(
    'mobsante-flutter-first-frame',
    measureName: 'mobsante-bootstrap',
    startMark: 'mobsante-launch-shell-visible',
  );
  final splash = html.document.getElementById('startup-splash');
  splash?.remove();
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
