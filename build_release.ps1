# Builds a release APK with the Supabase credentials baked in.
#
# Why this script exists: Supabase URL/anon key are read at build time via
# --dart-define (see lib/core/services/supabase_service.dart), not from a
# runtime .env file. `flutter build apk --release` on its own (or Android
# Studio's "Build > Build APK(s)" menu) does NOT pass that flag, so a release
# APK built that way installs and launches fine but silently ships with an
# empty SUPABASE_URL/SUPABASE_ANON_KEY - the app never reaches Supabase and
# every login attempt fails. Debug runs from Android Studio/VS Code work
# because their run configs already pass --dart-define-from-file=env.json.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path env.json)) {
    Write-Error "env.json not found. Copy env.json.example to env.json and fill in your Supabase URL/anon key."
    exit 1
}

flutter build apk --release --dart-define-from-file=env.json @args
