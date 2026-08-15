# iOS push setup for KLOOF

The Flutter receiver and the trusted Cloud Functions sender are present locally,
but push delivery is not active until the following manual setup is completed.

## Apple Developer and Xcode

1. Enable the **Push Notifications** capability for the App ID
   `com.kloof.booking` in Apple Developer.
2. Create or reuse an APNs authentication key with push access. Do not add the
   `.p8` file to this repository.
3. Refresh the development and distribution provisioning profiles after the
   capability is enabled.
4. Confirm that Xcode Signing & Capabilities shows Push Notifications for the
   Runner target.

## Firebase Console

1. Open Project Settings → Cloud Messaging → Apple app.
2. Upload the APNs authentication key, Key ID, and Apple Team ID.
3. Confirm that the Firebase iOS app bundle ID is `com.kloof.booking`.

## Firestore authorization

Before allowing device token writes, add and emulator-test a rule equivalent to
the following within the project's reviewed ruleset:

```text
match /users/{uid}/pushTokens/{tokenId} {
  allow read: if false;
  allow create, update, delete: if request.auth != null
                                && request.auth.uid == uid;
}
```

Do not deploy this fragment separately without integrating it into the complete
ruleset and testing the result against staging.

## Trusted sender

1. Install dependencies in `functions/`.
2. Run local syntax and Emulator checks.
3. Test new-booking, accepted, and rejected events in staging.
4. Deploy the two named functions only after staging approval.

No server key, APNs key, or Firebase Admin credential belongs in the Flutter
application or this repository.
