# cottage

The Flutter mobile app for the roommate expense tracker.

## Supabase credentials

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at **build time** via
`--dart-define` (see `lib/core/services/supabase_service.dart`) - there is no
runtime `.env` file. Without these, the app builds and installs fine but
every screen that talks to Supabase (starting with login) fails.

1. Copy `env.json.example` to `env.json` and fill in your project's URL/anon key.
   `env.json` is gitignored - never commit real credentials.
2. Debug runs from Android Studio / VS Code already pass
   `--dart-define-from-file=env.json` (see `.vscode/launch.json`), so `flutter run`
   from the IDE works once `env.json` exists.
3. **Release builds must pass the flag explicitly** - plain
   `flutter build apk --release` (or Android Studio's Build > Build APK(s) menu)
   does NOT include it, and will silently ship a broken build that can't log in.
   Use the provided script instead:
   ```sh
   ./build_release.sh      # macOS/Linux/WSL
   ./build_release.ps1     # Windows PowerShell
   ```
   or run the equivalent manually:
   ```sh
   flutter build apk --release --dart-define-from-file=env.json
   ```

## Push notifications (Firebase Cloud Messaging)

Native push to the device's system notification tray needs a Firebase
project, separate from Supabase:

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com).
2. Add an Android app with package name `com.cottage.cottage`.
3. Download the generated `google-services.json` and place it at
   `android/app/google-services.json`. It's gitignored (environment-specific,
   like `env.json`) - the app still builds without it, just with push disabled
   (`PushNotificationService` fails soft, see its doc comment).
4. For the backend to actually *send* pushes: Firebase Console > Project
   Settings > Service Accounts > Generate new private key, then set the
   full JSON contents as `FIREBASE_SERVICE_ACCOUNT` in the web app's
   `.env.local` (see `src/lib/data/fcm.ts`).

## Getting Started

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
