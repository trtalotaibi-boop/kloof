# KLOOF Booking Flow Validation — 2026-08-08

## Scope

This document records the booking-flow behavior that was manually verified on the iOS app against Firebase project `kloof-1cfcd` on 2026-08-08.

This is a validation record, not a production-readiness declaration.

## Verified end-to-end flow

The following transitions were manually verified from the customer and barber interfaces before the later hardening commits on this branch:

- Booking creation writes a `bookings` document with `status: pending`.
- Pending bookings appear in the customer's **My Bookings** screen.
- Pending bookings appear in the barber dashboard.
- Barber rejection changes the booking to `rejected` and the customer sees the rejected state.
- A rejected booking releases its time slot so that the slot becomes available again.
- Barber acceptance changes the booking to `accepted` and the customer sees the accepted state.
- An accepted booking keeps its time slot unavailable to prevent a second booking through the current UI flow.
- Barber completion changes the booking to `completed` and the customer sees the completed state.
- An afternoon booking at `5:00 PM` was manually checked end-to-end before the hardening commits: selection, confirmation, and My Bookings showed the same afternoon time, and the slot disappeared after booking.

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

## Hardening implemented on the isolated branch

The branch `chore/booking-safety-docs-2026-08-08` now contains narrow follow-up changes that have **not** been merged into the protected base branch:

### 1. Canonical booking-time display

Both customer **My Bookings** and **Barber Dashboard** now prefer numeric `selectedTimeMinutes` when rendering booking time and use the active Material locale for display.

Backward compatibility is preserved: older documents without a valid `selectedTimeMinutes` value fall back to their stored `selectedTime` string.

No booking write semantics or existing Firestore documents were migrated.

### 2. Booking action visibility

The barber dashboard now exposes only state-appropriate UI actions:

- `pending`: Accept, Reject
- `accepted`: Complete
- `rejected`: no state-change actions
- `completed`: no state-change actions

This is a UI safety improvement only. It is not server-side transition enforcement.

### 3. Repository index definition

`firestore.indexes.json` records the two composite indexes used by the verified customer and barber booking queries.

## Required checks still pending before merge

The following items are intentionally **not** marked complete and are a merge gate:

1. Device regression check of barber action visibility:
   - pending -> Accept + Reject only
   - accepted -> Complete only
   - rejected -> no actions
   - completed -> no actions
2. Device check of Barber Dashboard time rendering from `selectedTimeMinutes`.
3. Morning-time display check after the canonical-minutes changes.
4. Legacy booking display check using a booking document without `selectedTimeMinutes`.
5. Fresh Flutter static analysis/tests for the latest branch head. No GitHub CI/status evidence was available at the time this record was updated.

Until these checks are evidenced, the PR must remain **Draft** and must not be merged.

## Known follow-up items outside this branch

### 1. Concurrency / true double-booking protection

The current booking creation path checks existing bookings before adding the new document. This protects normal UI usage but is not an atomic reservation guarantee if two clients submit the same slot at nearly the same time.

Do not treat this as solved by the manual test. A transaction, deterministic slot document, or server-side reservation mechanism should be designed before production launch.

### 2. Firestore security rules

The booking flow was functionally validated, but this validation does not prove that Firestore Security Rules prevent unauthorized status changes or cross-user reads/writes. Rules require a separate review and emulator/security test pass.

## Git checkpoint and rollback

The known-good manually verified checkpoint is tagged:

`kloof-booking-flow-tested-2026-08-08`

The tag points to commit:

`48560ac`

Use that tag as the rollback reference if the isolated hardening branch must be abandoned. The current hardening work is six commits ahead of that checkpoint and remains isolated from the base branch.

Git tags do not capture Firebase Console state; Firestore indexes must also be managed from repository configuration for reproducible environments.

## Files affected by the isolated hardening branch

Compared with the known-good checkpoint, the branch changes only:

- `docs/booking-flow-validation-2026-08-08.md`
- `firestore.indexes.json`
- `lib/screens/barber_dashboard_screen.dart`
- `lib/screens/my_bookings_screen.dart`

## Local generated platform changes

During iOS execution, Flutter/Xcode regenerated platform/dependency files such as `ios/Podfile.lock`, Xcode project metadata, SwiftPM `Package.resolved`, and macOS generated/plugin files. Those changes were intentionally excluded from the validated code checkpoint because they were unrelated to the booking business logic.

Two local Git stashes were created during the manual session as recovery points. They are local developer artifacts and are not part of this repository documentation or release state.
