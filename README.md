# Potfolio

AI-assisted, goal-based stock pots on Base. One Flutter codebase for Android, iOS and web, a Cloudflare Worker API (`worker/`) and an onchain `PotRegistry` (`contracts/`).

## Run locally

```bash
flutter pub get
flutter run --dart-define=WORKER_URL=https://potfolio-api.purpose-money-api.workers.dev
```

## Website (Firebase Hosting)

Live at **https://potfolio.xyz** (also https://usepotfolio.web.app):

| URL | What |
| --- | --- |
| `/` | Landing page (`site/index.html`, plain HTML) |
| `/app/` | The Flutter web app |
| Android button | Links to the APK on GitHub Releases (`APK_URL`) |

### Deploy from your computer

```bash
npm install -g firebase-tools     # once
firebase login                    # once
bash scripts/build_site.sh        # builds dist/
firebase deploy --only hosting
```

### Android download

Firebase's free Spark plan blocks `.apk` files, so the APK lives on a **GitHub Release in a public repo**, and the Android button links to
`https://github.com/shipporlabs/potfolio-releases/releases/latest/download/potfolio.apk` (override with `APK_URL=...`, or `APK_URL=` for "Coming soon").

One-time:

```bash
gh repo create shipporlabs/potfolio-releases --public -d "Potfolio app downloads"
```

Each release:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 \
  --dart-define=WORKER_URL=https://potfolio-api.purpose-money-api.workers.dev
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk potfolio.apk
gh release create v0.1.0 potfolio.apk -R shipporlabs/potfolio-releases -t "Potfolio 0.1.0" -n "Android build"
```

The `latest/download/potfolio.apk` link always points to the newest release, so new APKs don't need a website redeploy.

### Automatic deploys (GitHub Action)

`.github/workflows/deploy-web.yml` builds and deploys on every push to `main`. One-time setup:

```bash
firebase init hosting:github
```

Choose `shipporlabs/Potfolio`. It creates the `FIREBASE_SERVICE_ACCOUNT_USEPOTFOLIO` secret the workflow uses. Answer **No** to the build-script and merge-deploy questions. Afterwards, delete any `.github/workflows/firebase-hosting-*.yml` files it added, and if it changed `firebase.json`, undo that with `git checkout firebase.json`.

### Notes

- `usepotfolio.web.app` and `usepotfolio.firebaseapp.com` are already authorized for Firebase Auth. Add `potfolio.xyz` and `www.potfolio.xyz` under Authentication → Settings → Authorized domains.
- If the Worker's `ALLOWED_ORIGINS` is not `*`, add `https://potfolio.xyz` and `https://usepotfolio.web.app`.
- The APK uses Flutter's default debug signing. Add a release keystore before sharing widely, and keep it out of git.
- Only add official App Store / Google Play badges once the apps are live in those stores.

## Real buying and selling (Base mainnet)

Users buy and sell Coinbase tokenized stocks with USDC from their own device wallet. The Worker asks the 0x Swap API for a route (mostly Aerodrome) and returns an unsigned transaction; the app signs it locally. Potfolio pays network fees by topping up each wallet with a tiny amount of ETH.

1. Get a free API key at https://dashboard.0x.org, then `npx wrangler secret put ZEROX_API_KEY`.
2. Create a **new** wallet just for gas, send it ~$10–20 of ETH on Base, then `npx wrangler secret put GAS_WALLET_KEY` (its private key). Limits: 12 top-ups per user per 30 days, 300 per day overall.
3. Optional fee: `SWAP_FEE_BPS` (e.g. `25` = 0.25%) and `FEE_RECIPIENT` (your address), taken in USDC.
4. `cd worker && npm install && npx wrangler deploy`
5. Build the app for mainnet: `--dart-define=BASE_NETWORK=mainnet --dart-define=WORKER_URL=...`

Tokenized stocks are only for eligible people outside the US; the app asks users to confirm this before their first trade.
