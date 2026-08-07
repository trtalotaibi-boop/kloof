import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kloof/l10n/app_localizations.dart';
import '../utils/barber_document_utils.dart';
import 'barber_details_screen.dart';
import 'barber_dashboard_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCheckingRole = true;

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final normalized = rawName.trim().toLowerCase();
    switch (normalized) {
      case 'haircut':
      case 'حلاقة الرأس':
        return l10n.serviceHaircut;
      case 'beard':
      case 'beard trim':
      case 'لحية':
      case 'حلاقة الدقن':
        return l10n.serviceBeard;
      case 'haircut + beard':
      case 'haircut & beard':
      case 'حلاقة الرأس والدقن':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'kids':
      case 'kids haircut':
      case 'أطفال':
      case 'حلاقة أطفال':
        return l10n.serviceKidsHaircut;
      case 'full head shave':
      case 'full head shave (zero cut)':
      case 'zero cut':
      case 'حلاقة كاملة':
      case 'حلاقة كاملة (زيرو)':
        return l10n.serviceFullHeadShave;
      default:
        return rawName.trim();
    }
  }

  String _localizedServicesSummary(String rawServices, AppLocalizations l10n) {
    if (rawServices.trim().isEmpty) return l10n.homeDefaultServices;
    return rawServices
        .replaceAll('•', ',')
        .split(',')
        .map((service) => _localizedServiceName(service, l10n))
        .where((service) => service.isNotEmpty)
        .join(' • ');
  }

  @override
  void initState() {
    super.initState();
    _enforceCustomerAccess();
  }

  Future<void> _enforceCustomerAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isCheckingRole = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final role = (data['role']?.toString().toLowerCase() ?? 'customer');
      final fullName = data['fullName']?.toString().trim();
      final barberName = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (user.email ?? 'Barber');

      if (role == 'barber') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BarberDashboardScreen(barberName: barberName),
          ),
        );
        return;
      }
    } catch (_) {
      // Keep customer flow if role lookup fails.
    }

    if (!mounted) return;
    setState(() {
      _isCheckingRole = false;
    });
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final shouldSignOut =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.homeSignOutTitle),
              content: Text(l10n.homeSignOutConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.homeSignOutAction),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldSignOut) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isCheckingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l10n.appTitle,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                return IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_none, color: Colors.black),
                );
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('recipientId', isEqualTo: currentUser.uid)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data?.docs.length ?? 0;
                  return IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsScreen(),
                        ),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none, color: Colors.black),
                        if (unreadCount > 0)
                          Positioned(
                            right: -6,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyBookingsScreen()),
              );
            },
            child: Text(
              l10n.myBookingsTitle,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout, color: Colors.black)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.homeCurrentLocation, style: const TextStyle(color: Colors.grey)),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 5),
                    Text(l10n.homeCityMakkah, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(l10n.homeWelcome, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(l10n.homeCategories, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _categoryChip(l10n.serviceHaircut),
                  const SizedBox(width: 10),
                  _categoryChip(l10n.serviceBeard),
                  const SizedBox(width: 10),
                  _categoryChip(l10n.serviceKidsHaircut),
                  const SizedBox(width: 10),
                  _categoryChip(l10n.homeCategoryVip),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(l10n.homeFindFavoriteBarber, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 25),
            TextField(
              decoration: InputDecoration(
                hintText: l10n.homeSearchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 30),
            const SizedBox(height: 20),
            Text(l10n.homeTopRated, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('barbers').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text(l10n.homeNoBarbersFound);
                }
                final barbers = snapshot.data!.docs.map((doc) {
                  final barberData = doc.data() as Map<String, dynamic>;
                  final name = barberDisplayName(barberData);
                  final rawRating = barberData['rating'];
                  final services = barberServicesSummary(barberData, fallback: '');
                  if (name.trim().isEmpty || services.trim().isEmpty) return null;
                  final ratingText = rawRating == null
                      ? '0.0'
                      : (rawRating is num
                          ? rawRating.toDouble().toStringAsFixed(1)
                          : (double.tryParse(rawRating.toString())?.toStringAsFixed(1) ?? '0.0'));
                  final imageUrl = barberData['imageUrl']?.toString() ?? '';
                  final address = barberData['address']?.toString() ?? l10n.homeAddressNotAvailable;
                  final latitude = barberData['latitude'] is num ? (barberData['latitude'] as num).toDouble() : null;
                  final longitude = barberData['longitude'] is num ? (barberData['longitude'] as num).toDouble() : null;
                  final isOnline = barberIsOnline(barberData);
                  return {
                    'barberId': doc.id,
                    'name': name,
                    'rating': '⭐ $ratingText',
                    'imageUrl': imageUrl,
                    'services': services,
                    'address': address,
                    'latitude': latitude,
                    'longitude': longitude,
                    'isOnline': isOnline,
                  };
                }).whereType<Map<String, Object?>>().toList();
                barbers.sort((a, b) {
                  final aOnline = a['isOnline'] as bool;
                  final bOnline = b['isOnline'] as bool;
                  if (aOnline == bOnline) return 0;
                  return aOnline ? -1 : 1;
                });
                return Column(
                  children: barbers.map((barber) {
                    return _barberCard(
                      l10n,
                      barber['barberId'] as String,
                      barber['name'] as String,
                      barber['rating'] as String,
                      imageUrl: barber['imageUrl'] as String,
                      services: barber['services'] as String,
                      address: barber['address'] as String,
                      latitude: barber['latitude'] as double?,
                      longitude: barber['longitude'] as double?,
                      isOnline: barber['isOnline'] as bool,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _barberCard(
    AppLocalizations l10n,
    String barberId,
    String name,
    String rating, {
    String? imageUrl,
    String? services,
    String? address,
    double? latitude,
    double? longitude,
    required bool isOnline,
  }) {
    final isOffline = !isOnline;
    final localizedServices = _localizedServicesSummary(services ?? '', l10n);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarberDetailsScreen(
              barberId: barberId,
              name: name,
              rating: rating,
              imageUrl: imageUrl ?? '',
              services: services ?? 'Haircut • Beard',
              address: address ?? l10n.homeAddressNotAvailable,
              latitude: latitude,
              longitude: longitude,
            ),
          ),
        );
      },
      child: Opacity(
        opacity: isOffline ? 0.6 : 1.0,
        child: Card(
          margin: const EdgeInsets.only(bottom: 20),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? null
                      : const Icon(Icons.content_cut, size: 30, color: Colors.black),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                          if (isOffline)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                l10n.homeOfflineStatus,
                                style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(rating, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(localizedServices, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(25)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
