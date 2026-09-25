#!/usr/bin/env bash
# Guards against a specific regression: dart2js can tree-shake the
# maplibre_gl_web plugin registration out of a `flutter build web` release
# bundle, silently falling back to the native-only MethodChannel
# implementation (which then errors with "TargetPlatform.<x> is not yet
# supported by the maps plugin" on every non-mobile browser).
#
# `flutter test` cannot catch this: it runs on the Dart VM, never through
# dart2js, so tree-shaking of the compiled web bundle never comes into play.
# This script builds the real release artifact and inspects it directly.
#
# Usage: scripts/check_web_release_map_plugin.sh
# Exits non-zero (with an explanation) if the marker is missing.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building release web bundle to verify maplibre_gl_web survives tree-shaking..."
flutter build web --pwa-strategy=none >/dev/null

BUNDLE="build/web/main.dart.js"
if [[ ! -f "$BUNDLE" ]]; then
  echo "ERROR: $BUNDLE not found after build." >&2
  exit 1
fi

# "maplibregl" is the literal JS global name maplibre_gl_web's @JS()
# interop binds to. It is a string, not a Dart identifier, so it survives
# dart2js minification even when class/method names are renamed away —
# unlike "MapLibreMapPlugin" or "registerPlugins", which are not reliable
# markers in a minified release bundle.
if grep -q "maplibregl" "$BUNDLE"; then
  echo "OK: maplibre_gl_web is present in the release bundle."
  exit 0
fi

cat >&2 <<'EOF'
REGRESSION DETECTED: the release web bundle does not reference "maplibregl".
This means maplibre_gl_web's registration was tree-shaken out of this build,
and the operational map will fall back to the native-only implementation,
showing "TargetPlatform.<x> is not yet supported by the maps plugin"
instead of an actual map on any non-mobile browser.

Known trigger: this reproduced with maplibre_gl 0.26.2 specifically in a
release build compiled with USE_FIREBASE unset/false (i.e. a build against
MockCoordinationRepository, not the real Firebase-backed app). It did not
reproduce with maplibre_gl 0.27.1, nor with USE_FIREBASE=true (the flag
netlify_build.sh always sets for real deployments).

If this fires: do not add a fallback/hack. Re-check whether the
maplibre_gl / maplibre_gl_web / maplibre_gl_platform_interface pub.dev
versions in pubspec.lock have regressed, and whether the failure also
reproduces with the exact dart-define flags netlify_build.sh uses for a
real deploy before concluding production is at risk.
EOF
exit 1
