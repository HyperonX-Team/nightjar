# Nightjar app

The Flutter app. Read `../README.md` first, then `../SPEC.md` for behavior and
`../docs/SETUP.md` for the owner-facing setup steps.

```
flutter analyze
flutter test
flutter build apk --release --flavor prod
```

The release build fails without `android/key.properties`, by design.
