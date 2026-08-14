# Crypto Analysis & Auto-Trading Assistant (Tabdeal) — Personal Use Edition

## ⚠️ Disclaimer (read first)
This is **not financial advice**. Signals are generated from historical data using conventional technical-analysis methods and **profitability is never guaranteed**. Trading real capital, especially with leverage, always carries risk of partial or total loss. All trading decisions, including enabling auto-trading, are entirely the user's responsibility.

## What this is
A Flutter Android app that:
- Analyzes crypto pairs on the **Tabdeal** exchange from a user-editable watchlist.
- Combines several independent technical methods (EMA trend, RSI, MACD, SMC/ICT-style market structure with BOS & CHoCH, supply/demand zones, candlestick patterns, Fibonacci) into a rule-based **ensemble signal engine** that only fires when multiple independent conditions align.
- When auto-trading is enabled, places real market orders + a stop-loss on Tabdeal, sized according to risk settings **the user must re-enter every session**.
- Stores API keys encrypted on-device only (`flutter_secure_storage`) — never transmitted to any third-party server.

## ⚠️ Critical technical limitations
1. **No server = no true 24/7 execution.** This app only runs inside the phone. Scanning, analysis, and order execution only happen while the app is open and running. Even with battery optimization disabled, Android may still suspend the app under memory pressure, reboots, or updates. The stop-loss is placed as a real `STOP_LOSS_LIMIT` order directly on the exchange so it stays active even if the app is closed — but TP1/TP2/TP3 partial-exit management happens client-side and requires the app to be running.
2. **No officially documented Tabdeal klines endpoint was found** in the public docs. The client attempts `/klines` and falls back to bucketing `/trades` into candles (lower fidelity) if that fails. Verify the correct path against the official Postman collection (`github.com/Tabdeal-Exchange/tabdeal-api-postman`) before relying on it, and fix `lib/core/api/tabdeal_api_service.dart` accordingly.
3. **No machine learning.** ML components (trend classification, regime detection, etc.) from the original spec were dropped — production-quality on-device training/inference without a backend isn't realistic. The current engine is fully rule-based and auditable instead.
4. **Crypto only, Tabdeal only** — forex/stocks/futures/commodities/indices were removed per your decision.
5. **This code is delivered uncompiled.** I (Claude) cannot produce a real APK in this environment. Follow the build steps below.

## Building the APK (one-time, on a computer)

### Fixed issues from earlier revisions
1. **`unable to find directory entry in pubspec.yaml: assets/`** — caused by an empty `assets/` folder (containing only a `.gitkeep`) not surviving a phone-browser upload to GitHub. Since no code currently references it, the `assets:` entry was removed from `pubspec.yaml` entirely (left as a comment for future use).
2. **`flutter_local_notifications requires core library desugaring`** — since `android/` isn't committed and is generated fresh by CI on every build, `scripts/patch_android_desugaring.py` now runs right after `flutter create` to inject `coreLibraryDesugaringEnabled true` and the `desugar_jdk_libs:2.1.4` dependency into the generated `build.gradle` (or `build.gradle.kts`). Wired into both `.github/workflows/build-apk.yml` and `codemagic.yaml`.

1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) and Android Studio.
2. Open the `crypto_trader` folder.
3. Native platform folders (`android/`, `ios/`) are not included (they require running the actual Flutter SDK to generate). Run:
   ```bash
   flutter create .
   ```
   This scaffolds `android/`, `ios/`, `web/` etc. without touching your `lib/` or `pubspec.yaml` (back them up first if prompted about overwrites).
4. Install packages:
   ```bash
   flutter pub get
   ```
5. Build the installable release:
   ```bash
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`. Transfer to your phone and install (requires enabling "install from unknown sources").

No computer available? Use a cloud CI service (Codemagic, GitHub Actions, Ionic Appflow) manageable from a phone browser, after pushing this code to a Git repository.

## Project structure
See `README.fa.md` for the annotated tree (same structure, Persian labels).

## Setting up your Tabdeal API key
1. Create an API key on Tabdeal with **Trade** permission only.
2. **Never enable Withdraw permission** for this key.
3. Enter the key/secret in the app's Settings screen — stored encrypted, on-device only.

## Suggested next steps (out of scope for this delivery)
- Wire up a live candlestick chart (`fl_chart` is already a dependency).
- Implement the background TP1/TP2/TP3 monitor using `flutter_background_service` (dependency included, service not yet implemented).
- Test extensively with a very small amount of real capital before scaling up.
