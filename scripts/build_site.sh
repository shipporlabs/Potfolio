#!/usr/bin/env bash
# Builds the website into dist/:
#   /                        landing page (site/)
#   /app/                    Flutter web app
#   /download/potfolio.apk   Android APK (your file in site/download/, or built here)
# Usage:  bash scripts/build_site.sh            # web only (+ your committed APK)
#         BUILD_APK=1 bash scripts/build_site.sh # also build the APK if none is committed
set -euo pipefail
cd "$(dirname "$0")/.."

WORKER_URL="${WORKER_URL:-https://potfolio-api.purpose-money-api.workers.dev}"

flutter pub get
flutter build web --release --base-href /app/ --dart-define=WORKER_URL="$WORKER_URL"

rm -rf dist && mkdir -p dist/app dist/download
cp -r site/. dist/
cp -r build/web/. dist/app/

if [ ! -f site/download/potfolio.apk ] && [ "${BUILD_APK:-0}" = "1" ]; then
  flutter build apk --release --split-per-abi --target-platform android-arm64 \
    --dart-define=WORKER_URL="$WORKER_URL" || echo "APK build failed, continuing without it"
  APK=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  [ -f "$APK" ] && cp "$APK" dist/download/potfolio.apk
fi

[ -f dist/download/potfolio.apk ] && echo "APK included: $(du -h dist/download/potfolio.apk | cut -f1)" \
  || echo "No APK. The Android button will show 'Coming soon'."
echo "Site ready in dist/"
