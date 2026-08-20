import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kloof/auth/customer_auth_policy.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

class CustomerPhoneAuthScreen extends StatefulWidget {
  const CustomerPhoneAuthScreen({super.key});

  @override
  State<CustomerPhoneAuthScreen> createState() =>
      _CustomerPhoneAuthScreenState();
}

class _CustomerPhoneAuthScreenState extends State<CustomerPhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  String? _normalizedPhone;
  bool _isRequestingCode = false;
  bool _isCompletingSignIn = false;

  bool get _isBusy => _isRequestingCode || _isCompletingSignIn;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _authError(FirebaseAuthException error, AppLocalizations l10n) {
    switch (error.code) {
      case 'invalid-phone-number':
        return l10n.phoneAuthInvalidPhone;
      case 'invalid-verification-code':
        return l10n.phoneAuthInvalidCode;
      case 'session-expired':
      case 'code-expired':
        return l10n.phoneAuthCodeExpired;
      case 'too-many-requests':
      case 'quota-exceeded':
        return l10n.authTooManyRequests;
      case 'network-request-failed':
        return l10n.authNetworkError;
      case 'operation-not-allowed':
        return l10n.authOperationNotAllowed;
      default:
        return l10n.authUnexpectedError;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestCode() async {
    if (_isBusy) return;

    final l10n = AppLocalizations.of(context);
    final normalizedPhone = normalizeSaudiMobileNumber(_phoneController.text);
    if (normalizedPhone == null) {
      _showMessage(l10n.phoneAuthInvalidPhone);
      return;
    }

    setState(() {
      _isRequestingCode = true;
      _normalizedPhone = normalizedPhone;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        verificationCompleted: _completeSignIn,
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _isRequestingCode = false);
          _showMessage(_authError(error, l10n));
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isRequestingCode = false;
          });
          _showMessage(l10n.phoneAuthCodeSent);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isRequestingCode = false;
          });
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _isRequestingCode = false);
      _showMessage(_authError(error, l10n));
    }
  }

  Future<void> _submitCode() async {
    if (_isBusy) return;

    final l10n = AppLocalizations.of(context);
    final verificationId = _verificationId;
    final smsCode = _otpController.text.trim();
    if (verificationId == null || smsCode.length != 6) {
      _showMessage(l10n.phoneAuthEnterValidCode);
      return;
    }

    final PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _completeSignIn(credential);
  }

  Future<void> _completeSignIn(PhoneAuthCredential credential) async {
    if (!mounted || _isCompletingSignIn) return;

    setState(() {
      _isRequestingCode = false;
      _isCompletingSignIn = true;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final destination = resolveCustomerSignInDestination(
        profileExists: profile.exists,
        role: profile.data()?['role']?.toString(),
      );

      if (destination == CustomerSignInDestination.blocked) {
        await FirebaseAuth.instance.signOut();
        _showMessage(l10n.phoneAuthCustomerOnly);
        return;
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      _showMessage(_authError(error, l10n));
    } on FirebaseException {
      _showMessage(l10n.phoneAuthProfileReadFailed);
    } finally {
      if (mounted) setState(() => _isCompletingSignIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final awaitingCode = _verificationId != null;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 30,
            vertical: 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.phone_iphone,
                size: 72,
                color: KloofColors.luxuryGold,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.phoneAuthTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                awaitingCode
                    ? l10n.phoneAuthCodeSubtitle(_normalizedPhone ?? '')
                    : l10n.phoneAuthPhoneSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KloofColors.secondaryText,
                ),
              ),
              const SizedBox(height: 32),
              if (!awaitingCode) ...[
                TextField(
                  controller: _phoneController,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: l10n.phoneAuthPhoneLabel,
                    hintText: '05xxxxxxxx',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  onSubmitted: (_) => _requestCode(),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _isBusy ? null : _requestCode,
                  child: _isRequestingCode
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.phoneAuthSendCode),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  enabled: !_isBusy,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.phoneAuthCodeLabel,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) => _submitCode(),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _isBusy ? null : _submitCode,
                  child: _isCompletingSignIn
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.phoneAuthVerifyCode),
                ),
                TextButton(
                  onPressed: _isBusy
                      ? null
                      : () {
                          setState(() {
                            _verificationId = null;
                            _normalizedPhone = null;
                            _otpController.clear();
                          });
                        },
                  child: Text(l10n.phoneAuthChangePhone),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerProfileCompletionScreen extends StatefulWidget {
  final String phoneNumber;

  const CustomerProfileCompletionScreen({super.key, required this.phoneNumber});

  @override
  State<CustomerProfileCompletionScreen> createState() =>
      _CustomerProfileCompletionScreenState();
}

class _CustomerProfileCompletionScreenState
    extends State<CustomerProfileCompletionScreen> {
  final _fullNameController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final l10n = AppLocalizations.of(context);
    final fullName = _fullNameController.text.trim();
    if (fullName.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.phoneAuthFullNameRequired)));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.phoneNumber != widget.phoneNumber) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authUnexpectedError)));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final profileRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final existingProfile = await profileRef.get();
      if (existingProfile.exists) {
        final role = existingProfile.data()?['role']?.toString().toLowerCase();
        if (role != 'customer') {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.phoneAuthCustomerOnly)));
        }
        return;
      }

      await profileRef.set({
        'fullName': fullName,
        'phone': widget.phoneNumber,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.phoneAuthProfileCreateFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.phoneAuthCompleteProfileTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.phoneAuthCompleteProfileSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _fullNameController,
                enabled: !_isSaving,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: l10n.registerFullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onSubmitted: (_) => _saveProfile(),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.phoneAuthSaveProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InvalidAuthenticatedProfileScreen extends StatelessWidget {
  const InvalidAuthenticatedProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: KloofColors.error,
                ),
                const SizedBox(height: 20),
                Text(l10n.phoneAuthInvalidProfile, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: FirebaseAuth.instance.signOut,
                  child: Text(l10n.homeSignOutAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
