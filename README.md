# Potfolio

AI-assisted, goal-based stock pots on Base. One Flutter codebase for Android, iOS and web, a Cloudflare Worker API (`worker/`) and an onchain `PotRegistry` (`contracts/`).

## Run locally

```bash
flutter pub get
flutter run --dart-define=WORKER_URL=https://potfolio-api.purpose-money-api.workers.dev
```

## Website (Firebase Hosting)

Live at **https://usepotfolio.web.app**:

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

- `usepotfolio.web.app` and `usepotfolio.firebaseapp.com` are already authorized for Firebase Auth. Add any custom domain under Authentication → Settings → Authorized domains.
- If the Worker's `ALLOWED_ORIGINS` is not `*`, add `https://usepotfolio.web.app`.
- The APK uses Flutter's default debug signing. Add a release keystore before sharing widely, and keep it out of git.
- Only add official App Store / Google Play badges once the apps are live in those stores.
