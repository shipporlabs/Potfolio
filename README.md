# Potfolio

AI-assisted, goal-based stock pots on Base. One Flutter codebase for Android, iOS and web, a Cloudflare Worker API (`worker/`) and an onchain `PotRegistry` (`contracts/`).

## Run locally

```bash
flutter pub get
flutter run --dart-define=WORKER_URL=https://potfolio-api.purpose-money-api.workers.dev
```

## Website: landing page + web app + Android download

Everything is served from one Cloudflare Pages site:

| URL | What |
| --- | --- |
| `/` | Landing page (`site/index.html`, plain HTML, no build step) |
| `/app/` | The Flutter web app |
| `/download/potfolio.apk` | Android APK (arm64), shown as "Coming soon" until it exists |

A GitHub Action rebuilds and publishes all three on every push to `main` (or run it by hand from the **Actions** tab).

### One-time setup

1. **Turn on the workflow.** Move `deploy/deploy-web.yml` to `.github/workflows/deploy-web.yml` (on GitHub: open the file → ✏️ Edit → change the path at the top → Commit).
2. **Create the Pages project.** Cloudflare dashboard → Workers & Pages → Create → Pages → *Direct upload* → name it `potfolio` → upload any placeholder file. Your site will be at `https://potfolio.pages.dev`.
3. **Create an API token.** My Profile → API Tokens → Create token → *Custom token* with **Account · Cloudflare Pages · Edit**.
4. **Add GitHub secrets** (repo → Settings → Secrets and variables → Actions):
   - `CLOUDFLARE_API_TOKEN` – the token from step 3
   - `CLOUDFLARE_ACCOUNT_ID` – shown on the right of the Workers & Pages overview
   - Optional *variables*: `WORKER_URL` (defaults to the potfolio-api Worker) and `PAGES_PROJECT` (defaults to `potfolio`)
5. **Allow the domain in Firebase.** Firebase console → `usepotfolio` → Authentication → Settings → Authorized domains → add `potfolio.pages.dev` (and your custom domain, if any). Without this, sign-in on the web app fails.
6. **Allow the domain in the Worker.** If `ALLOWED_ORIGINS` in `worker/wrangler.toml` is not `*`, add `https://potfolio.pages.dev`, then `npx wrangler deploy` from `worker/`.
7. **Custom domain (optional).** Pages project → Custom domains → add e.g. `potfolio.xyz`, then repeat step 5 for it.

### Deploy by hand (no GitHub Action)

```bash
flutter build web --release --base-href /app/ \
  --dart-define=WORKER_URL=https://potfolio-api.purpose-money-api.workers.dev
rm -rf dist && mkdir -p dist/app && cp -r site/. dist/ && cp -r build/web/. dist/app/
# optional: flutter build apk --release --split-per-abi --target-platform android-arm64 ...
#   mkdir -p dist/download && cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk dist/download/potfolio.apk
npx wrangler pages deploy dist --project-name=potfolio
```

### Notes

- The APK is signed with the default debug key from the Flutter template. Before sharing widely, add a release keystore (see Flutter's *Build and release an Android app*) and keep it out of git.
- Cloudflare Pages has a 25 MiB per-file limit; the workflow only uses the arm64 split APK and skips it if it is larger.
- iPhone users can install the web app with Safari → Share → Add to Home Screen. Only add official App Store / Google Play badges once the apps are live in those stores.
