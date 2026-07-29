#!/usr/bin/env bash

set -euo pipefail

readonly FLUTTER_RELEASE="${FLUTTER_VERSION:-3.41.8}"
readonly SDK_CACHE_ROOT="${NETLIFY_BUILD_BASE:-${HOME}/.cache}"
readonly FLUTTER_SDK_DIR="${SDK_CACHE_ROOT}/flutter-sdk-${FLUTTER_RELEASE}"

if [[ ! -x "${FLUTTER_SDK_DIR}/bin/flutter" ]]; then
  git clone \
    --depth 1 \
    --branch "${FLUTTER_RELEASE}" \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_SDK_DIR}"
fi

export PATH="${FLUTTER_SDK_DIR}/bin:${PATH}"

flutter config --no-analytics --enable-web
flutter pub get

build_arguments=(--release)

if [[ "${USE_FIREBASE:-false}" == "true" ]]; then
  required_firebase_variables=(
    FIREBASE_API_KEY
    FIREBASE_APP_ID
    FIREBASE_MESSAGING_SENDER_ID
    FIREBASE_PROJECT_ID
    FIREBASE_AUTH_DOMAIN
    FIREBASE_STORAGE_BUCKET
  )

  for variable_name in "${required_firebase_variables[@]}"; do
    if [[ -z "${!variable_name:-}" ]]; then
      echo "Missing required Netlify environment variable: ${variable_name}" >&2
      exit 1
    fi
  done

  build_arguments+=(
    "--dart-define=USE_FIREBASE=true"
    "--dart-define=ENABLE_LOCATION_SEED=${ENABLE_LOCATION_SEED:-false}"
    "--dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY}"
    "--dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID}"
    "--dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID}"
    "--dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}"
    "--dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN}"
    "--dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET}"
  )
fi

flutter build web "${build_arguments[@]}"
