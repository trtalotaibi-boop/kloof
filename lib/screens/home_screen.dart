import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import 'barber_details_screen.dart';
import 'barber_dashboard_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'welcome_screen.dart';
import '../widgets/whatsapp_feedback_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCheckingRole = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<String> _serviceNames(dynamic rawServices) {
    if (rawServices is String) {
      return rawServices
          .replaceAll('•', ',')
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
    if (rawServices is! List) return <String>[];
    return rawServices
        .map((service) {
          if (service is Map) {
            return (service['name'] ?? '').toString().trim();
          }
          return service.toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final normalized = rawName.trim().toLowerCase();
    switch (normalized) {
      case 'haircut':
      case 'حلاقة الرأس':
        return l10n.serviceHaircut;
      case 'beard trim':
      case 'لحية trim':
      case 'حلاقة الدقن':
        return l10n.barberDetailsFallbackServiceBeardTrim;
      case 'haircut + beard':
      case 'حلاقة الرأس والدقن':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'full head shave (zero cut)':
      case 'حلاقة كاملة':
      case 'حلاقة الرأس بالمكينة':
        return l10n.barberProfileServiceFullHeadShaveZeroCut;
      case 'beard machine shave':
      case 'حلاقة الدقن بالمكينة':
        return l10n.barberProfileServiceBeardMachineShave;
      case 'kids haircut':
      case 'أطفال حلاقة الرأس':
      case 'حلاقة أطفال':
        return l10n.barberProfileServiceKidsHaircut;
      default:
        return rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  @override
  void initState() {
    super.initState();
    _enforceCustomerAccess();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final data = userDoc.data() ?? <String, dynamic>{};
      final role = (data['role']?.toString().toLowerCase() ?? 'customer');
      final fullName = data['fullName']?.toString().trim();
      final barberName = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (user.email ?? l10n.bookingConfirmationLabelBarber);

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
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: KloofColors.warmOffWhite,
        elevation: 0,
        title: Text(
          l10n.appTitle,
          style: TextStyle(
            color: KloofColors.softGold,
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
                  icon: const Icon(
                    Icons.notifications_none,
                    color: KloofColors.primaryText,
                  ),
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
                        const Icon(
                          Icons.notifications_none,
                          color: KloofColors.primaryText,
                        ),
                        if (unreadCount > 0)
                          PositionedDirectional(
                            end: -6,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: KloofColors.luxuryGold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: KloofColors.deepBlack,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
                MaterialPageRoute(
                  builder: (context) => const MyBookingsScreen(),
                ),
              );
            },
            child: Text(
              l10n.myBookingsTitle,
              style: TextStyle(
                color: KloofColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: KloofColors.primaryText),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.homeCurrentLocation,
                  style: TextStyle(color: KloofColors.secondaryText),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, color: KloofColors.luxuryGold),
                    SizedBox(width: 5),
                    Text(
                      l10n.homeCityMakkah,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            Text(
              l10n.homeWelcome,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const WhatsAppFeedbackButton(),
            const SizedBox(height: 20),
            Text(
              l10n.homeFindFavoriteBarber,
              style: TextStyle(color: KloofColors.secondaryText, fontSize: 16),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: l10n.homeSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.homeClearSearch,
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                filled: true,
                fillColor: KloofColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: KloofColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: KloofColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: KloofColors.luxuryGold,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              l10n.homeTopRated,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("barbers")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text(l10n.homeNoBarbersFound);
                }

                final canonicalLegacyIds = snapshot.data!.docs
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['legacyProfileId'] ?? '').toString();
                    })
                    .where((id) => id.isNotEmpty)
                    .toSet();
                final barbers = snapshot.data!.docs
                    .map((doc) {
                      if (canonicalLegacyIds.contains(doc.id)) return null;
                      final barberData = doc.data() as Map<String, dynamic>;
                      final fullName = barberData['fullName']
                          ?.toString()
                          .trim();
                      final legacyName = barberData['name']?.toString().trim();
                      final name = fullName != null && fullName.isNotEmpty
                          ? fullName
                          : legacyName;
                      final shopName =
                          barberData['shopName']?.toString().trim() ?? '';
                      final rawRating = barberData['rating'];
                      final services = barberData['services'];
                      final workingHours = barberData['workingHours'];

                      if (name == null || name.trim().isEmpty) {
                        return null;
                      }

                      final ratingText = rawRating == null
                          ? "0.0"
                          : (rawRating is num
                                ? rawRating.toDouble().toStringAsFixed(1)
                                : (double.tryParse(
                                        rawRating.toString(),
                                      )?.toStringAsFixed(1) ??
                                      "0.0"));
                      final imageUrl =
                          (barberData['profileImage'] ??
                                  barberData['imageUrl'] ??
                                  '')
                              .toString();
                      final address =
                          barberData['address']?.toString() ??
                          l10n.homeAddressNotAvailable;
                      final latitude = barberData['latitude'] is num
                          ? (barberData['latitude'] as num).toDouble()
                          : null;
                      final longitude = barberData['longitude'] is num
                          ? (barberData['longitude'] as num).toDouble()
                          : null;
                      final isOnline = barberData['isOnline'] == true;

                      return {
                        'id':
                            (barberData['uid'] ??
                                    barberData['ownerUid'] ??
                                    doc.id)
                                .toString(),
                        'name': name,
                        'shopName': shopName,
                        'rating': "⭐ $ratingText",
                        'imageUrl': imageUrl,
                        'services': services,
                        'workingHours': workingHours,
                        'address': address,
                        'latitude': latitude,
                        'longitude': longitude,
                        'isOnline': isOnline,
                      };
                    })
                    .whereType<Map<String, Object?>>()
                    .toList();

                barbers.sort((a, b) {
                  final aOnline = a['isOnline'] as bool;
                  final bOnline = b['isOnline'] as bool;
                  if (aOnline == bOnline) return 0;
                  return aOnline ? -1 : 1;
                });

                final normalizedQuery = _searchQuery.trim().toLowerCase();
                final filteredBarbers = normalizedQuery.isEmpty
                    ? barbers
                    : barbers.where((barber) {
                        final searchableText = <String>[
                          barber['name'] as String,
                          barber['shopName'] as String,
                          ..._serviceNames(barber['services']),
                        ].join(' ').toLowerCase();
                        return searchableText.contains(normalizedQuery);
                      }).toList();

                if (filteredBarbers.isEmpty) {
                  return Text(l10n.homeNoBarbersFound);
                }

                return Column(
                  children: filteredBarbers.map((barber) {
                    return _barberCard(
                      l10n,
                      barber['id'] as String,
                      barber['name'] as String,
                      barber['rating'] as String,
                      shopName: barber['shopName'] as String,
                      imageUrl: barber['imageUrl'] as String,
                      services: barber['services'],
                      workingHours: barber['workingHours'],
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
    required String shopName,
    String? imageUrl,
    Object? services,
    Object? workingHours,
    String? address,
    double? latitude,
    double? longitude,
    required bool isOnline,
  }) {
    final isOffline = !isOnline;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarberDetailsScreen(
              barberId: barberId,
              name: name,
              shopName: shopName,
              rating: rating,
              imageUrl: imageUrl ?? '',
              services: services,
              workingHours: workingHours,
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
          margin: const EdgeInsetsDirectional.only(bottom: 20),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: KloofColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: KloofColors.secondarySurface,
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                      ? NetworkImage(imageUrl)
                      : null,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? null
                      : const Icon(
                          Icons.content_cut,
                          size: 30,
                          color: KloofColors.softGold,
                        ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isOffline)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: KloofColors.secondarySurface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                l10n.homeOfflineStatus,
                                style: TextStyle(
                                  color: KloofColors.secondaryText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (shopName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KloofColors.secondaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: KloofColors.luxuryGold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (_serviceNames(services).isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          _serviceNames(services)
                              .take(2)
                              .map((name) => _localizedServiceName(name, l10n))
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: KloofColors.secondaryText,
                          ),
                        ),
                      ],
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
}
