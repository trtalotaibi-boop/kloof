# MVP Firebase security gap

## Current repository state

`firebase.json` only contains Flutter app registration. The repository has no
versioned Firestore rules, Storage rules, Emulator configuration, or rules test
harness. Production rules were not inspected or changed during the MVP client
fixes.

## Client-side guarantees added

- Barber profiles use the authenticated Firebase Auth UID as the canonical
  `barbers/{uid}` document ID. A matching legacy name-based document is copied
  forward and retained for rollback/read compatibility.
- New bookings reserve a deterministic `bookingSlots/{uid--YYYYMMDD--HHmm}`
  document and create the booking in the same Firestore transaction.
- Slot start is stored as a Firestore `Timestamp` (`slotStart`) and the display
  label remains only for UI/backward compatibility.
- Rejecting a new-format booking releases its matching slot lock in a
  transaction.

These checks improve consistency but are not an authorization boundary. A
modified client can still attempt arbitrary writes if production rules permit
them.

## Decision required before adding rules

Confirm the deployed collection contract and authorization policy for
`users`, `barbers`, `bookings`, `bookingSlots`, and `notifications`, then add
versioned rules plus Emulator tests in one reviewed change. In particular,
decide whether customers may create notifications directly and which booking
status transitions barbers may perform. Rules must validate that the barber
profile owner is `request.auth.uid`, booking customers match the caller, and a
slot lock and booking are mutually consistent.
