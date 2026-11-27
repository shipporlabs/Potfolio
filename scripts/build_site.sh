#!/usr/bin/env bash
# Builds the website into dist/ for Firebase Hosting:
#   /       landing page (site/)
#   /app/   Flutter web app
#   /p/<id> public page for a shared pot
# Firebase's free plan does not allow .apk files, so the Android button links to
# APK_URL, by default the latest GitHub Release in shipporlabs/potfolio-releases.
# Set APK_URL= (empty) to show "Coming soon" instead.
#
# BASE_NETWORK=mainnet turns on real buying and selling (tokenized stocks only exist on Base mainnet).
# SITE_URL is used for share links (https://<site>/p/<id>); switch to https://potfolio.xyz once the domain is connected.
#
# Usage:  bash scripts/build_site.sh
set -euo pipefail
cd "$(dirname "$0")/.."

WORKER_URL="${WORKER_URL:-https://potfolio-api.purpose-money-api.workers.dev}"
BASE_NETWORK="${BASE_NETWORK:-mainnet}"
SITE_URL="${SITE_URL:-https://usepotfolio.web.app}"
APK_URL="${APK_URL-https://github.com/shipporlabs/potfolio-releases/releases/latest/download/potfolio.apk}"

flutter pub get
flutter build web --release --base-href /app/ --dart-define=WORKER_URL="$WORKER_URL" --dart-define=BASE_NETWORK="$BASE_NETWORK" --dart-define=SITE_URL="$SITE_URL"

rm -rf dist && mkdir -p dist/app
cp -r site/. dist/
rm -rf dist/download dist/_redirects dist/_headers
find dist -name '*.apk' -delete
cp -r build/web/. dist/app/

# Shared-pot page reads snapshots from the Worker.
sed "s|__WORKER_URL__|$WORKER_URL|g" dist/p/index.html > dist/p/index.tmp && mv dist/p/index.tmp dist/p/index.html

if [ -n "$APK_URL" ]; then
  sed "s|/download/potfolio.apk|$APK_URL|g" dist/index.html > dist/index.tmp && mv dist/index.tmp dist/index.html
  echo "Android button -> $APK_URL"
else
  echo "APK_URL is empty. The Android button will show 'Coming soon'."
fi
echo "Site ready in dist/ (WORKER_URL=$WORKER_URL, BASE_NETWORK=$BASE_NETWORK, SITE_URL=$SITE_URL)"
