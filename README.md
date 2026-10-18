# Mizzy's Bistro POS

An independent Flutter restaurant POS starter. This is a demo/test milestone, not production-ready.

## Included
- Tablet-friendly cashier and sample menu
- Cart quantity updates and totals
- Orders and Kitchen show orders only after Save
- Kitchen can mark tickets Ready
- Widget tests and GitHub Actions workflow for analysis, tests, and a debug APK build

## Important limitations
Orders currently stay in memory and disappear when the app process restarts. Tax is zero until configured. No live payments, receipt printing, inventory decrement, user authentication, or cloud sync is implemented. Do not use for live sales yet.

## Build
Install Flutter stable, Android SDK, and Java 17. Run `flutter create . --platforms android --org ph.mizzysbistro`, then `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --debug`.

Never commit tokens, passwords, signing keys, `.env` files, customer records, or production database exports.