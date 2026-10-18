# Mizzy's Bistro POS

An independent Flutter restaurant POS starter. This is a demo/test milestone, not production-ready.

## Included
- Tablet-friendly cashier and sample menu in Philippine pesos
- Cart quantity updates, dine-in/takeaway selection and totals
- Orders and Kitchen show an order only after Save is tapped
- Kitchen status changes are stored locally
- SQLite local persistence: order headers and all order lines are committed in one transaction
- Widget tests and GitHub Actions workflow for analysis, tests, and a debug APK build

## Local data and limitations
Saved orders persist on the same device across app restarts in an application-private SQLite database. This is **local storage only**: it does not synchronize with other devices and uninstalling/clearing app data may erase it. There is no remote backup yet. Use test orders only.

Tax remains zero until configured. Live payment processing, receipt-printer integration, inventory deduction, authentication/roles, remote backup and multi-device synchronization are not implemented. Do not use for live sales until those controls and recovery procedures are implemented and tested.

## Build
Install Flutter stable, Android SDK, and Java 17. The GitHub Actions workflow generates the Android platform scaffolding if missing, then runs:
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

## Safety
Never commit tokens, passwords, signing keys, `.env` files, customer records, or production database exports.
