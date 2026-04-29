#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL_VALUE="${API_BASE_URL:-/api}"

FLUTTER_DIR="${HOME}/flutter"

if [[ ! -d "${FLUTTER_DIR}" ]]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter pub get
echo "Building Flutter web with API_BASE_URL=${API_BASE_URL_VALUE}"
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL_VALUE}"
