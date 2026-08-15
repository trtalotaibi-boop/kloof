# KLOOF push notifications

This directory contains the trusted sender for booking push notifications. It is
not deployed automatically.

Before deployment:

1. Enable Cloud Messaging and upload the APNs authentication key in Firebase.
2. Review and deploy Firestore rules that let a signed-in user manage only
   `users/{uid}/pushTokens/{tokenId}` under their own UID.
3. Test the functions and token rules against a staging Firebase project.
4. Deploy only the two named functions after staging verification.

The Flutter app never sends push messages and contains no server credentials.
