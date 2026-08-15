import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../screens/barber_bookings_screen.dart';
import '../screens/my_bookings_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GlobalKey<NavigatorState>? _navigatorKey;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _registeredUid;
  String? _registeredToken;
  RemoteMessage? _pendingMessage;

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // The in-app notification center remains available if push is unavailable.
    }

    _authSubscription = _auth.authStateChanges().listen((user) async {
      try {
        await _syncTokenForUser(user);
      } catch (_) {
        // Push registration must never block authentication or app startup.
      }
      if (user != null && _pendingMessage != null) {
        final message = _pendingMessage!;
        _pendingMessage = null;
        _openMessage(message);
      }
    });
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      try {
        await _registerToken(_auth.currentUser, token);
      } catch (_) {
        // A later refresh or app launch will retry registration.
      }
    });
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );

    try {
      await _syncTokenForUser(_auth.currentUser);
    } catch (_) {
      // Keep the app usable if token storage is not configured yet.
    }
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openMessage(initialMessage);
    }
  }

  Future<void> _syncTokenForUser(User? user) async {
    if (user == null) {
      await _removeRegisteredToken();
      return;
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerToken(user, token);
    }
  }

  Future<void> _registerToken(User? user, String token) async {
    if (user == null) return;

    if (_registeredUid != null &&
        _registeredToken != null &&
        (_registeredUid != user.uid || _registeredToken != token)) {
      await _deleteToken(_registeredUid!, _registeredToken!);
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('pushTokens')
        .doc(_tokenDocumentId(token))
        .set({
          'token': token,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    _registeredUid = user.uid;
    _registeredToken = token;
  }

  Future<void> _removeRegisteredToken() async {
    final uid = _registeredUid;
    final token = _registeredToken;
    _registeredUid = null;
    _registeredToken = null;
    if (uid != null && token != null) {
      await _deleteToken(uid, token);
    }
  }

  Future<void> _deleteToken(String uid, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('pushTokens')
          .doc(_tokenDocumentId(token))
          .delete();
    } catch (_) {
      // Token cleanup is best effort; the trusted sender removes invalid tokens.
    }
  }

  String _tokenDocumentId(String token) {
    return base64Url.encode(utf8.encode(token)).replaceAll('=', '');
  }

  void _openMessage(RemoteMessage message) {
    final user = _auth.currentUser;
    if (user == null) {
      _pendingMessage = message;
      return;
    }

    final recipientId = message.data['recipientId'];
    if (recipientId != null && recipientId != user.uid) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey?.currentState;
      if (navigator == null) {
        _pendingMessage = message;
        return;
      }

      final target = message.data['target'];
      final route = target == 'barberBookings'
          ? MaterialPageRoute<void>(
              builder: (_) => const BarberBookingsScreen(),
            )
          : MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen());
      navigator.push(route);
    });
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
