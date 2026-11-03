<div align="center">

<img src="assets/images/logo.png" alt="Cottage logo" width="96" />

# 🏡 Cottage

**Shared-house living, sorted: meals, bazaar duty, utilities and notices in one calm dashboard.**
The native Flutter client for Cottage, on the same Supabase backend as the web app.

![Flutter](https://img.shields.io/badge/Flutter-3.12+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Backend](https://img.shields.io/badge/Backend-Supabase-1B7A52?style=for-the-badge&logo=supabase&logoColor=white)
![Push](https://img.shields.io/badge/Push-Firebase%20FCM-0F1B33?style=for-the-badge&logo=firebase&logoColor=FFCA28)
![Dart](https://img.shields.io/badge/Dart-%5E3.12.2-14A6B5?style=for-the-badge&logo=dart&logoColor=white)

![Last commit](https://img.shields.io/github/last-commit/moinul-rehan/Cottage-App-Flutter?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.0.0-555?style=flat-square)
![Feature modules](https://img.shields.io/badge/Feature%20modules-13-555?style=flat-square)
![Targets](https://img.shields.io/badge/Flutter%20targets-6-555?style=flat-square)
![License](https://img.shields.io/badge/License-Proprietary-lightgrey?style=flat-square)

[About](#-about) · [Features](#-features) · [Tech stack](#-tech-stack) · [Platforms](#-supported-platforms) · [Getting started](#-getting-started) · [Structure](#-project-structure) · [Design](#-design-language) · [License](#-license)

</div>

---

## 🏠 About

Splitting rent is easy. Splitting *everything else* is not: who cooked, who shopped, who paid the electricity bill, who owes what this month. **Cottage** turns that spreadsheet chaos into one shared source of truth for every member of the house.

It's the native mobile counterpart to Cottage's Next.js web app, built on the same [Supabase](https://supabase.com) project, so a change on one surface shows up instantly on the other. Log a meal on the web at lunch, see the updated balance on your phone by dinner.

```mermaid
flowchart LR
    WEB["🌐 Next.js web app"] --> SB[("🗄️ Supabase<br/>Auth · Postgres · Realtime")]
    APP["📱 Cottage Flutter app"] --> SB
    SB --> FCM["🔔 Firebase Cloud Messaging"]
    FCM --> APP

    click APP "./lib" "Open lib"

    classDef hub fill:#1B7A52,stroke:#1B7A52,color:#fff
    classDef main fill:#0F1B33,stroke:#0F1B33,color:#fff
    classDef leaf fill:#F4F5F8,stroke:#14A6B5,color:#1B1B1B
    class SB hub
    class APP main
    class WEB,FCM leaf
```

---

## ✨ Features

<table>
<tr><td width="46">🏠</td><td><b>Dashboard</b><br/>The daily snapshot: live meal & utility balances, the pinned notice, this month's bazaar duty roster, recent utility expenses, and a per-member meal summary. Pull to refresh at any time.</td></tr>
<tr><td>🍽️</td><td><b>Meal Tracking</b><br/>A tabbed monthly ledger: <i>Meal Details</i> for daily counts and the running per-meal rate, <i>Bazar</i> for grocery purchases, <i>Deposit</i> for meal-fund contributions. Every entry is editable and totals recalculate automatically.</td></tr>
<tr><td>🛒</td><td><b>Bazaar Duty Roster</b><br/>A shared rota showing each member's grocery-shopping window, with whoever's on duty highlighted at a glance and full details a tap away.</td></tr>
<tr><td>💡</td><td><b>Utilities</b><br/>Log shared bills by category (electricity, gas, water, internet, rent, maintenance, and more), record deposits, and see a per-member <i>Dues</i> breakdown with clear paid/due status.</td></tr>
<tr><td>📢</td><td><b>Notice Board</b><br/>A cottage-wide announcement feed across <i>Feed</i>, <i>Scheduled</i>, and <i>History</i> tabs. Notices carry a type and priority, and admins can pin, archive, or restrict visibility.</td></tr>
<tr><td>🔔</td><td><b>Notifications</b><br/>An in-app bell and activity list, sorted by source, backed by Firebase Cloud Messaging so alerts land even when the app is closed.</td></tr>
<tr><td>👥</td><td><b>Members & Menu</b><br/>Your profile card, the active billing month, a member directory, and quick links to History, Contacts, and Settings.</td></tr>
<tr><td>🔐</td><td><b>Authentication</b><br/>Email/password and native Google sign-in (in-app account picker, no browser hop), plus password recovery, all backed by Supabase Auth.</td></tr>
</table>

---

## 🧱 Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`) |
| Backend, Auth & Database | [Supabase](https://supabase.com) (`supabase_flutter`) |
| Push Notifications | Firebase Cloud Messaging + `flutter_local_notifications` |
| Sign-In | Native Google Sign-In (`google_sign_in`) via Supabase ID-token exchange |
| Typography | Google Fonts (Poppins, Outfit) + bundled Plus Jakarta Sans |
| Icons | `lucide_icons_flutter`, matching the web app's icon set |
| Sharing | `share_plus` + `path_provider` for generated invoice images |

<details>
<summary><b>🏗 Architecture</b></summary>

<br>

- **Feature-first** layout: `lib/features/<name>/{data,presentation}`
- **State:** plain `StatefulWidget` + `Future`/`FutureBuilder` (no external state-management package)
- **Theming:** a global `ValueNotifier<ThemeMode>` for light/dark
- **Navigation:** a key-based `NavigationService` for context-free navigation
- **Design system:** brand colors and design tokens mirror the web app's design system so both clients feel like one product

```mermaid
flowchart LR
    MAIN["main.dart"] --> INIT["SupabaseService · PushNotificationService · OnboardingService"]
    INIT --> SPLASH["Splash"]
    SPLASH --> GATE{"Signed in?"}
    GATE -- "no" --> AUTH["Onboarding / Login"]
    GATE -- "yes" --> SHELL["Bottom nav shell"]
    SHELL --> FEAT["Feature screens"]

    click MAIN "./lib/main.dart" "Open main.dart"
    click INIT "./lib/helpers" "Open helpers"
    click SHELL "./lib/common_widgets/bottom_nav_shell.dart" "Open bottom_nav_shell.dart"
    click FEAT "./lib/features" "Open features"

    classDef root fill:#1B7A52,stroke:#1B7A52,color:#fff
    classDef step fill:#F4F5F8,stroke:#14A6B5,color:#1B1B1B
    classDef gate fill:#0F1B33,stroke:#0F1B33,color:#fff
    class MAIN root
    class INIT,SPLASH,AUTH,SHELL,FEAT step
    class GATE gate
```

</details>

---

## 📱 Supported Platforms

Android · iOS · macOS · Windows · Linux · Web: all six Flutter targets are scaffolded in this repo.

| [`android`](./android) | [`ios`](./ios) | [`macos`](./macos) | [`windows`](./windows) | [`linux`](./linux) | [`web`](./web) |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 🤖 | 🍎 | 💻 | 🪟 | 🐧 | 🌐 |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.12.2`)
- A Supabase project (URL + anon key)
- *(Optional, for push notifications)* A Firebase project

### 1. Clone & install dependencies

```sh
git clone https://github.com/moinul-rehan/Cottage-App-Flutter.git
cd Cottage-App-Flutter
flutter pub get
```

### 2. Configure Supabase credentials

Cottage reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at **build time** via `--dart-define` (see [`lib/helpers/supabase_service.dart`](lib/helpers/supabase_service.dart)). There's no runtime `.env` file. Without them, the app builds fine, but every screen that talks to Supabase (starting with login) will fail.

```sh
cp env.json.example env.json
# then fill in your own project's URL and anon key
```

Run the app with the credentials injected:

```sh
flutter run --dart-define-from-file=env.json
```

> [!WARNING]
> **Release builds must pass the flag explicitly.** A plain `flutter build apk --release` (or Android Studio's *Build > Build APK(s)*) silently ships a broken build that can't log in. Use the provided script instead:
> ```sh
> ./build_release.sh      # macOS / Linux / WSL
> ./build_release.ps1     # Windows PowerShell
> ```

<details>
<summary><b>3. (Optional) Enable push notifications</b></summary>

<br>

Native push needs a separate Firebase project:

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com).
2. Add an Android app with package name `com.cottage.cottage`.
3. Download `google-services.json` and place it at `android/app/google-services.json` (gitignored; the app still builds without it, just with push disabled, see [`PushNotificationService`](lib/helpers/push_notification_service.dart)).
4. For the backend to *send* pushes, generate a service-account key (Firebase Console → Project Settings → Service Accounts) and configure it on the web app's side.

</details>

<details>
<summary><b>4. (Optional) Enable native Google Sign-In</b></summary>

<br>

1. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials), create an **OAuth 2.0 Client ID** of type *Web application* (redirect URI: your Supabase project's `/auth/v1/callback`), and paste its Client ID + Secret into Supabase → Authentication → Providers → Google.
2. Create a second **Android**-type Client ID with your app's package name and signing SHA-1 fingerprint. This is what lets the native account picker launch for your build.

</details>

---

## 📂 Project Structure

Click a box to open that folder.

```mermaid
flowchart LR
    LIB(("📦 lib"))

    LIB --> CW["common_widgets"]
    LIB --> CO["constants"]
    LIB --> FE["features"]
    LIB --> HE["helpers"]
    LIB --> MO["models"]
    LIB --> MAIN["main.dart"]

    FE --> F1["auth · onboarding · splash"]
    FE --> F2["dashboard · meal · bazaar_duty · utilities"]
    FE --> F3["notices · notifications · requests"]
    FE --> F4["menu · months · contacts"]

    click CW "./lib/common_widgets" "Open common_widgets"
    click CO "./lib/constants" "Open constants"
    click FE "./lib/features" "Open features"
    click HE "./lib/helpers" "Open helpers"
    click MO "./lib/models" "Open models"
    click MAIN "./lib/main.dart" "Open main.dart"

    classDef root fill:#1B7A52,stroke:#1B7A52,color:#fff
    classDef group fill:#0F1B33,stroke:#0F1B33,color:#fff
    classDef leaf fill:#F4F5F8,stroke:#14A6B5,color:#1B1B1B
    class LIB root
    class CW,CO,FE,HE,MO,MAIN group
    class F1,F2,F3,F4 leaf
```

<details open>
<summary><b>🗂 Folder tree</b></summary>

<br>

```
lib/
├── common_widgets/     # Shared UI: app scaffold, bottom nav shell, bottom sheets, empty states
├── constants/          # App name, theme (CottageColors, CottageSurface)
├── features/
│   ├── auth/            # Login, signup, forgot password, native Google sign-in
│   ├── dashboard/       # Home screen: summaries, roster, notices, expenses
│   ├── meal/            # Meal details, bazar purchases, deposits
│   ├── bazaar_duty/     # Grocery-duty roster
│   ├── utilities/       # Utility expenses, deposits, dues
│   ├── menu/            # Settings hub + member directory
│   ├── notices/         # Notice board (feed / scheduled / history)
│   └── notifications/   # In-app notification center
├── helpers/             # Supabase client, push notifications, navigation, formatting
├── models/              # Shared data models (e.g. Profile)
└── main.dart            # App entry point, theming, auth gate
```

</details>

<details>
<summary><b>➕ More feature modules in <code>lib/features</code></b></summary>

<br>

These folders are in the code but were not in the tree above.

| Folder | Contents |
|---|---|
| [`contacts`](./lib/features/contacts) | `contacts_screen.dart`, contact model and service |
| [`months`](./lib/features/months) | `months_screen.dart`, month models and service |
| [`requests`](./lib/features/requests) | `request_screen.dart`, request models and service |
| [`onboarding`](./lib/features/onboarding) | `onboarding_screen.dart` |
| [`splash`](./lib/features/splash) | `splash_screen.dart` |

</details>

<details>
<summary><b>🗄️ Supabase folder</b></summary>

<br>

| Path | What is inside |
|---|---|
| [`supabase/migrations`](./supabase/migrations) | SQL migrations shared with the web app's Supabase project |
| [`supabase/templates`](./supabase/templates) | Auth and cottage email templates (signup, invite, reset password, magic link, approve/reject cottage and more) |
| [`supabase/MIGRATIONS_README.md`](./supabase/MIGRATIONS_README.md) | How to keep migrations in sync with the `cottage-expense-tracker` web repo |

</details>

---

## 🎨 Design Language

Cottage's UI mirrors the web app's design tokens for a consistent cross-platform feel: a warm brand orange (`#E66140`) drives buttons and active states, with dedicated light/dark surface palettes and status-tone colors (blue, green, orange, red) for badges and balances throughout the app.

| Token | Value |
|---|---|
| Brand primary | ![#E66140](https://img.shields.io/badge/%23E66140-E66140?style=flat-square) |
| Themes | Light and dark surface palettes |
| Status tones | Blue · green · orange · red |
| Bundled fonts | Plus Jakarta Sans (400 to 800), Lobster |

---

## 📄 License

> [!CAUTION]
> All rights reserved. See [`LICENSE`](LICENSE). This repository is public for portfolio and reference purposes only; no permission is granted to copy, modify, or redistribute the code.

<div align="center">

---

<sub>Built with Flutter · Powered by Supabase</sub>

Made in Dhaka 🇧🇩 by **Moinul Islam Rehan** · Tulip Tech

</div>
