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

The normal UI flow above was verified end-to-end. This does **not** prove atomic protection against two concurrent clients attempting to reserve the same slot.

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

## Booking hardening implemented on the safety branch

### 1. Time display consistency

`bookings` stores both `selectedTime` and `selectedTimeMinutes`. The numeric field is now treated as the preferred canonical display source in both customer **My Bookings** and the barber dashboard.

Current implementation:

- Prefer `selectedTimeMinutes` when it is present and valid.
- Format the numeric value with `MaterialLocalizations.formatTimeOfDay` for the active locale.
- Fall back to the stored `selectedTime` value for older documents.
- No booking data migration was performed.
- No booking-write or availability logic was changed.

Validation evidence so far:

- A new afternoon booking at `5:00 PM` was manually verified on the customer side: slot selection, confirmation, and My Bookings all showed the same afternoon time.
- Barber-side canonical-minutes rendering was implemented in commit `f785f23` but still needs a physical-device check.
- A morning booking still needs an explicit post-change display check.
- A legacy booking without `selectedTimeMinutes` still needs an explicit fallback check.

### 2. Booking action visibility

The barber dashboard now exposes only the state-change actions valid for the current booking state:

- `pending`: Accept, Reject
- `accepted`: Complete
- `rejected`: no state-change actions
- `completed`: no state-change actions

This UI-only safety change was implemented in commit `b85acff`. It does not modify `_updateBookingStatus`, Firestore write behavior, booking creation, or slot availability logic.

A physical-device regression check of all four states is still required before this item is considered fully validated.

## Remaining production-readiness items

### 1. Concurrency / true double-booking protection

The current booking creation path checks existing bookings before adding the new document. This protects normal UI usage but is not an atomic reservation guarantee if two clients submit the same slot at nearly the same time.

Do not treat this as solved by the manual test. A transaction, deterministic slot document, or server-side reservation mechanism should be designed before production launch.

### 2. Firestore security rules and server-side state transitions

The booking flow was functionally validated, but this validation does not prove that Firestore Security Rules prevent unauthorized status changes or cross-user reads/writes.

The current barber action restrictions are UI-only. Rules and/or trusted server-side logic should separately enforce who may update a booking and which status transitions are legal.

### 3. Fresh automated validation

There is currently no CI status or pull-request workflow run proving fresh `flutter analyze` / Flutter tests for the latest branch head. Those checks must be run before the draft PR is approved or merged.

## Git checkpoint and rollback

The original manually validated code checkpoint is tagged:

`kloof-booking-flow-tested-2026-08-08`

The tag points to commit:

`48560ac`

Use the tag as the known-good Git reference for the manually verified booking flow. Note that Git tags do not capture Firebase Console state; Firestore indexes must also be managed from repository configuration for reproducible environments.

The booking hardening work remains isolated on branch:

`chore/booking-safety-docs-2026-08-08`

Because the hardening commits are separate, an individual change can be reverted without discarding the original known-good checkpoint.

## Local generated platform changes

During iOS execution, Flutter/Xcode regenerated platform/dependency files such as `ios/Podfile.lock`, Xcode project metadata, SwiftPM `Package.resolved`, and macOS generated/plugin files. Those changes were intentionally excluded from the validated booking commits because they were unrelated to the booking business logic.

Three local Git stashes were created during the session as recovery points for generated platform changes. They are local developer artifacts and are not part of this repository or release state.
