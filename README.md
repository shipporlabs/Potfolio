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
| `/download/potfolio.apk` | Android APK. The button shows "Coming soon" until it exists |

### Deploy from your computer

```bash
npm install -g firebase-tools     # once
firebase login                    # once
bash scripts/build_site.sh        # builds dist/
firebase deploy --only hosting
```

### Android download

Put your APK at `site/download/potfolio.apk`, then build and deploy as above (or commit it and push; the GitHub Action deploys it).
Build one with:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 \
  --dart-define=WORKER_URL=https://potfolio-api.purpose-money-api.workers.dev
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk site/download/potfolio.apk
```

Firebase's free Spark plan allows about **360 MB of downloads per day**, so roughly 15–20 APK downloads a day. Move the APK to other storage if it gets more traffic than that.

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
