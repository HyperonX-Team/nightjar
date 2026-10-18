# AGENTS

Project: Nightjar (covert SOS app, Android only, Flutter).

## Routing

- For UI work, read DESIGN.md for direction, then antislop.md as the filter.
- For responsive layout work, also read skills/antislop-layoutmobile/SKILL.md.
- For code comments, also read skills/antislop-code/SKILL.md.
- Core rules: antislop.md (R-01 to R-38).

## antislop

For UI, copy, people, mobile layout, or code comments work, read antislop.md (core) and then the skill for the task:

- UI / visual: skills/antislop-ui/SKILL.md
- Copy & text: skills/antislop-copywriting/SKILL.md
- People: skills/antislop-human/SKILL.md
- Mobile / responsive: skills/antislop-layoutmobile/SKILL.md
- Code comments: skills/antislop-code/SKILL.md

Mode for this project: during and after, session override.

## Commands

- flutter analyze
- flutter test
- flutter build apk --release
- firebase emulators:start --only firestore,storage
- firebase deploy --only hosting,firestore,storage

## Constraints

- No em dashes in any text (R-02).
- No fabricated claims, numbers, or testimonials (R-17, R-18, R-36).
- Every interactive element has real behavior or is removed (R-26).
- Platform limits (FGS notification, microphone indicator, no SMS deletion) are documented honestly.