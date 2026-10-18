# Threat model

Companion to SPEC.md section 36. Repeated here so the analysis travels with the
app documentation.

## Adversaries

1. A partner or household member with brief physical access to the unlocked
   phone.
2. A partner who monitors notifications, recent apps, battery usage, or
   installed apps.
3. A person who receives or finds the SMS link.
4. A network observer.
5. A determined adversary with spyware, device admin rights, root, or forensic
   tooling.

## Assets

- The fact that a safety app exists on this phone.
- The PIN.
- Contact names and numbers.
- Location during an alert.
- Audio during an alert.
- The incident token.

## Mitigations in the MVP

- A working calculator cover, with no safety terms on the visible surface.
- Setup hidden behind a 2 second press on AC and a PIN, rate limited with an
  escalating lockout stored in secure storage.
- PIN stored as PBKDF2-HMAC-SHA256, 210,000 iterations, random 16 byte salt,
  32 byte derived key, in Keystore backed encrypted storage.
- Contacts stored on the device only. No contact name or number is written to
  the server.
- A 192 bit token as the only capability for the contact page.
- 24 hour expiry on incident, ping, and audio data, enforced by Firestore TTL
  and a Storage lifecycle rule.
- No in-app incident list, no sent message log, no audio playback in the app.
- A low importance notification channel with neutral text and no sound,
  vibration, or badge.
- `excludeFromRecents`, `allowBackup=false`, and backup and transfer rules that
  exclude everything.
- Public read on a token, with listing denied so the collection cannot be
  enumerated.

## Known gaps, stated honestly

- Android shows a foreground service notification and a microphone privacy
  indicator during an alert.
- Android Settings shows the app, its permissions, and its battery use.
- Notification history may retain the neutral notification.
- The recipient phone shows the SMS and the link, and Nightjar cannot delete it.
- Anyone with the token can view location and audio for up to 24 hours.
- A rooted or compromised device defeats the local protections. A 4 digit PIN
  has 10,000 combinations and is brute forceable offline with root access.
- The app cannot detect that the abuser is watching, and it cannot guarantee
  survival against manufacturer battery managers.
- SMS is readable by the carrier and by anyone holding the recipient phone.
- Audio may capture the abuser and may create legal risk for the owner.
- Firebase administrators can access stored data.
- There is no duress PIN in the MVP. A PIN entered under duress opens setup, not
  a silent alert.
- Storage rules cannot read Firestore, so any authenticated user who knows a
  token could overwrite that incident's audio inside the 24 hour window. Tokens
  are 192 bit secrets. A Cloud Function with signed uploads is the post-MVP
  hardening step.

## Out of scope

- Spyware and stalkerware already on the device.
- A compromised operating system.
- Forensic extraction of the device.
- Physical coercion of the owner.
- Attacks on Firebase infrastructure itself.
