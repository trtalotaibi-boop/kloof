# KLOOF Booking Flow Validation — 2026-08-08

## Scope

This document records the booking-flow behavior that was manually verified on the iOS app against Firebase project `kloof-1cfcd` on 2026-08-08.

This is a validation record, not a production-readiness declaration.

## Verified end-to-end flow

The following transitions were manually verified from the customer and barber interfaces:

- Booking creation writes a `bookings` document with `status: pending`.
- Pending bookings appear in the customer's **My Bookings** screen.
- Pending bookings appear in the barber dashboard.
- Barber rejection changes the booking to `rejected` and the customer sees the rejected state.
- A rejected booking releases its time slot so that the slot becomes available again.
- Barber acceptance changes the booking to `accepted` and the customer sees the accepted state.
- An accepted booking keeps its time slot unavailable to prevent a second booking through the current UI flow.
- Barber completion changes the booking to `completed` and the customer sees the completed state.

## Firestore composite indexes required by the verified queries

Customer booking history query:

- Collection: `bookings`
- `customerId` — Ascending
- `createdAt` — Descending
- Query scope: Collection

Barber booking list query:

- Collection: `bookings`
- `barberId` — Ascending
- `createdAt` — Descending
- Query scope: Collection

These indexes were enabled manually in the Firebase console during validation. The repository-level definition is stored in `firestore.indexes.json` so the required indexes are documented and can later be managed through Firebase CLI deployment.

## Known follow-up items

### 1. Time display consistency

`bookings` currently stores both `selectedTime` and `selectedTimeMinutes`. The numeric field should be treated as the canonical value when rendering time because localized `selectedTime` strings can differ between locales and can produce AM/PM display inconsistencies.

Recommended low-risk implementation:

- Prefer `selectedTimeMinutes` for display formatting.
- Fall back to `selectedTime` only for older documents that do not contain the numeric field.
- Do not migrate existing booking documents until the display-only change is independently verified.

### 2. Booking action visibility

The barber dashboard currently renders Accept, Reject, and Complete actions for every booking status. The UI should only expose actions that are valid for the current state.

Recommended UI policy:

- `pending`: Accept, Reject
- `accepted`: Complete
- `rejected`: no state-change actions
- `completed`: no state-change actions

This should be implemented as a UI safety improvement first. Server-side enforcement and transactional state transitions should be handled separately because they have a larger behavioral/security impact.

### 3. Concurrency / true double-booking protection

The current booking creation path checks existing bookings before adding the new document. This protects normal UI usage but is not an atomic reservation guarantee if two clients submit the same slot at nearly the same time.

Do not treat this as solved by the manual test. A transaction, deterministic slot document, or server-side reservation mechanism should be designed before production launch.

### 4. Firestore security rules

The booking flow was functionally validated, but this validation does not prove that Firestore Security Rules prevent unauthorized status changes or cross-user reads/writes. Rules require a separate review and emulator/security test pass.

## Git checkpoint and rollback

The validated code checkpoint is tagged:

`kloof-booking-flow-tested-2026-08-08`

The tag points to commit:

`48560ac`

Use the tag as the known-good Git reference for the manually verified booking flow. Note that Git tags do not capture Firebase Console state; Firestore indexes must also be managed from repository configuration for reproducible environments.

## Local generated platform changes

During iOS execution, Flutter/Xcode regenerated platform/dependency files such as `ios/Podfile.lock`, Xcode project metadata, SwiftPM `Package.resolved`, and macOS generated/plugin files. Those changes were intentionally excluded from the validated code checkpoint because they were unrelated to the booking business logic.

Two local Git stashes were created during the manual session as recovery points. They are local developer artifacts and are not part of this repository documentation or release state.
