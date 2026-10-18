# Verification

Evidence log for this build. Everything below was run in this repository on
2026-10-17 and 2026-10-18. Anything that could not be run here is listed as
outstanding, with the reason, rather than marked as passing.

Toolchain: Flutter 3.29.0, Dart 3.7.0, Java 21, Node 26.7.0, Android SDK
platform 35 and build-tools 35 (Gradle also installed platform 34, build-tools
34, CMake 3.22.1, and NDK 27.0.12077973 for the plugins that request them).

## 1. Checks and results

| Check | Command | Result |
| --- | --- | --- |
| Dart analysis | `flutter analyze` (in `app/`) | No issues found |
| App tests | `flutter test` (in `app/`) | 220 passing |
| Rules tests | `npx firebase-tools@13 emulators:exec --only firestore,storage --project quiet-tally-rules "npm --prefix rules-tests test"` | 28 passing |
| Debug APK build | `flutter build apk --debug --flavor dev` | Built `app-dev-debug.apk` |
| Release APK build | `flutter build apk --release --flavor prod` with a local keystore | Built `app-prod-release.apk`, `apksigner verify` passes |
| APK install and launch | `adb install -r`, then launcher intent on emulator-5554 (Android 11, API 30) | Installed and focused |
| Release signing guard | `flutter build apk --release --flavor prod` without `key.properties` | Fails with the intended message |

## 2. Unit and widget evidence

- Calculator engine: 61 cases covering entry, immediate execution, repeat
  equals, operator replacement, percent, sign, rounding, the 12 character cap,
  overflow to Error, and error recovery (`test/calculator_engine_test.dart`).
- PBKDF2-HMAC-SHA256 matches two RFC 7914 vectors and one independent 210,000
  iteration vector generated with Node's crypto.
- Trigger detector: triple tap boundaries at 350 ms and 700 ms, sequence reset,
  PIN shaped entry.
- Message composer: exact template, six decimal coordinates, ASCII only, the
  four forbidden terms, name fallback, and the 300 character ceiling.
- Tokens: 32 base64url characters, 100,000 samples with zero collisions, and
  24 hour versus 1 hour expiry.
- Contact validation: E.164 normalisation, duplicates in a different format,
  name length, and the disabled save state.
- Trigger controller: 19 cases with fakes covering the full pipeline, cancel
  before and after five seconds, cancel before the SMS phase, cooldown, a
  failed service start, and delivery reporting.
- Widgets: the calculator at 320, 360, and 420 dp and at 200 percent text
  scale, a 2 second long press opening the gate and 1.5 seconds not, no setup
  after a triple tap, PIN plus equals with no dialog or snackbar, one haptic
  pulse, no sound call, PIN gate creation rules and lockout, permission rows,
  contact sheet validation, and setup status rows.
- Contrast test measures every palette pair: ink on paper 13.69:1, oxide on
  paper 5.35:1, paper on oxide 5.35:1, ink on key surface 11.55:1, ink on
  pressed key 10.44:1, muted ink 6.13:1, status colors 4.70:1 to 6.08:1. All
  meet AA at minimum.
- Copy scan: no em dash or en dash in any project file, and none of the banned
  marketing terms. Both scans only matched files inside `node_modules`.

## 3. Contact page

Verified in a real browser through the agent-browser CLI at a 320 px viewport,
with seeded documents in the Firestore emulator. `config.useEmulator` was set
to true for these checks and restored to false afterwards.

| State | Observed |
| --- | --- |
| Loading | "Opening alert" with the thin line indicator |
| Active | "Alert from Amal", Live badge, coordinates 1.352100, 103.819800, "Accuracy 18 m. Updated 5 seconds ago", audio note "30 seconds. Recorded 21 seconds ago", expiry line, 4 map tiles rendered, trail polyline drawn |
| Ended | "This alert ended" with the end time, no Live badge, last location kept |
| Test | "Test alert" with Live badge |
| Stale location | "Location is not updating. Last update 5 minutes ago" |
| No location | "Location unavailable" |
| No audio | "Audio unavailable", player hidden |
| Not found or expired | "This alert does not exist or has expired" |
| Offline | "No connection. Retrying." after the 12 second first snapshot timeout |

- Horizontal overflow: none at 320 px (`scrollWidth == innerWidth`).
- Reduced motion: the loader animation computes to `none`.
- Console and page errors: none.
- axe-core 4.12.1: 0 violations. Contrast measured on the rendered page:
  title 13.69:1, Live badge 5.35:1, coordinates 13.69:1, age note 6.13:1,
  expiry 6.13:1, call action 13.69:1.
- One real defect was found and fixed: the map container carried `role="img"`
  while Leaflet's controls are interactive, which axe reported as
  nested-interactive. The map is now a plain container and the coordinates line
  is the accessible location.
- An early check also found that relative asset paths broke the page, because
  it is served at `/i/<token>` and Hosting rewrites unknown paths to
  `index.html`. Every asset reference is now absolute.

## 4. On-device evidence (debug build, API 30 emulator)

- `adb install -r app-dev-debug.apk` reported Success.
- The launcher intent focused `com.tally.calculator.dev/com.tally.calculator.MainActivity`.
- logcat shows the Flutter engine starting with no Dart exception.
- The accessibility tree contains the display "Display 0" and every key with
  its label: clear/AC, sign/+/- percent/%, divide/÷, 7, 8, 9, multiply/×, 4,
  5, 6, minus/-, 1, 2, 3, plus/+, zero/0, decimal/., equals/=. No safety terms
  appear anywhere on the surface.
- Tapping the 7 key changed the live region to "Display 7".
- `aapt dump badging` reports `application-label: 'Calculator'`, launchable
  activity `com.tally.calculator.MainActivity`, and exactly the permission list
  from SPEC 12.1 and 12.2. None of the SPEC 12.3 permissions are present.

## 5. Deviations from SPEC.md, with reasons

1. **Trigger step order.** SPEC 13.3 orders the incident document write before
   the foreground service start. The implementation starts the service first so
   the process stays alive while the network write completes. Both steps stay
   inside the stated budgets (service 500 ms target, write 2000 ms target).
2. **PIN compare timing.** SPEC 13.3 asks for a compare under 50 ms. Measured
   in debug mode: an entry whose length does not match exits in 39 microseconds
   (the length check runs before hashing), while a length-matching entry costs
   1.1 to 1.3 seconds for the 210,000 iteration derivation, run off the UI
   thread. The iterations are fixed by SPEC 10, so the target cannot be met in
   software on this hardware. The display clears and the haptic fires before the
   derivation, so the visible trigger is immediate, and the 15 second
   trigger-to-SMS budget is unaffected. Release mode timings are unverified
   here.
3. **Audio upload retry on open.** SPEC 19.2 says the app retries a pending
   upload on the next open. Retrying at cold start would initialize Firebase on
   the calculator path, which SPEC 8.6 forbids. The retry runs when Safety
   settings opens instead, inside the one hour window.
4. **Resumed upload metadata.** On the resume path the recording duration is
   unknown, so `durationSec` is written as 0 in the Storage metadata. The page
   player still reads the real duration from the file.
5. **Cancel after a process restart.** Cancel compares against the in-memory
   active incident. If Android kills the process mid-alert, a later PIN plus
   equals starts a new incident instead of canceling the old one, which expires
   on its own. There is no local incident state by design.
6. **Key layout.** The zero key spans two cells and equals spans one, so the
   4 by 5 grid has no dead cell. SPEC 8.2 requires equals to span one cell.
7. **Added copy.** Four strings are not in the copy deck because the deck has no
   entry for the case: "Choose a PIN you have not used before." (SPEC 10 rejects
   reusing the last PIN), "That number is already added." (SPEC 11 rejects
   duplicates), and the two test alert failure lines. Two setup rows were also
   added to reach requirements elsewhere in the spec: "Name in the alert"
   (SPEC 17.2, open question Q-02) and "Triple-tap trigger" (SPEC 13.1 says the
   setting exists).
8. **`res/xml/backup_rules.xml` omitted.** SPEC 44 lists the file, but SPEC 31
   fixes `android:fullBackupContent="false"` plus `dataExtractionRules`, so the
   file would be dead. Everything is excluded in both places.
9. **Emulator ports.** 8080, 9099, and 9199 were already taken on this machine,
   so `firebase.json` uses 8180, 9298, and 9299, and the app, the page, and the
   CSP match.
10. **Lockout wording.** The countdown rounds up on milliseconds, so a fresh 30
    second lock does not read as "29 seconds".
11. **Contact page asset paths.** See section 3.
12. **Audio package.** SPEC 15 names the format, not the package. The umbrella
    `record` package pulls `record_linux` into the generated Dart plugin
    registrant, and that package does not compile against the current platform
    interface (its `hasPermission` is missing a named argument). The app depends
    on `record_android` and `record_platform_interface` directly, which is also
    the honest shape for an Android only product.

## 6. Build environment notes

- The machine started with only `platform-tools`. The SDK platform, build
  tools, and NDK were installed with `sdkmanager`; Gradle installed the rest.
- The SDK lives inside a long temporary path, which exceeded the Windows path
  limit and broke the C compiler launch. A directory junction now exposes it at
  `%LOCALAPPDATA%\Android\Sdk`. This is a local machine setup detail, not a
  repository change.
- `android/local.properties` is ignored by git and points at the machine SDK.

## 7. Not verified here, and why

These need a physical device or a Firebase project, so they are recorded as
outstanding rather than passing.

- SMS delivery to three real contacts, and `SmsManager` behaviour with no SIM
  or in airplane mode.
- Background recording for the full 30 seconds on a physical device, including
  the interrupt-on-call path, and the microphone privacy indicator.
- Real GPS accuracy gates, the 15 minute window, and battery draw over 15
  minutes (SPEC budget: under 5 percent on a 4000 mAh device).
- A release APK installed on Android 10 through 15. Only the debug dev build
  was installed, on API 30.
- TalkBack walkthrough, notification shade and history inspection, recents
  screen, and Android Settings battery attribution checks.
- Firestore TTL and Storage lifecycle deletion timing in a real project.
- Live Firebase calls from the app. `google-services.json` wires project
  `nightjar-8d561`, but that file registers the Android package
  `com.hyperonx.nightjar` while the app ships as `com.tally.calculator`
  (SPEC 22.1). The Dart options initialize the project regardless, and calls
  only fail if the owner restricted the API key by package. Register
  `com.tally.calculator` and `com.tally.calculator.dev` in the Firebase console
  to remove that risk.

## 6a. Signing

The release APK is signed with a locally generated key at
`%USERPROFILE%\.nightjar\nightjar-release.jks`. The credentials live in
`app/android/key.properties`, which git ignores. That key is the app's signing
identity: every future update must use it, so the folder needs a backup. The
release guard still fails any build that has no `key.properties`.

## 8. antislop Delivery Gate

See `anti-slop/audit-001-2026-10-17.md` for the findings list and the gate
report.
