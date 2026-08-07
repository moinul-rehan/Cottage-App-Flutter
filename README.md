<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Push-Firebase%20FCM-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/License-Private-lightgrey" alt="License" />
</p>

<h1 align="center">🏡 Cottage</h1>
<p align="center"><b>The mobile companion app for shared-house living — meals, bazaar duty, utilities, and notices, all in one place.</b></p>

---

## About

**Cottage** is a Flutter mobile app that helps roommates and shared-house ("cottage") members track and split their day-to-day living expenses without the spreadsheet headache. It's the native mobile counterpart to Cottage's Next.js web app, backed by the same [Supabase](https://supabase.com) project so both surfaces stay in sync.

Every member of a cottage sees the same live dashboard of who owes what, who's cooking, whose turn it is to shop, and what's been announced — with push notifications keeping everyone in the loop even when the app is closed.

## ✨ Features

### 🏠 Dashboard
A single home screen that surfaces what matters today: a live meal & utility balance summary, the current pinned notice, this month's bazaar duty roster, recent utility expenses, and a per-member meal summary — pull to refresh at any time.

### 🍽️ Meal Tracking
A tabbed monthly ledger for shared cooking:
- **Meal Details** — log daily lunch/dinner counts per member and see the running per-meal rate.
- **Bazar** — record grocery ("bazaar") purchases with amount and description.
- **Deposit** — track each member's meal-fund deposits.
- Every entry is editable/deletable from a bottom sheet, and totals (meals, bazaar spend, rate) update automatically.

### 🛒 Bazaar Duty Roster
A shared rota showing each member's grocery-shopping duty period, with the current person on duty highlighted at a glance and full details available on tap.

### 💡 Utilities
Split shared bills without the guesswork:
- Log expenses by category — electricity, gas, water, internet, house rent, maintenance, and more.
- Record member deposits toward utilities.
- A **Dues** view breaks down rent, expenses, amount paid, and remaining/advance balance per member, with clear paid/due status badges.

### 📢 Notice Board
A cottage-wide announcement feed with **Feed**, **Scheduled**, and **History** tabs. Notices carry a type (general, emergency, utility, meal, …) and priority, can be pinned or archived by admins, and support member-only or admin-only visibility.

### 🔔 Notifications
An in-app notification bell and full activity list — mark individual items or everything as read, with entries categorized by their source (meals, utilities, notices, and more). Backed by Firebase Cloud Messaging for native push alerts, even when the app isn't open.

### 👥 Members & Menu
A settings-style hub with your profile card, the active billing month, a member directory (avatar, name, email, active status), and sign-out — plus quick links to History, Contacts, and Settings.

### 🔐 Authentication
Email/password sign-in and sign-up, Google OAuth (via deep-link redirect back into the app), and password recovery — all backed by Supabase Auth.

## 🧱 Tech Stack

| Layer | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev) (Dart SDK `^3.12.2`) |
| Backend / Auth / Database | [Supabase](https://supabase.com) (`supabase_flutter`) |
| Push Notifications | Firebase Cloud Messaging + `flutter_local_notifications` |
| Typography | Google Fonts (Poppins) |
| Icons | `lucide_icons_flutter` — matches the web app's icon set |
| Sharing | `share_plus` + `path_provider` (share generated invoice images) |

**Architecture:** feature-first (`lib/features/<name>/{data,presentation}`), plain `StatefulWidget` + `Future`/`FutureBuilder` for state (no external state-management package), a global `ValueNotifier<ThemeMode>` for light/dark theming, and a key-based `NavigationService` for context-free navigation. Brand colors and design tokens mirror the web app's design system so both clients feel like one product.

## 📱 Supported Platforms

Android · iOS · macOS · Windows · Linux · Web — all six Flutter targets are scaffolded in this repo.

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

Cottage reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at **build time** via `--dart-define` (see [`lib/helpers/supabase_service.dart`](lib/helpers/supabase_service.dart)) — there's no runtime `.env` file. Without them, the app builds fine but every screen that talks to Supabase (starting with login) will fail.

```sh
cp env.json.example env.json
# then fill in your project's URL and anon key
```

Run the app with the credentials injected:

```sh
flutter run --dart-define-from-file=env.json
```

> ⚠️ **Release builds must pass the flag explicitly.** A plain `flutter build apk --release` (or Android Studio's *Build > Build APK(s)*) silently ships a broken build that can't log in. Use the provided script instead:
> ```sh
> ./build_release.sh      # macOS / Linux / WSL
> ./build_release.ps1     # Windows PowerShell
> ```

### 3. *(Optional)* Enable push notifications

Native push needs a separate Firebase project:

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com).
2. Add an Android app with package name `com.cottage.cottage`.
3. Download `google-services.json` and place it at `android/app/google-services.json` (gitignored — the app still builds without it, just with push disabled, see [`PushNotificationService`](lib/helpers/push_notification_service.dart)).
4. For the backend to *send* pushes, generate a service-account key (Firebase Console → Project Settings → Service Accounts) and configure it as `FIREBASE_SERVICE_ACCOUNT` on the web app's side.

## 📂 Project Structure

```
lib/
├── common_widgets/     # Shared UI — app scaffold, bottom nav shell, bottom sheets, empty states
├── constants/          # App name, theme (CottageColors, CottageSurface)
├── features/
│   ├── auth/            # Login, signup, forgot password, Google OAuth
│   ├── dashboard/        # Home screen — summaries, roster, notices, expenses
│   ├── meal/             # Meal details, bazar purchases, deposits
│   ├── bazaar_duty/      # Grocery-duty roster
│   ├── utilities/        # Utility expenses, deposits, dues
│   ├── menu/              # Settings hub + member directory
│   ├── notices/          # Notice board (feed / scheduled / history)
│   └── notifications/    # In-app notification center
├── helpers/             # Supabase client, push notifications, navigation, formatting
├── models/              # Shared data models (e.g. Profile)
└── main.dart            # App entry point, theming, auth gate
```

## 🎨 Design Language

Cottage's UI mirrors the web app's design tokens for a consistent cross-platform feel — a warm brand orange (`#DE7356`) drives buttons and active states, with dedicated light/dark surface palettes and status tone colors (blue, green, orange, red) for badges and balances throughout the app.

---

<p align="center"><sub>Built with Flutter · Powered by Supabase</sub></p>
