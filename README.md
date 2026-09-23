# Pharco Expenses (Flutter)

A ground-up rebuild of the Pharco Corporation sales-rep travel & expense-claim
app, for Android and iOS. Reverse-engineered from the original ASP.NET
Core/ABP backend (`Pharco.Application.dll`) and the released Xamarin.Forms
mobile app — see the functional spec produced during that analysis for the
full business-rule breakdown (distance-based mileage cost, meal per-diem,
extra costs with receipts, two-tier manager approval chain, monthly quotas).

## Stack

- **Flutter** (Android + iOS) — Riverpod for state, go_router for navigation
- **Supabase** — Postgres database, Auth, and Storage (receipt photos)
- **Google Directions API** (optional) — real driving distance; falls back to
  a Haversine straight-line estimate if no API key is configured

## Getting started

The `android/` and `ios/` platform folders are already included and
pre-configured (see "Android build notes" below for what was tuned and why).
If you ever need to regenerate them from scratch:

```bash
cd pharco_app
flutter create . --platforms=android,ios --org com.pharco
flutter pub get
```

`flutter create .` only adds the missing platform scaffolding — it will not
touch the existing `lib/` or `pubspec.yaml` you already have. Note that
regenerating `android/` will discard the version pins described below, so
re-apply them if you do this.

### 0. Android build notes (read this before your first Android build)

This project's Android toolchain needed a few adjustments to build cleanly.
They're already applied in this repo — this section is so you understand
*why*, and can redo them if you ever regenerate `android/`:

- **JDK 17+ required.** A modern Android Gradle Plugin needs Java 17–20;
  Java 11 fails with an AGP/Java compatibility error. Install a JDK 17
  (e.g. [Temurin](https://adoptium.net/)) and point Flutter at it:
  `flutter config --jdk-dir=/path/to/jdk-17`.
- **AGP/Kotlin pinned to known-published versions** in
  `android/settings.gradle.kts` (`com.android.application` 8.7.2,
  `org.jetbrains.kotlin.android` 2.1.0) and the Gradle wrapper pinned to
  8.10.2 in `android/gradle/wrapper/gradle-wrapper.properties`. Whatever
  Flutter version you're on may default `settings.gradle.kts` to a much
  newer AGP version string that doesn't actually exist in Google's Maven
  repo yet, which fails with a confusing "plugin not found" error.
- **`compileSdk` pinned to 36** in `android/app/build.gradle.kts` — a couple
  of plugins (`flutter_plugin_android_lifecycle`, `app_links`) need a higher
  SDK than some Flutter versions default to.
- **A real bug in the `app_links` plugin** (pulled in transitively by
  `supabase_flutter` for deep-link auth callbacks): its
  `android/build.gradle` declares its own separate Android Gradle Plugin
  classpath, which breaks Flutter's `flutter.compileSdkVersion` property
  injection for that one subproject and fails the build with *"Could not get
  unknown property 'flutter' for extension 'android'"*. This lives in your
  global pub cache, not in this repo, so it needs to be re-applied any time
  pub re-fetches `app_links` from scratch (a fresh machine, a cleared pub
  cache, etc.) — run this once after `flutter pub get`, before building for
  Android:
  ```bash
  bash scripts/fix_app_links_gradle.sh
  ```
- **First Android build needs real disk space and a stable connection.**
  The very first build downloads the Gradle distribution, the Android NDK,
  and every dependency's Android artifacts — budget at least 5–6GB of free
  disk and expect it to take several minutes.

### 1. Set up Supabase

1. Create a project at supabase.com.
2. Run `supabase/migrations/0001_init.sql` in the SQL editor (or via the CLI:
   `supabase db push`). It creates every table, the manager-hierarchy RLS
   policies, and a public `receipts` storage bucket.
3. Seed your lookup tables (`governorates`, `cities`, `companies`, `lines`,
   `territories`, `bricks`, `territory_bricks`, `titles`,
   `reimbursement_policy`) with your real org data — there's no seed data
   included since it's specific to Pharco's org chart and territories.
4. **Sign-in model**: employees log in with their **employee code**, not a
   real email (same as the original app). Under the hood each code maps to a
   fixed synthetic address `{code}@pharco.local` for Supabase Auth. Default
   password on account creation is `123456`; the login screen's "Forgot
   password?" resets it to a fixed `Ph@123` (no email link — these accounts
   don't have real inboxes). Both behaviors are server-side Edge Functions
   (`supabase/functions/provision-employee`, `supabase/functions/reset-password`)
   since changing another user's password needs the service-role key, which
   must never live in the Flutter app. Deploy them with:
   ```bash
   supabase functions deploy provision-employee
   supabase functions deploy reset-password
   ```

   **To create one test employee quickly without the CLI**, in the Supabase
   dashboard:
   1. Authentication → Users → Add user. Email: `1001@pharco.local`,
      Password: `123456`, check "Auto Confirm User". Copy the generated user
      UUID.
   2. Table Editor → `employees` → insert a row: `id` = that UUID,
      `code` = `1001`, `full_name` = whatever you like, leave `manager_type`
      as `0`.
   3. In the app, sign in with Employee Code `1001`, password `123456`.

5. Create the rest of your employee accounts the same way (or via the
   `provision-employee` function once deployed), inserting a matching row in
   `employees` for each, setting `manager_id` and `manager_type` to build the
   approval hierarchy:
   - `manager_type = 0` — individual rep, no direct reports
   - `manager_type = 1` — first-line manager (their "approve" forwards to a
     second-level manager instead of finalizing)
   - `manager_type = 2` — second-level manager (finalizes; also reviews what
     first-line managers under them have forwarded)
   - `manager_type = 3` — direct/top-level manager (finalizes directly)

### 2. Run the app

With a device/emulator connected (`flutter devices` to check):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxx \
  --dart-define=GOOGLE_MAPS_API_KEY=xxxx
```

`GOOGLE_MAPS_API_KEY` needs the Directions API enabled and billing set up on
that Google Cloud project. Without it, every travel/return distance silently
falls back to straight-line (Haversine) distance instead of real driving
distance — which is also why, without a key, the travel and return legs of
the same trip always come out identical (a straight line has no direction;
a real driving route does).

Or build a debug APK to sideload onto a real Android phone (no emulator
needed — copy the resulting file to the phone and open it; you'll need to
allow installs from unknown sources):

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxx \
  --dart-define=GOOGLE_MAPS_API_KEY=xxxx
```

The APK lands at `build/app/outputs/flutter-apk/app-debug.apk`. For iOS,
Xcode (and therefore a Mac) is required — this is an Apple restriction, not
a Flutter one.

## What's implemented

- Employee-code + password sign-in (Supabase Auth under the hood), with a
  "Forgot password?" reset to the fixed default
- Home dashboard with pending/approved/declined counts
- New expense request: request type, outbound/return cities (or home
  address) + dates, extra-cost line items, live cost preview before submit
- My Requests list, filterable by status, and a request detail screen
- Manager: team list → an employee's requests → approve (with per-line
  extra-cost accept/reject) or decline with a reason, including the
  "no changes after the 3rd of the month" cutoff rule
- Profile + sign out

## Notable simplifications vs. the original backend

- The original "Create (draft) → confirm" two-call flow is combined into a
  single preview-then-submit action; no separate "Draft" status is stored.
- Distance is memoized in a `distances` table exactly like the original
  `Distance` entity, keyed by city pair or (employee, city) for home-address
  legs.
- The original's GPS/geo-fencing visit-validation subsystem (background
  Excel-import reconciliation, `Request.Status` Valid/Suspicious/NoVisit) is
  back-office tooling, not part of the mobile app, and isn't included here.
