# SPEC

Nightjar covert SOS app
Status: implementation specification, MVP
Platform: Android only, Flutter
Related documents: `GOAL.md`, `DESIGN.md`, `AGENTS.md`

This document is the source of truth for behavior. If code and this spec disagree, the spec wins until it is revised.

## Contents

1. Definitions
2. Product summary
3. Users and jobs
4. Scope
5. Success criteria
6. Platform constraints
7. Surfaces and information architecture
8. Calculator requirements
9. Hidden setup entry
10. PIN requirements
11. Contacts requirements
12. Permissions requirements
13. Trigger requirements
14. Cancel requirements
15. Audio requirements
16. Location requirements
17. SMS requirements
18. Incident data requirements
19. Upload and retry
20. Contact page
21. Expiry and retention
22. Stealth requirements
23. Screen specifications
24. Copy deck
25. Visual requirements
26. Accessibility requirements
27. State machines
28. Firestore schema
29. Security rules (Firestore and Storage)
30. Firebase configuration
31. Android manifest
32. Native SMS bridge
33. Foreground service
34. Error matrix
35. Privacy
36. Threat model
37. Performance budgets
38. Logging and observability
39. Testing strategy
40. Acceptance criteria
41. Build and release
42. Verification checklist
43. Decisions and open questions
44. File tree
45. Glossary

## 1. Definitions

- Incident: one triggered alert, identified by a token.
- Token: 24 random bytes, base64url encoded, used as the public Firestore document id and the contact page path.
- Trusted contact: one of the three phone numbers configured by the owner.
- Owner: the person who installed the app and completed setup.
- Active window: the 15 minutes after trigger during which location updates are sent.
- Recording window: the 30 seconds after trigger during which audio is captured.
- Setup: the hidden configuration area reached by long-pressing AC and entering the PIN.
- Cover: the visible calculator app.
- FGS: Android foreground service.
- TTL: Firestore Time to Live deletion policy.

## 2. Product summary

Nightjar is an Android app that looks and works like a calculator. A person in an unsafe situation can trigger a silent alert by typing a secret PIN and pressing equals, or by triple-tapping the display. The app records 30 seconds of audio, shares live location for 15 minutes, and sends a text message with a coordinate link and a private web page to three trusted contacts. The app keeps no incident history, and server data expires after 24 hours.

The app does not claim to be undetectable. Android shows a foreground service notification and a microphone indicator. The product is designed for a brief, discreet action, not for defeating a determined forensic adversary.

## 3. Users and jobs

Primary user: an adult in a household or relationship where openly calling for help is unsafe. They need a phone that does not reveal a safety app and a trigger that can be done in a few seconds.

Secondary user: a trusted contact who receives an SMS on a normal phone. They need to understand what happened, see a location, hear the audio, and act, without installing anything.

Jobs to be done:
- Open an app that looks normal to anyone watching.
- Trigger help without a confirmation screen, sound, or message.
- Give contacts enough location and context to act.
- Leave no obvious trace in the app or its history.
- Stop the alert if it was a mistake.

## 4. Scope

In scope for the MVP:
- Android 10 through 15.
- A fully working calculator cover.
- Hidden setup with PIN, three contacts, permissions, and a test alert.
- PIN trigger and triple-tap trigger.
- 30 second audio capture.
- 15 minutes of location updates.
- SMS to three contacts.
- A public incident page with map, trail, audio, and expiry.
- 24 hour server expiry.
- No in-app history.
- Direct APK distribution.

Out of scope for the MVP:
- iOS.
- Google Play distribution.
- A contact-side app.
- Push notifications to contacts.
- Deleting SMS from the recipient phone.
- Weather cover, decoy vault, remote wipe, duress PIN, or fake crash screen.
- Analytics, crash reporting, ads, or any third-party telemetry.
- Multi-language.
- Contact import from the device address book.
- End-to-end encrypted audio beyond TLS in transit and Google-managed encryption at rest.
- Offline map tiles.

## 5. Success criteria

The MVP is successful when all of the following are true:
- A stranger who picks up the phone sees a normal calculator and cannot find a safety feature without the gesture and PIN.
- A complete alert can be triggered in under 5 seconds from a cold app open.
- All three contacts receive an SMS on a live carrier network.
- The contact page shows a location within 30 seconds of trigger and updates for 15 minutes.
- Audio playback succeeds on the contact page for a 30 second recording.
- The app stores no incident list, no message history, and no audio after upload.
- Incident and audio data carry a 24 hour expiry and are removed by TTL and lifecycle policies, verified in staging with short expiry values.
- The app passes the verification checklist in section 42 with recorded evidence.

## 6. Platform constraints

These constraints are part of the product, not defects.

6.1 Foreground service notification
Android requires a visible notification for microphone and location use in the background. The app uses a low-importance channel named `Calculator`, no sound, no vibration, and neutral text. The notification can appear in the shade, in notification history, and in the active apps view. It cannot be removed while the service runs.

6.2 Microphone privacy indicator
Android 12 and later show a privacy indicator when the microphone is used. This cannot be suppressed.

6.3 SMS deletion
An app cannot delete a sent SMS unless it is the default SMS app. Nightjar does not request the default SMS role. The app keeps no local SMS history, but the message remains on the recipient phone. Product copy must never claim that messages self-delete on the recipient device.

6.4 Background start
A foreground service with the microphone type cannot start from the background on Android 14 and later. The trigger happens in the visible calculator activity, so this requirement is satisfied.

6.5 Background location
If background location permission is denied, location may stop when the app leaves the foreground. The app requests the permission with a plain explanation and degrades honestly.

6.6 OEM battery managers
Some manufacturers kill foreground services. Setup includes a battery optimization step. The app cannot guarantee survival on every device.

6.7 Distribution policy
Google Play restricts covert surveillance and background SMS. The MVP ships as a signed APK through a trusted channel. Distribution requires legal review and published Terms and Privacy pages.

6.8 Legal
Recording ambient audio may require consent in some jurisdictions. The owner is responsible for compliance. Setup includes a short legal notice. This is not legal advice.

## 7. Surfaces and information architecture

There are four surfaces.

7.1 Calculator
The only surface visible without authentication. It must be a credible everyday calculator.

7.2 PIN gate
Reached by long-pressing AC for 2 seconds. It is the only entry to setup.

7.3 Setup
A small stack of screens: status, PIN change, contacts, permissions, test alert, about.

7.4 Contact page
A public web page at `/i/<token>`. It is not part of the app and does not require installation.

There is no onboarding on first launch. Setup instructions live in `docs/SETUP.md`, which is delivered with the APK. The owner must read them before relying on the app.

## 8. Calculator requirements

8.1 Behavior model
The calculator uses immediate execution, the way a physical pocket calculator works. There is no expression parser and no operator precedence. Example: `2 + 3 x 4 =` yields `20`.

8.2 Keys
Row 1: AC, +/-, %, divide.
Row 2: 7, 8, 9, multiply.
Row 3: 4, 5, 6, minus.
Row 4: 1, 2, 3, plus.
Row 5: 0, decimal, equals.
Equals spans one cell. The layout is a 4 by 5 grid.

8.3 Display
- Right-aligned, single line.
- Maximum 12 significant characters, including the decimal point and minus sign.
- Uses comma grouping for integer parts with more than 3 digits.
- Auto-shrinks between 48sp and 24sp to avoid overflow. It never scrolls horizontally.
- Shows `Error` for divide by zero and for overflow beyond 12 characters.
- After `Error`, the next digit starts a new entry, and AC clears.

8.4 Arithmetic
- Digits append to the current entry. A maximum of 12 digits is accepted, excluding separators.
- A second decimal point is ignored.
- An operator commits the current entry and stores the pending operator.
- Pressing equals commits and shows the result.
- Pressing an operator twice replaces the pending operator.
- Percent divides the current entry by 100. It does not implement context-dependent percent-of behavior.
- Sign toggles the current entry or the displayed result.
- AC clears entry, pending operator, and accumulator.
- Result precision: double, formatted to at most 12 significant digits. Avoid floating point artifacts in display by rounding to 12 significant digits.

8.5 Feedback
- Key press: light haptic feedback, no sound.
- A long press on AC at 2 seconds gives a medium haptic and opens the PIN gate.
- No other gestures are visible or documented in the UI.

8.6 Startup
- The calculator must be interactive within 1.5 seconds on a mid-range device.
- Firebase must not initialize on the calculator path. Initialize Firebase only when setup or trigger needs it.
- The app must open directly to the calculator, with no splash, onboarding, or login.

8.7 Semantics
- Each key has a content description: `7`, `plus`, `minus`, `multiply`, `divide`, `equals`, `clear`, `percent`, `sign`, `decimal`, `zero`.
- The display is a live region. It announces the current value only when accessibility is enabled. It must not announce trigger activity.

8.8 Credibility
- No developer menus, no debug text, and no safety references on the calculator surface.
- The app name and launcher icon are Calculator.
- The about screen is inside setup, behind the PIN.

## 9. Hidden setup entry

- Gesture: long-press AC for 2000 ms, measured with a timer that cancels if the finger moves more than 24dp or lifts.
- On threshold: medium haptic, then the PIN gate.
- If no PIN exists: the create PIN screen.
- If a PIN exists: the enter PIN screen.
- Wrong PIN shows `Incorrect PIN. Try again.` and clears the field.
- Five wrong attempts lock the gate for 30 seconds. Subsequent lockouts are 1 minute, 5 minutes, and 15 minutes. The counter resets after a successful unlock.
- Lockout state is stored in secure storage so a process restart does not reset it.
- The lockout applies only to setup. The alert trigger still works while setup is locked.
- There is no PIN recovery. Reinstalling clears setup. This is documented.
- The PIN gate must not reveal whether an alert is active.

## 10. PIN requirements

- Length: 4 to 8 digits.
- Rejected values: all identical digits (`0000`, `1111`), ascending or descending sequences of length 4 or more (`1234`, `4321`, `9876`), and the same PIN as the last used PIN.
- Storage: PBKDF2-HMAC-SHA256, random 16 byte salt per PIN, 210,000 iterations, 32 byte derived key.
- The hash, salt, iteration count, and failed attempt state live in `flutter_secure_storage` with Android encrypted shared preferences backed by the Keystore.
- Comparison uses a constant-time comparison.
- The PIN is never logged, never written to Firestore, and never included in analytics or crash reports.
- The PIN is held in memory only while the field is being validated. Dart strings are immutable, so memory zeroing is best effort. Do not cache the PIN.
- Changing the PIN requires the current PIN, then the new PIN twice.
- A 4-digit PIN has at most 10,000 combinations. If an attacker has root access to the device, offline brute force is possible. The Keystore and rate limiting reduce casual risk, not forensic risk. This limitation is documented in the threat model.

## 11. Contacts requirements

- Exactly three contacts are required to complete setup.
- Each contact has a display name of 1 to 40 characters and a phone number in E.164 format.
- Phone numbers are validated with `phone_numbers_parser` or an equivalent E.164 parser. Invalid numbers block save.
- Duplicate numbers are rejected.
- Contacts are stored only on the device, in secure storage, as a JSON array. No contact name or number is written to Firestore.
- Editing and deleting contacts requires the PIN gate.
- Contact data is deleted on uninstall. There is no cloud backup.
- The UI must warn: `Your contacts receive a normal text message. Their carrier and their phone can see it.`
- The UI must warn: `Add all three. If one number is wrong, that person will not get your alert.`

## 12. Permissions requirements

12.1 Required for a full alert
- `RECORD_AUDIO`
- `ACCESS_FINE_LOCATION`
- `SEND_SMS`
- `POST_NOTIFICATIONS` on Android 13 and later. The service runs if denied, but the notification is hidden from the shade and appears only in the active apps view.
- `ACCESS_BACKGROUND_LOCATION` on Android 10 and later, requested separately with a Settings deep link.

12.2 Manifest only
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MICROPHONE`
- `FOREGROUND_SERVICE_LOCATION`
- `WAKE_LOCK`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

12.3 Not requested
- `READ_CONTACTS`
- `READ_SMS`
- `RECEIVE_SMS`
- `READ_PHONE_STATE`
- `CAMERA`
- `MANAGE_EXTERNAL_STORAGE`
- `SYSTEM_ALERT_WINDOW`

12.4 Permission UX
- Each permission has its own row in setup with a plain explanation, current status, and an action.
- Denial is not a dead end. The row explains what degrades and offers `Open settings`.
- Setup can be completed with denied permissions, but the status screen shows a persistent amber warning and the test alert reports the failure.
- No permission is requested on first launch before the user reaches setup.
- The app never requests a permission while the calculator is in normal use.

12.5 Degraded modes
- No microphone: the incident still sends location and SMS. The page says `Audio unavailable`.
- No location: the incident still sends SMS with the page link only. The page says `Location unavailable`.
- No SMS: the incident page is created but no contact is notified. Setup shows this as a failed check. There is no alternate delivery channel in the MVP.
- No notifications: the FGS still runs, subject to Android limits.
- No background location: updates may stop when the app is backgrounded. The page shows the last fix age.

## 13. Trigger requirements

13.1 Trigger methods
- PIN trigger: the current display entry equals the PIN digits exactly, and the user presses equals. Example: PIN `4826`, user types `4826`, presses `=`.
- Triple-tap trigger: three taps on the display area, each within 350 ms of the previous tap, and the total sequence within 700 ms. No PIN is required.
- Both methods are active by default. The settings screen allows disabling the triple-tap method.

13.2 Trigger preconditions
- The trigger works while the calculator is visible and the process is alive.
- If an incident is already active, a PIN trigger cancels it. A triple-tap is ignored to prevent accidental cancellation.
- If fewer than three contacts exist, the trigger does not start. It clears the display and gives no other feedback. This state is only possible if the user bypassed setup checks. Setup must prevent it.
- Device lock state: the app cannot trigger from the lock screen in the MVP.

13.3 Trigger sequence
1. Read the current display value and compare it with the stored PIN hash if the entry has the correct digit count. Compare takes under 50 ms.
2. Set the internal state to `starting`. Debounce for 2000 ms.
3. Clear the display to `0`. Give one 40 ms haptic pulse. No sound, no toast, no banner, no dialog.
4. Generate the token and write the incident document as `active` with `locationUnavailable = true`. This happens before delivery so the link is valid when the message arrives.
5. Start the FGS with microphone and location types.
6. Start the audio recorder and the location tracker in parallel.
7. Wait for the first location fix, up to 10 seconds.
8. Compose and send the SMS to the three contacts.
9. Continue location updates for 15 minutes.
10. Upload the audio when recording completes.
11. Move to `finalizing` when recording is done, upload succeeded or failed, and the location window has ended.
12. Move to `ended`, stop the FGS, clear the local queue entry.

13.4 Timing budgets
- Trigger to FGS start: 500 ms target, 1500 ms maximum.
- Trigger to incident document write: 2000 ms target, 5000 ms maximum with network.
- Trigger to SMS: 15000 ms maximum, bounded by the first fix timeout.
- Trigger to audio ready on the page: 40 seconds maximum, 30 seconds recording plus 10 seconds upload.

13.5 No visible confirmation
The app must not show a confirmation after trigger. The only feedback is the cleared display and the haptic pulse. The owner learns that an alert started from the setup status screen or from a contact.

13.6 Repeat triggers
- While active, attempts to trigger are ignored except the PIN cancel.
- After `ended`, a new trigger creates a new token and a new incident.
- A cooldown of 10 seconds applies after the end of an incident to avoid accidental double triggers.

## 14. Cancel requirements

- Cancel method: while an incident is active, type the PIN and press equals.
- Cancel is available from the calculator only, not from the contact page.
- On cancel:
  - Stop the recorder. If a partial valid file exists, it may be uploaded only if the cancel happens after 5 seconds. Before 5 seconds, discard it.
  - Stop location updates.
  - Set the incident status to `ended` and update `updatedAt`.
  - Stop the FGS.
  - Delete the local queue entry and any temp audio.
- The contact page shows `This alert ended` with the time and the last known location. It does not hide the page immediately because a contact may already be on the way.
- If the cancel happens before the SMS send begins, no SMS is sent and no contact is notified. The incident document may already exist and is marked `ended`; it expires normally.
- If the SMS has already been sent, contacts keep the link and the page shows the ended state. This behavior is intentional.
- Cancel gives no visible confirmation, only the cleared display.

## 15. Audio requirements

15.1 Format
- Container: MP4.
- Codec: AAC LC.
- Sample rate: 16,000 Hz.
- Channels: mono.
- Bit rate: 64 kbps.
- Expected size for 30 seconds: about 240 KB.
- Maximum accepted upload: 2 MB.

15.2 Capture
- Start within 500 ms of the FGS start.
- Record for 30,000 ms with a tolerance of 200 ms.
- If the recorder fails to start, continue without audio and record `audio.status = "failed"`.
- If the app loses focus or the screen locks, recording must continue under the FGS.
- If a phone call interrupts the recording, stop, finalize the partial file if valid, and mark the audio `partial`.
- Do not record before the trigger. Do not keep a rolling buffer. Do not record on app launch.

15.3 Local file handling
- Path: `${cacheDir}/nightjar/${token}.m4a`.
- Upload with `firebase_storage`.
- Delete the local file after a successful upload.
- Delete any remaining file after 1 hour, on app start and after every incident end.
- No audio is stored in app documents, media gallery, or external storage.

15.4 Upload
- Path: `incidents/{token}/audio.m4a`.
- Content type: `audio/mp4`.
- Custom metadata: `token`, `durationSec`, `recordedAt`, `schemaVersion`. No device identifiers.
- Retry policy: 3 attempts with backoff of 2, 5, and 15 seconds while the service is alive. After the service stops, retry on the next app open if the file is younger than 1 hour.
- After 1 hour, delete and mark `failed`.

15.5 Privacy
- The page requires the token link. There is no audio preview in the app.
- The audio is readable by anyone with the token path. See section 29 for the trade-off.
- No transcription, no speech analysis, no third-party processing.

## 16. Location requirements

16.1 Acquisition
- Request high accuracy.
- Use a cached last known position if it is younger than 2 minutes and accuracy is under 100 meters, as a provisional fix.
- Request a fresh fix with a 10 second timeout.
- After the first fix, subscribe to updates with a 10 second throttle.
- Stop after 15 minutes or on cancel.

16.2 Writes
- Update `incidents/{token}` with `location`, `accuracyMeters`, and `locationUpdatedAt`.
- Add one document to `incidents/{token}/pings` per accepted fix.
- Use a batched write so the parent and the ping stay consistent.
- The parent document is the live view. The pings collection is the trail.

16.3 Quality
- Store accuracy in meters.
- Mark `lowAccuracy = true` when accuracy is worse than 500 meters.
- Do not send a fix with accuracy worse than 2000 meters. Keep the previous fix and update `locationUpdatedAt` only when a fix is accepted.
- If no fix is available after 10 seconds, send the SMS with the page link only and keep trying for the full 15 minutes.

16.4 Display
- The contact page shows the last fix, its age, and the accuracy.
- If the last fix is older than 2 minutes, show `Location is not updating` and the age.
- The page never guesses a location from IP address.

16.5 Battery
- Do not request a wake lock beyond the FGS default.
- Do not use continuous high-frequency updates. 10 seconds is the floor.
- Stop all location work at the 15 minute cap.

## 17. SMS requirements

17.1 Delivery
- The app sends the SMS directly with `SmsManager`.
- Three messages are sent, one per contact. No group message.
- Sending starts after the incident document exists and after the first fix is available or the 10 second timeout expires.
- Messages are sent in parallel with a 20 second overall timeout.
- If a message fails, do not retry automatically. Record `failed`.
- No SMS is sent on cancel before the send begins.

17.2 Message content
Template:
`Alert from {name}. Live location: {mapsUrl} Details: {pageUrl}`
- `{name}` is the owner's display name, 1 to 20 characters. Default `a contact`.
- `{mapsUrl}` is `https://maps.google.com/?q={lat},{lng}` with 6 decimal places. Omit when no fix is available.
- `{pageUrl}` is `https://quiet-tally.web.app/i/{token}`.
- ASCII only. No emoji, no smart quotes.
- Total length must be at most 300 characters. Multipart messages are allowed.
- The message must not contain the words Nightjar, SOS, abuse, or help me.
- Example: `Alert from Amal. Live location: https://maps.google.com/?q=1.352100,103.819800 Details: https://quiet-tally.web.app/i/8Fj2...`

17.3 Delivery status
- The native bridge returns `sent`, `failed`, or `permission_denied` for each number.
- The app writes `contactsAlerted` and a `delivery` array with channel and status only. No numbers.
- `sent` means the platform accepted the message for sending, not that the recipient received it.
- The app cannot confirm receipt without `RECEIVE_SMS`, which is not requested.

17.4 SIM behavior
- Use the default SMS subscription.
- If no SIM is present or the device is in airplane mode, all sends fail. The incident page is still created. The user sees the failure only in the test alert result and the setup status, not during a real alert.
- Do not switch SIMs or change messaging settings.

17.5 Sender history
- Because the app is not the default SMS app, sent messages are not stored by Nightjar.
- Whether the system or the default messaging app records the sent message is outside the app's control. Test on each target device and document the result.
- Product copy says `Nightjar keeps no message history`, not `messages self-delete`.

## 18. Incident data requirements

18.1 Token
- 24 bytes from `Random.secure()`.
- Base64url without padding, 32 characters.
- Used as the Firestore document id and the page path.
- Regenerate on collision. Collision probability is negligible.
- The token is a bearer capability. Anyone with it can read the incident.

18.2 Incident fields
Required on create:
- `ownerUid`: Firebase anonymous auth UID.
- `schemaVersion`: integer, currently 1.
- `status`: `active`.
- `createdAt`: server timestamp.
- `updatedAt`: server timestamp.
- `expiresAt`: timestamp, `createdAt + 24h` computed with the server timestamp offset or with client time plus a safety margin. Use `Timestamp.now().add(Duration(hours: 24))` and accept clock skew.
- `trigger`: `pin`, `triple_tap`, or `test`.
- `appVersion`: string.
- `contactsAlerted`: integer, starts at 0.
- `delivery`: array of maps with `channel` and `status`.
- `locationUnavailable`: boolean, starts true.

Optional fields:
- `location`: geopoint.
- `accuracyMeters`: number.
- `locationUpdatedAt`: timestamp.
- `lowAccuracy`: boolean.
- `audio`: map with `status` (`pending`, `ready`, `failed`, `partial`), `path`, `durationSec`, `sizeBytes`, `uploadedAt`.

Forbidden fields:
- Contact names.
- Contact phone numbers.
- PIN or PIN hash.
- Device model, IP address, advertising id, or any device identifier.
- Free text entered by the user.

18.3 Ping fields
- `location`: geopoint.
- `accuracyMeters`: number.
- `at`: server timestamp.
- `atClient`: client timestamp.
- `expiresAt`: timestamp, same as the parent.

18.4 Status transitions
- `active` to `ended` only.
- No other status values in schema version 1.
- An expired incident is treated as `ended` by the page even if the document has not been deleted yet.

## 19. Upload and retry

19.1 Local queue
- One entry per active incident, stored in app-private storage, not in secure storage.
- Fields: token, audio path, createdAt, attempts, lastError.
- Maximum one entry. A new trigger replaces an expired entry.
- The queue never contains location or contact data.
- Delete on successful upload, on cancel, or after 1 hour.

19.2 Network
- Use the Firebase SDK's built-in offline persistence for Firestore writes.
- Storage upload has no automatic background retry after the process dies. The app retries on next open within the 1 hour window.
- Do not use WorkManager in the MVP. It adds scheduling variance and another place for PII to persist.

19.3 Failure handling
- On upload failure, mark `audio.status = "failed"` on the incident if the document write succeeds.
- Keep the local file for retry until 1 hour.
- Log no file path or token in release builds.
- If the incident document does not exist because the device is offline, keep the queue entry and retry the whole incident write on next open. The SMS already contains a link that will not work until the write succeeds. This is a known limitation.

## 20. Contact page

20.1 Route
- `/i/<token>`.
- Firebase Hosting rewrites all paths to `/index.html`.

20.2 Technology
- Static HTML, CSS, and JavaScript.
- Firebase JS SDK modular build from gstatic.
- Leaflet with OpenStreetMap tiles.
- Native audio element.
- No build step. No framework. No analytics.
- Self-hosted IBM Plex Sans and IBM Plex Mono woff2 files.

20.3 States
- Loading: `Opening alert` with a neutral progress indicator.
- Active: `Alert from {name}` and a live indicator.
- Ended: `This alert ended` plus the end time.
- Expired: `This alert does not exist or has expired`.
- Not found: same as expired, intentionally indistinguishable.
- Offline: `No connection. Retrying.` plus the last known location if cached in memory.
- Audio missing: `Audio unavailable`.
- Location missing: `Location unavailable`.
- Stale location: `Location is not updating` plus the age.

20.4 Content
- Status and last update time.
- Map with a marker, accuracy circle, and trail polyline.
- Last known coordinates as text, with six decimals.
- Audio player with duration and recording time.
- Expiry line: `This page stops working at {time}`.
- One action: `Call emergency services`, using `tel:112` by default. The number is configurable in `config.js`. The page never offers a call button to the owner, because ringing their phone can put them at risk.
- No owner phone number, no contact list, no device details.

20.5 Behavior
- Subscribe to the incident document and pings with `onSnapshot`.
- Reconnect automatically.
- Stop updating when the document is deleted.
- Update relative times every 10 seconds.
- `prefers-reduced-motion` is respected. There are no animations beyond a spinner while loading.
- The page works on a 320px wide screen with no horizontal scroll.
- The page must not require JavaScript for the static not-found message. A `<noscript>` message says `This page needs JavaScript.`

20.6 Security
- The token is the only credential.
- No contact PII on the page.
- No indexing. Add `noindex, nofollow` meta tags and a `robots.txt` that disallows `/i/`.
- Set a Content Security Policy.
- Do not put the token in a query parameter, only in the path.
- Do not log the token to the console in production.
- The page reads only its own document and its pings. Firestore rules block listing the incident collection.

20.7 Map
- OpenStreetMap tiles from `tile.openstreetmap.org`.
- Attribution is visible.
- The map is decorative if tiles fail. Coordinates remain visible.
- The map does not use a Google Maps API key.

## 21. Expiry and retention

21.1 Server
- Incident and ping documents carry `expiresAt`.
- Firestore TTL policies run on `incidents.expiresAt` and collection group `pings.expiresAt`.
- TTL deletion is asynchronous. Firebase documents may persist for up to 24 hours after the expiry time. Do not promise immediate deletion.
- Storage lifecycle deletes objects under `incidents/` 1 day after creation.
- No Firestore backups are enabled.
- No Storage object versioning.

21.2 Local
- No incident history.
- Temp audio is deleted after upload, on cancel, or after 1 hour.
- The upload queue is deleted on success, cancel, or after 1 hour.
- Contacts and PIN remain until uninstall or setup reset.
- Logs in release builds contain no location, token, or phone numbers.

21.3 User-facing language
- Use `Data is removed automatically after 24 hours. Removal can take a little longer.`
- Never say `deleted immediately`, `untraceable`, or `no one can see this`.

## 22. Stealth requirements

22.1 Manifest and launcher
- `android:label="Calculator"`.
- Application id: `com.tally.calculator`.
- Launcher icon: neutral calculator glyph, drawn as a vector, submitted for owner approval before use.
- No safety-related strings in the launcher, app info, or default activity label.

22.2 Activity
- `android:excludeFromRecents="true"`.
- `android:launchMode="singleTask"`.
- `android:exported="true"` for the launcher activity.
- `android:allowBackup="false"`.
- `android:fullBackupContent="false"` and data extraction rules disabled.
- No screenshots are blocked. Blocking screenshots on a calculator would look suspicious.
- The task description is the app name, Calculator. Set a neutral `android:description` if the launcher shows one.

22.3 Notifications
- Channel id: `calculator_service`.
- Channel name: `Calculator`.
- Importance: low, no sound, no vibration, no badge.
- Title: `Calculator`.
- Text: `Active`.
- No safety words.
- The notification is required by Android and is not removed.

22.4 App content
- No safety terms in the calculator UI.
- Setup uses `Safety settings` as its title after unlock.
- The about screen lists the app version and a short privacy note. It does not use the word Nightjar in the launcher or calculator.
- Debug builds exclude the setup shortcut from screenshots? Not possible. Keep release builds clean.

22.5 History
- No in-app incident list.
- No sent message log.
- No recent locations.
- No audio playback in the app.
- No "last alert" status on the calculator.
- Setup status shows whether the last test alert succeeded, with a timestamp, but not its contents. Clear it with a button.

22.6 Verification
- Check the launcher label and icon.
- Check the recent apps screen after backgrounding.
- Check the notification shade during an alert.
- Check Android Settings, Apps, Calculator.
- Check battery usage attribution.
- Record the results in the verification log.

## 23. Screen specifications

23.1 Calculator screen
- Display at the top, with the ledger rule under it.
- Key grid below, 4 columns, equal widths, 4dp gaps.
- Minimum key target 56dp by 56dp. The whole key cell is tappable.
- Maximum content width 420dp, centered.
- Background paper. Keys are key-surface color. The equals key uses the accent.
- No app bar, no title, no menu.
- System status bar uses the paper color with dark icons.
- Safe area insets respected. Bottom gesture area adds 8dp padding.

23.2 PIN gate
- Title: `Enter PIN` or `Create a PIN`.
- A single PIN field, 4 to 8 digits, masked by default with a show toggle.
- Keypad is the system numeric keyboard.
- Primary button: `Unlock` or `Continue`.
- Secondary text button: `Back to calculator`.
- Error text below the field, accent color.
- Lockout text replaces the error: `Too many attempts. Try again in 30 seconds.`
- No mention of alerts.
- Back returns to the calculator.

23.3 Setup status
- Title: `Safety settings`.
- Rows: PIN, Contacts, Permissions, Battery, Test alert.
- Each row shows a status icon, label, short status, and chevron.
- Primary button: `Send a test alert`.
- Secondary button: `Done`.
- If any requirement is incomplete, an amber summary line: `Finish the amber items before you rely on Nightjar.`
- No red unless something failed a test.

23.4 Contacts
- Three numbered slots.
- Empty slot: `Add contact`.
- Filled slot: name, masked phone number, `Edit`, `Remove`.
- Add/edit sheet: name field, phone field with country code hint, `Save`, `Cancel`.
- Inline validation, no modal error dialogs.
- Save is disabled until valid.
- Removing a contact requires confirmation.

23.5 Permissions
- One row per permission: microphone, location, background location, notifications, SMS, battery.
- Status: granted, denied, not requested.
- Explanation in one sentence.
- Action: `Allow` or `Open settings`.
- The microphone and SMS rows are marked `Needed for a full alert`.
- The background location row is marked `Recommended`.
- The notifications row says: `Android shows a small notification while an alert is active. It cannot be hidden.`
- The battery row says: `Some phones stop background work. Allow Nightjar to keep running.`
- Bottom text: `You can finish setup without these. The test alert will show what is missing.`

23.6 Test alert
- Confirmation screen before sending.
- Copy: `This sends a real text to your three contacts and records 5 seconds of audio. The link works for one hour.`
- Buttons: `Send test`, `Cancel`.
- Progress: one row per contact with `Sending`, `Sent`, `Failed`, or `No permission`.
- Result summary: `Test sent to 3 of 3 contacts.` or a list of failures.
- The test incident uses the same pipeline with a 5 second recording and a 60 second location window.
- It is stored in the same collection with `trigger = "test"` and an `expiresAt` of 1 hour.
- The contact page title is `Test alert`.
- No contact is notified without the confirmation screen.

23.7 About
- App version, build number.
- Privacy note with the 24 hour retention statement.
- `Delete all settings` with a typed confirmation. This clears the PIN, contacts, and queue, and returns to the calculator. It does not delete existing incidents; they expire.
- No external links in the MVP.

## 24. Copy deck

All copy is sentence case, plain language, no em dash, no buzzwords.

Calculator: no copy.

PIN gate:
- `Enter PIN`
- `Create a PIN`
- `Use 4 to 8 digits. Avoid repeated or sequential numbers.`
- `Unlock`
- `Continue`
- `Back to calculator`
- `Incorrect PIN. Try again.`
- `Too many attempts. Try again in 30 seconds.`
- `PINs do not match.`

Setup status:
- `Safety settings`
- `PIN` / `Set`
- `Contacts` / `3 of 3`
- `Permissions` / `2 need attention`
- `Battery` / `Allowed` or `Restricted`
- `Test alert` / `Last test: {date}`
- `Send a test alert`
- `Done`
- `Finish the amber items before you rely on Nightjar.`

Contacts:
- `Add contact`
- `Name`
- `Phone number`
- `Use the full number with country code.`
- `Your contacts receive a normal text message. Their carrier and their phone can see it.`
- `Add all three. If one number is wrong, that person will not get your alert.`
- `Save`
- `Cancel`
- `Remove contact?`
- `Remove`

Permissions:
- `Microphone` / `Records 30 seconds when you trigger an alert.`
- `Location` / `Shares your position for 15 minutes.`
- `Background location` / `Keeps sharing when the app is not on screen.`
- `Notifications` / `Android shows a small notification while an alert is active. It cannot be hidden.`
- `SMS` / `Sends the alert text to your contacts.`
- `Battery` / `Some phones stop background work. Allow Nightjar to keep running.`
- `Allow`
- `Open settings`
- `Needed for a full alert`
- `Recommended`
- `You can finish setup without these. The test alert will show what is missing.`

Test alert:
- `Send a test alert now?`
- `This sends a real text to your three contacts and records 5 seconds of audio. The link works for one hour.`
- `Send test`
- `Cancel`
- `Sending`
- `Sent`
- `Failed`
- `No permission`
- `Test sent to 3 of 3 contacts.`
- `Test finished. 2 of 3 contacts got the message.`

Contact page:
- `Opening alert`
- `Alert from {name}`
- `Test alert`
- `Live`
- `Updated 12 seconds ago`
- `Location is not updating`
- `Location unavailable`
- `Audio unavailable`
- `This alert ended`
- `This alert does not exist or has expired`
- `No connection. Retrying.`
- `This page stops working at {time}`
- `Call emergency services`
- `This page needs JavaScript.`

About:
- `Safety settings are stored on this phone. Alerts and locations are removed automatically after 24 hours. Removal can take a little longer.`
- `Delete all settings`
- `This removes your PIN, contacts, and any pending upload. Existing alerts expire on their own.`
- `Type DELETE to confirm.`

## 25. Visual requirements

25.1 Source of truth
`DESIGN.md` is the visual source of truth. This section lists testable requirements.

25.2 Palette
- Paper `#E9E5DB`.
- Ink `#1C1B18`.
- Key surface `#D9D3C6`.
- Accent oxide `#9C3D2E`.
- No gradients, no glow, no glass, no background grid.
- Accent appears on the equals key, one primary button per setup screen, and the live indicator on the contact page. It does not appear on body text, icons, borders, and backgrounds at the same time.

25.3 Type
- IBM Plex Sans for UI.
- IBM Plex Mono for the calculator display only.
- Fonts are bundled, not fetched at runtime.
- No uppercase tracked labels.
- Minimum body size 15sp. Minimum secondary size 13sp.

25.4 Shape
- Key radius 6dp.
- Card and row radius 8dp.
- Button radius 8dp.
- No pills except the live status badge on the contact page, which is a real state indicator.
- No border on every element. Use spacing and the ledger rule for grouping.

25.5 Elevation
- No shadows except the 1px key press depression.
- The contact page map may have a 1px border. No drop shadow.

25.6 Motion
- Press states only.
- Duration 90 ms, ease-out.
- No entrance animations, no looping animations, no pulsing live dot.
- Loading uses a static text plus a thin indeterminate line, not a bouncing element.

25.7 Identity motif
- The ledger rule: a 1dp ink line under the calculator display, repeated under the setup title and under the contact page status.
- It is the only repeated decorative element.

25.8 Themes
- Light theme only. A dark calculator would not match the office calculator identity, and a theme toggle adds a suspicious setting. This is a deliberate decision, recorded in `DESIGN.md`.

## 26. Accessibility requirements

26.1 Contrast
- Ink on paper: about 13.7:1, exceeds AAA for normal text.
- Accent on paper: 5.35:1, meets AA for normal text.
- Paper on accent: 5.35:1.
- Ink on key surface: at least 10:1.
- Verify with a contrast tool and record the result.

26.2 Touch
- Minimum 44dp by 44dp for every interactive target.
- Calculator keys are at least 56dp by 56dp.
- 8dp minimum gap between adjacent targets in setup.

26.3 Screen readers
- TalkBack labels on every key and control.
- The calculator display is a live region for the current value.
- Trigger activity is not announced.
- The contact page uses landmarks, headings, and descriptive link text.
- The audio player has a label and a duration.

26.4 Keyboard and focus
- The contact page is fully keyboard operable with visible focus rings.
- Flutter screens support hardware keyboard activation and focus traversal.
- Escape closes dialogs.
- Focus order follows visual order.

26.5 Text scaling
- Calculator display scales down, not up, to fit. Keys stay at least 56dp and labels remain readable at 200 percent system font scale.
- Setup screens reflow at 200 percent without clipping or horizontal scroll.
- Contact page uses relative units and reflows at 200 percent browser zoom.

26.6 Motion
- No animation is required to understand any state.
- `prefers-reduced-motion` is respected on the contact page.

## 27. State machines

27.1 App lifecycle
```
cold_start
  -> calculator_ready
  -> pin_gate (long press AC)
  -> setup (correct PIN)
  -> calculator_ready (back or Done)
```

27.2 Trigger controller
```
idle
  -> starting        (trigger accepted, debounce passed)
  -> active          (FGS started, recording and location running)
  -> finalizing      (recording done, upload attempted, location window over)
  -> ended           (service stopped, queue cleared)

active
  -> canceling       (PIN + equals)
  -> ended

starting
  -> idle            (FGS start failed, no incident created)

any
  -> error           (unrecoverable; incident marked ended if it exists)
```

27.3 Trigger state rules
- `idle` accepts a trigger if setup is complete, no cooldown is active, and the app is visible.
- `starting` blocks new triggers. It lasts at most 2000 ms.
- `active` accepts only the PIN cancel. Triple taps are ignored.
- `finalizing` accepts cancel and stops work early.
- `ended` accepts a new trigger after the 10 second cooldown.
- `error` returns to `idle` after cleanup.

27.4 Incident upload states
```
pending -> uploading -> ready
                     -> failed -> pending (retry, max 3)
failed -> deleted (after 1 hour)
```

27.5 Test alert states
```
idle -> confirming -> running -> summary
running -> canceling -> summary
```

## 28. Firestore schema

Collection: `incidents`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| ownerUid | string | yes | Firebase anonymous auth UID |
| schemaVersion | number | yes | 1 |
| status | string | yes | `active` or `ended` |
| trigger | string | yes | `pin`, `triple_tap`, or `test` |
| createdAt | timestamp | yes | server timestamp |
| updatedAt | timestamp | yes | server timestamp |
| expiresAt | timestamp | yes | created plus 24 hours, 1 hour for test |
| location | geopoint | no | latest accepted fix |
| accuracyMeters | number | no | latest accepted fix |
| locationUpdatedAt | timestamp | no | latest accepted fix |
| locationUnavailable | boolean | yes | true until a fix is accepted |
| lowAccuracy | boolean | no | accuracy worse than 500 m |
| contactsAlerted | number | yes | 0 to 3 |
| delivery | array of maps | yes | channel and status only |
| audio | map | no | see below |
| appVersion | string | yes | semantic version |
| name | string | no | owner display name, maximum 20 characters |

Audio map:
| Field | Type | Notes |
| --- | --- | --- |
| status | string | pending, ready, failed, partial |
| path | string | `incidents/{token}/audio.m4a` |
| durationSec | number | 0 to 30 |
| sizeBytes | number | maximum 2097152 |
| uploadedAt | timestamp | server time |

Subcollection: `incidents/{token}/pings`

| Field | Type | Required |
| --- | --- | --- |
| location | geopoint | yes |
| accuracyMeters | number | yes |
| at | timestamp | yes |
| atClient | timestamp | yes |
| expiresAt | timestamp | yes |

Indexes:
- Single field TTL indexes are configured in the Firebase console or CLI.
- No composite index is required for the MVP.
- The contact page orders pings by `at` ascending, which is a single field order.

Document size budget:
- Incident document stays below 8 KB.
- Pings are separate documents, so the 1 MB limit is not a concern.

## 29. Security rules

29.1 Firestore
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }
    function ownsIncident(token) {
      return signedIn()
        && get(/databases/$(database)/documents/incidents/$(token)).data.ownerUid == request.auth.uid;
    }

    match /incidents/{token} {
      allow get: if true;
      allow list: if false;
      allow create: if signedIn()
        && request.resource.data.ownerUid == request.auth.uid
        && request.resource.data.schemaVersion == 1
        && request.resource.data.status == 'active'
        && request.resource.data.expiresAt is timestamp
        && request.resource.data.expiresAt > request.time;
      allow update: if signedIn()
        && resource.data.ownerUid == request.auth.uid
        && request.resource.data.ownerUid == resource.data.ownerUid
        && request.resource.data.schemaVersion == resource.data.schemaVersion
        && request.time < resource.data.expiresAt;
      allow delete: if signedIn()
        && resource.data.ownerUid == request.auth.uid;

      match /pings/{pingId} {
        allow get, list: if true;
        allow create: if signedIn()
          && ownsIncident(token)
          && request.time < request.resource.data.expiresAt;
        allow update, delete: if false;
      }
    }
  }
}
```

Notes:
- Public `get` on a known token is the sharing mechanism. Public `list` is denied so the collection cannot be enumerated.
- `get()` in rules counts as a document read and adds cost per write. Accept for the MVP.
- Updates after expiry are denied. TTL deletion handles cleanup.
- Pings are readable by token. They contain no PII.
- There is no private subcollection. Contact data stays on the device.

29.2 Storage
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /incidents/{token}/audio.m4a {
      allow read: if true;
      allow create, update: if request.auth != null
        && request.resource.size < 2 * 1024 * 1024
        && request.resource.contentType == 'audio/mp4';
      allow delete: if false;
    }
  }
}
```

Notes:
- Storage rules cannot read Firestore. Any authenticated user who knows the token could overwrite the audio. Tokens are 192-bit secrets, and the window is 24 hours. This is accepted for the MVP and documented in the threat model.
- Lifecycle deletion handles expiry.
- A Cloud Function with signed uploads is the post-MVP hardening step.

29.3 Auth
- Anonymous auth is enabled.
- The UID is stored in secure storage.
- If the anonymous user is lost, new incidents are still created under a new UID. Old incidents are not recoverable by the app, but they expire.
- No email, phone, or social login.

## 30. Firebase configuration

30.1 Project
- Project id placeholder: `quiet-tally`.
- Hosting domain placeholder: `quiet-tally.web.app`.
- Custom domain can replace the hosting domain later. The SMS template and the app config read the same constant.
- Firestore location: choose the region closest to the primary user. Record it.
- Storage bucket: default.

30.2 Services
- Firestore in native mode.
- Storage.
- Hosting.
- Anonymous Auth.
- No Functions in the MVP.
- No Analytics, no Crashlytics, no Performance Monitoring, no Remote Config.

30.3 Local development
- Emulators for Firestore, Storage, and Auth.
- Android emulator connects to `10.0.2.2`.
- `--dart-define=USE_EMULATOR=true` selects emulator hosts.
- Seed script creates an anonymous user and one incident for page testing.

30.4 Deploy
- `firebase deploy --only firestore:rules,firestore:indexes,storage,hosting`.
- TTL policies are configured with the Firebase console or `gcloud firestore fields ttls update`.
- Storage lifecycle is configured with `gsutil lifecycle set`.

## 31. Android manifest

Required entries, expressed as requirements rather than a full file:
- Application label `Calculator`.
- Application id `com.tally.calculator`.
- `android:allowBackup="false"`.
- `android:fullBackupContent="false"`.
- `android:dataExtractionRules` points to a file that disables cloud and device transfer.
- Main activity exported, single task, exclude from recents, portrait and landscape allowed.
- FGS service with `foregroundServiceType="microphone|location"`.
- Permissions listed in section 12.
- Notification channel created at runtime.
- `usesCleartextTraffic="false"`.
- No `android:debuggable` in release.
- No `android:usesCleartextTraffic` override for localhost in release.
- ProGuard and R8 enabled for release.
- Signing config from a local keystore that is never committed.

## 32. Native SMS bridge

32.1 Channel
- Channel name: `dev.nightjar/sms`.
- Dart wrapper: `SmsSender`.

32.2 Methods
`sendAlerts`
Input:
```
{
  "phones": ["+65...", "+65...", "+65..."],
  "message": "Alert from ...",
  "token": "public-token"
}
```
Output:
```
{
  "results": [
    { "status": "sent" },
    { "status": "failed", "reason": "generic_failure" },
    { "status": "permission_denied" }
  ]
}
```

32.3 Behavior
- Check `SEND_SMS` at call time. Return `permission_denied` if missing.
- Use `SmsManager.getDefault()`.
- Use `divideMessage` and `sendMultipartTextMessage`.
- Register sent and delivered PendingIntents. `sent` is returned when the sent intent fires. Do not wait for delivery.
- Timeout after 20 seconds and return `failed` with reason `timeout`.
- Catch `SecurityException`, `IllegalArgumentException`, and `NullPointerException` and return a structured failure.
- Never log phone numbers or message bodies.
- Do not read the SMS database.
- Do not request the default SMS role.

32.4 Permissions
- `SEND_SMS` only. No `READ_SMS`, no `RECEIVE_SMS`.

## 33. Foreground service

33.1 Configuration
- Use `flutter_foreground_task`.
- Service id: 2107.
- Notification channel: `calculator_service`.
- Notification title: `Calculator`.
- Notification text: `Active`.
- Importance: low. No sound, no vibration, no badge.
- `foregroundServiceType`: microphone and location.
- `autoRunOnBoot`: false.
- `stopWithTask`: false.
- `allowWakeLock`: true.
- `allowWifiLock`: false.

33.2 Lifecycle
- Start on trigger, after the debounce.
- Stop on cancel, or when the location window ends and the audio upload has finished or failed.
- Hard cap: 20 minutes. At the cap, stop location and recording if still running, mark the incident `ended`, and stop the service.
- If the service fails to start, mark the incident `error`, clean up, and return to idle. The user sees no message.

33.3 Isolate model
- The MVP runs recording and location in the main isolate and uses the FGS to keep the process alive.
- The service callback performs no work. This is a deliberate simplification.
- Risk: some devices may stop the main isolate even with an FGS. Phase 4 includes a background recording test. If it fails, replace recording with a native Kotlin `MediaRecorder` service. The Dart interface stays the same.

33.4 Notification tap
- Tapping the notification opens the calculator. It does not open setup or show alert details.
- The pending intent has no extras that reveal an alert.

## 34. Error matrix

| Condition | Behavior | User sees in setup | Contact page |
| --- | --- | --- | --- |
| Microphone permission denied | Continue without audio, mark failed | Amber row, test reports failure | `Audio unavailable` |
| Recorder start failure | Continue, mark failed | Amber row | `Audio unavailable` |
| Recording interrupted by call | Stop, keep partial if valid | No live signal | `Audio partial` if valid, otherwise unavailable |
| Location permission denied | Send SMS with page link only | Amber row | `Location unavailable` |
| First fix timeout | Send SMS without coordinates | Amber row | `Location unavailable` then updates if a fix arrives |
| Background location denied | Updates may stop when backgrounded | Amber row | Stale location warning |
| SMS permission denied | Create incident, no SMS | Red row, test reports failure | Page works if the link is shared |
| No SIM or airplane mode | All sends fail | Test reports failure | Page works if the link is shared |
| No network | Firestore and Storage writes queued | Test reports failure | Page unavailable until upload |
| Auth failure | Queue incident, retry on next open | Red row | Page unavailable until upload |
| Firestore rule rejection | Retry 3 times, then mark error | Red row | Page unavailable |
| Storage quota or upload failure | Mark audio failed, keep location | Amber row | `Audio unavailable` |
| App killed during recording | FGS should prevent; if killed, partial file may be corrupt | None | `Audio unavailable` |
| Token collision | Regenerate | None | None |
| Clock skew | Use server timestamps for expiry; show approximate times | None | Times may be approximate |
| Incident expired | Treat as ended | None | `This alert does not exist or has expired` |
| Page token wrong | Same as expired | None | `This alert does not exist or has expired` |

## 35. Privacy

- No analytics, no advertising id, no crash reporting, no third-party SDKs beyond Firebase core services used for storage and sync.
- Firebase SDKs may collect operational metadata under Google's terms. This is disclosed in the privacy note.
- Contact names and numbers never leave the device.
- Incident documents contain location and audio only for 24 hours.
- Audio is not transcribed or analyzed.
- The contact page is readable by anyone with the link.
- The app does not read the address book, SMS inbox, call log, photos, or files.
- The app does not request overlay or accessibility permissions.
- Uninstall removes local settings and the queue. Server data expires on its own.
- The owner may delete an incident from the app? Not in the MVP. Cancelling ends it but does not delete it. Add `Delete this alert` in setup? No, it would create a history surface. Keep it simple: data expires.

## 36. Threat model

36.1 Adversaries
- A partner or household member with brief physical access to the unlocked phone.
- A partner who monitors notifications, recent apps, battery usage, or installed apps.
- A person who receives or finds the SMS link.
- A network observer.
- A determined adversary with spyware, device admin, root, or forensic tools.

36.2 Assets
- The fact that a safety app exists on the phone.
- The PIN.
- Contact names and numbers.
- Location during an alert.
- Audio during an alert.
- The token.

36.3 Mitigations
- Calculator cover with a working calculator.
- No onboarding or safety terms on the visible surface.
- PIN gate for setup, rate limited.
- Contacts and PIN in Keystore-backed secure storage.
- No contact PII server-side.
- 192-bit token capability.
- 24 hour expiry.
- No in-app history.
- Low-importance notification with neutral text.
- No sound, no vibration, no badge on alert.
- `excludeFromRecents`.
- Backups disabled.

36.4 Known gaps
- Android shows a foreground service notification and a microphone indicator.
- Android Settings shows the app, its permissions, and its battery use.
- Notification history may retain the neutral notification.
- The recipient phone shows the SMS and the link.
- A person with the token can view location and audio for 24 hours.
- A rooted or compromised device defeats local protections.
- The app cannot detect that the abuser is watching.
- The app cannot guarantee service survival against OEM battery managers.
- SMS can be read by the carrier and by anyone with the recipient phone.
- Audio may capture the abuser and may create legal risk for the owner.
- Firebase administrators can access data.
- There is no duress PIN. A PIN entered under duress opens setup, not a silent alert. This is a known gap for the MVP.

36.5 Out of scope threats
- Spyware and stalkerware on the device.
- Compromised operating system.
- Forensic extraction of the device.
- Physical coercion of the owner.
- Attacks on Firebase infrastructure.

## 37. Performance budgets

- Cold start to interactive calculator: 1.5 seconds on a mid-range Android device.
- Key press to display update: under 16 ms.
- Trigger to FGS start: under 500 ms target, 1500 ms maximum.
- Trigger to incident write: under 2 seconds with network.
- Trigger to SMS: under 15 seconds.
- Trigger to audio ready on page: under 40 seconds.
- Memory during an alert: under 150 MB.
- Release APK size: under 35 MB.
- Battery: 15 minutes of high-accuracy location plus 30 seconds of audio must not exceed 5 percent on a 4000 mAh device in a test.
- Contact page first contentful paint on 4G: under 2 seconds.
- Contact page location update visible: under 3 seconds after the write.

## 38. Logging and observability

- Debug builds use a `NIGHTJAR` log tag and may log state transitions without PII.
- Release builds log nothing containing a token, location, phone number, contact name, PIN, hash, or file path.
- No remote logging, no crash reporting, no analytics.
- Store no server-side logs beyond Firebase's own operational logs.
- Test alert results are stored locally only as a timestamp and a pass or fail summary. Clear on reset.

## 39. Testing strategy

39.1 Unit tests
- Calculator engine: at least 60 cases covering digits, decimals, operators, repeat equals, divide by zero, percent, sign, overflow, and rounding.
- PIN hashing: deterministic with a fixed salt, verification, rejection rules, constant-time comparison wrapper.
- Trigger detector: PIN match, digit count mismatch, triple-tap timing boundaries, debounce, cooldown.
- Message composer: length under 300, ASCII only, no forbidden words, coordinate formatting, missing location variant.
- Token generator: length, alphabet, uniqueness over 100,000 samples.
- Expiry: 24 hours for real incidents, 1 hour for tests.
- Contact validation: E.164, duplicates, name length.

39.2 Widget tests
- Calculator at 320, 360, and 420dp widths.
- Calculator at 200 percent text scale.
- Long press opens the PIN gate at 2 seconds and not before.
- Triple tap opens no setup screen.
- Setup validation states.
- Permission rows render granted, denied, and not requested.
- Contact sheet validation.
- Test alert progress and summary.

39.3 Integration tests
- Run against Firebase emulators.
- Trigger writes the incident, pings, and audio.
- Cancel marks ended and stops updates.
- Expired writes are denied.
- Rules tests: unauthorized create, update, delete, public get, list denied, pings write authorization.
- Storage rules: type and size enforcement.
- Contact page with a seeded token: active, ended, expired, offline, audio missing, location missing.

39.4 Manual device tests
- Physical device with an active SIM for SMS.
- Background recording for the full 30 seconds.
- Recents screen, notification shade, notification history, app info, battery usage.
- Permission revoke while idle.
- Airplane mode trigger.
- Battery saver trigger.
- Incoming call during recording.
- TalkBack walkthrough.
- Cold start timing.
- OEM battery manager behavior on at least one non-stock device if available.

39.5 Test data rules
- Never use real contact numbers in tests. Use reserved ranges such as `+1 555 0100`.
- Never use real location data. Use fixed coordinates.
- Never commit a Firebase service account key.
- Emulator data is disposable.

## 40. Acceptance criteria

Each criterion has an id and a verification method.

AC-01 Calculator opens directly with no splash or onboarding. Verified by cold launch on a physical device.
AC-02 Calculator computes correctly for 60 engine cases and 10 manual cases. Verified by tests and click-through.
AC-03 AC long press opens the PIN gate at 2 seconds. Verified by manual and widget test.
AC-04 A correct PIN opens setup. Wrong PIN shows an error and increments the lockout counter. Verified by test.
AC-05 Setup requires three valid, unique phone numbers. Verified by widget test and manual.
AC-06 Setup can complete with permissions denied, and shows amber warnings. Verified by manual.
AC-07 The test alert sends to three contacts and reports per-contact status. Verified on a physical device.
AC-08 PIN trigger starts the incident with no visual confirmation. Verified by screen recording.
AC-09 Triple-tap trigger starts the incident. Verified by screen recording.
AC-10 A second PIN trigger while active cancels the incident and marks it ended. Verified by test and manual.
AC-11 Recording reaches 30 seconds while the app is backgrounded. Verified on a physical device.
AC-12 The first SMS arrives with coordinates and a page link within 15 seconds when location is available. Verified on a physical device.
AC-13 The contact page shows the live location and updates every 10 seconds. Verified with two devices.
AC-14 The contact page plays the 30 second audio. Verified in Chrome and Safari mobile.
AC-15 No in-app incident history exists. Verified by inspection and manual.
AC-16 The recent apps screen does not show the app. Verified by manual.
AC-17 The notification contains no safety terms. Verified by manual.
AC-18 Incident and ping documents are deleted by TTL after expiry. Verified in a staging project with a short TTL.
AC-19 Storage audio is deleted by lifecycle after expiry. Verified in a staging project.
AC-20 Contact names and numbers are absent from all network payloads. Verified by inspecting Firestore documents and Storage metadata.
AC-21 The contact page shows the loading, ended, expired, offline, and audio-missing states. Verified with seeded data.
AC-22 All interactive elements work, with no dead controls. Verified by click-through and recorded evidence.
AC-23 Contrast passes AA, targets meet 44dp, and the page is keyboard operable. Verified by contrast tool and keyboard walkthrough.
AC-24 The app passes the antislop Delivery Gate with zero FAIL lines.
AC-25 The release APK builds and installs on Android 10 through 15. Verified by install on at least two API levels.

## 41. Build and release

41.1 Toolchain
- Flutter 3.29 or newer.
- Dart 3.7 or newer.
- Android SDK 35, minimum SDK 29, target SDK 35.
- Java 17.
- Gradle from the Flutter template, with dependency locking reviewed.

41.2 Flavors
- `dev`: emulator hosts, debug logging, no signing.
- `prod`: release signing, Firebase production project, no logging.

41.3 Commands
- `flutter analyze`
- `flutter test`
- `flutter build apk --release --flavor prod`
- `flutter build appbundle --release --flavor prod` for future store use.

41.4 Signing
- Keystore stored outside the repository.
- `key.properties` ignored by git.
- The release build fails if signing is missing, rather than producing an unsigned APK.

41.5 Release checklist
- Version number incremented.
- Privacy note reviewed.
- Platform limitations section of README reviewed.
- No debug logs.
- No emulator hosts in prod.
- No test numbers in the build.
- APK hash published with the distribution.

## 42. Verification checklist

Run every item and record evidence in `docs/VERIFICATION.md`.

42.1 Build
- `flutter analyze` clean.
- `flutter test` green.
- Rules tests green.
- Release APK builds and installs.

42.2 Calculator
- Cold start time recorded.
- All keys work, including AC, sign, percent, decimal, operators, equals.
- Divide by zero shows Error.
- Display never overflows at 320dp and at 200 percent text scale.
- No sound is produced.

42.3 Setup
- Long press timing.
- PIN creation rules.
- PIN change with current PIN.
- Lockout after five failures.
- Contact validation and removal.
- Permission rows reflect the real state.
- Test alert sends real SMS and reports results.
- Delete all settings works.

42.4 Trigger
- PIN trigger.
- Triple-tap trigger.
- Cancel before SMS.
- Cancel after SMS.
- Repeat trigger cooldown.
- No visual confirmation.
- Haptic pulse.

42.5 Incident
- Firestore document fields.
- Pings ordered by time.
- Audio file metadata and size.
- Local file deletion after upload.
- Queue retry after app restart.
- 1 hour expiry behavior.

42.6 Contact page
- Active state.
- Live updates.
- Trail polyline.
- Audio playback.
- Ended state.
- Expired state.
- Offline state.
- 320px layout.
- Keyboard and TalkBack.
- CSP causes no console errors.
- No token in the console.
- No index tags present.

42.7 Stealth
- Launcher label and icon.
- Recents screen.
- Notification shade and history.
- App info and permissions.
- Battery usage entry.
- No safety strings in release resources.

42.8 Privacy
- No contact PII in Firestore.
- No token or location in release logs.
- No analytics packages in the dependency tree.
- Backups disabled.

42.9 antislop
- Hard Gate all no.
- Purpose-Gate reasons present in `DESIGN.md`.
- Liveliness dials held.
- UI, layoutmobile, and code checklists all yes.
- After-mode audit written and approved items fixed.
- Delivery Gate report attached with evidence.

## 43. Decisions and open questions

Decisions already made:
- D-01: Flutter for the app, Android only.
- D-02: Calculator cover first. Weather is out of scope.
- D-03: Project folder and codename Nightjar. Visible name Calculator.
- D-04: Application id `com.tally.calculator`.
- D-05: Exactly three contacts.
- D-06: Contacts stored on device only, no private Firestore subcollection.
- D-07: Token as Firestore document id and page path.
- D-08: SMS via native `SmsManager`, no third-party SMS provider.
- D-09: OpenStreetMap and Leaflet for the contact map.
- D-10: Light theme only.
- D-11: No analytics or crash reporting.
- D-12: TTL cleanup, no Functions in the MVP.
- D-13: Contact page action is `tel:112` by default, configurable.
- D-14: Triple-tap trigger enabled by default, configurable.
- D-15: No duress PIN in the MVP.
- D-16: No app-side incident deletion in the MVP.

Open questions that need an answer before release:
- Q-01: Final Firebase project id and hosting domain. Placeholder `quiet-tally`.
- Q-02: Owner display name policy. Default `a contact`.
- Q-03: Emergency number per region. Default 112.
- Q-04: Whether to add a duress PIN after the MVP.
- Q-05: Whether to add a contact-side PWA for push notifications after the MVP.
- Q-06: Legal review for audio recording in the target jurisdiction.
- Q-07: Whether OEM-specific battery instructions are needed in setup for the target devices.

## 44. File tree

```
nightjar/
  AGENTS.md
  DESIGN.md
  GOAL.md
  SPEC.md
  README.md
  docs/
    SETUP.md
    THREAT-MODEL.md
    VERIFICATION.md
  firebase.json
  firestore.rules
  firestore.indexes.json
  storage.rules
  storage.lifecycle.json
  web/
    contact/
      index.html
      app.js
      styles.css
      config.js
      assets/
        plex-sans.woff2
        plex-mono.woff2
      robots.txt
  app/
    pubspec.yaml
    lib/
      main.dart
      app.dart
      core/
        constants.dart
        result.dart
        time.dart
      features/
        calculator/
          calculator_engine.dart
          calculator_screen.dart
          keypad.dart
        setup/
          pin_gate_screen.dart
          setup_status_screen.dart
          contacts_screen.dart
          permissions_screen.dart
          test_alert_screen.dart
          about_screen.dart
        trigger/
          trigger_controller.dart
          trigger_detector.dart
          pin_hasher.dart
        incident/
          incident.dart
          incident_repository.dart
          audio_recorder.dart
          location_tracker.dart
          sms_sender.dart
          upload_queue.dart
      services/
        firebase_bootstrap.dart
        secure_store.dart
        foreground_service.dart
      theme/
        palette.dart
        typography.dart
        theme.dart
    android/
      app/
        src/main/AndroidManifest.xml
        src/main/kotlin/com/tally/calculator/MainActivity.kt
        src/main/kotlin/com/tally/calculator/SmsSender.kt
        src/main/res/
          mipmap-*/ic_launcher.*
          values/strings.xml
          xml/backup_rules.xml
          xml/data_extraction_rules.xml
    test/
      calculator_engine_test.dart
      pin_hasher_test.dart
      trigger_detector_test.dart
      message_composer_test.dart
      token_test.dart
      widget/
        calculator_screen_test.dart
        pin_gate_test.dart
        contacts_test.dart
    integration_test/
      trigger_flow_test.dart
  rules-tests/
    package.json
    firestore.test.js
    storage.test.js
  anti-slop/
    audit-001-2026-10-17.md
```

## 45. Glossary

- Alert: the event experienced by the owner. Same as incident.
- Contact page: the public web page at `/i/<token>`.
- Cover: the calculator surface.
- FGS: Android foreground service.
- Incident: the Firestore representation of one alert.
- Owner: the person who installed and configured the app.
- Ping: one location sample in the subcollection.
- Setup: the hidden configuration area.
- Token: the 192-bit capability that identifies an incident.
- Trigger: the gesture that starts an alert.
- TTL: Firestore Time to Live policy.
