import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';

import 'edit_barber_profile_screen.dart';
import '../data/barber_profile_store.dart';

class BarberProfileScreen extends StatefulWidget {
  const BarberProfileScreen({super.key});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  Future<DocumentReference<Map<String, dynamic>>> _ensureProfileDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No signed-in barber user found.');
    }

    return BarberProfileStore(
      FirebaseFirestore.instance,
    ).ensureCanonicalProfile(uid: user.uid, fallbackName: user.displayName);
  }

  Widget _profileRow(String label, String value) {
    final displayValue = value.trim().isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: KloofColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: KloofColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '-';
    if (price is num) {
      if (price == price.toInt()) {
        return price.toInt().toString();
      }
      return price.toStringAsFixed(2);
    }

    final parsed = double.tryParse(price.toString());
    if (parsed == null) {
      return price.toString();
    }
    if (parsed == parsed.toInt()) {
      return parsed.toInt().toString();
    }
    return parsed.toStringAsFixed(2);
  }

  String _formatDuration(dynamic duration, AppLocalizations l10n) {
    if (duration == null || duration.toString().trim().isEmpty) {
      return l10n.barberProfileNotAvailable;
    }
    if (duration is num) {
      return l10n.barberProfileDurationMinutes(duration.toInt().toString());
    }
    final parsed = int.tryParse(duration.toString());
    if (parsed == null || parsed <= 0) {
      return l10n.barberProfileNotAvailable;
    }
    return l10n.barberProfileDurationMinutes(parsed.toString());
  }

  String _localizedServiceName(String rawName, AppLocalizations l10n) {
    final canonical = rawName.trim();
    if (canonical.isEmpty) return canonical;

    switch (canonical.toLowerCase()) {
      case 'haircut':
        return l10n.serviceHaircut;
      case 'beard trim':
        return l10n.barberDetailsFallbackServiceBeardTrim;
      case 'haircut + beard':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'kids haircut':
        return l10n.barberProfileServiceKidsHaircut;
      case 'full head shave (zero cut)':
        return l10n.barberProfileServiceFullHeadShaveZeroCut;
      case 'beard machine shave':
        return l10n.barberProfileServiceBeardMachineShave;
      default:
        return canonical;
    }
  }

  String _localizedCityName(String rawCity, AppLocalizations l10n) {
    switch (rawCity.trim().toLowerCase()) {
      case 'makkah':
        return l10n.homeCityMakkah;
      case 'jeddah':
        return l10n.editBarberProfileCityJeddah;
      case 'madinah':
        return l10n.editBarberProfileCityMadinah;
      case 'riyadh':
        return l10n.editBarberProfileCityRiyadh;
      case 'dammam':
        return l10n.editBarberProfileCityDammam;
      default:
        return rawCity;
    }
  }

  List<Map<String, dynamic>> _readServices(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .map<Map<String, dynamic>>((item) {
          if (item is Map<String, dynamic>) {
            return {
              'name': (item['name'] ?? '').toString(),
              'price': item['price'],
              'duration': item['duration'],
            };
          }

          if (item is Map) {
            return {
              'name': (item['name'] ?? '').toString(),
              'price': item['price'],
              'duration': item['duration'],
            };
          }

          return {'name': item.toString(), 'price': null, 'duration': null};
        })
        .where((service) => service['name'].toString().trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: KloofColors.warmOffWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: KloofColors.primaryText),
        title: Text(
          l10n.barberProfileTitle,
          style: TextStyle(color: KloofColors.primaryText),
        ),
      ),
      body: FutureBuilder<DocumentReference<Map<String, dynamic>>>(
        future: _ensureProfileDoc(),
        builder: (context, refSnapshot) {
          if (refSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (refSnapshot.hasError || !refSnapshot.hasData) {
            return Center(
              child: Text(
                l10n.barberProfileLoadFailed,
                style: const TextStyle(color: KloofColors.secondaryText),
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: refSnapshot.data!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data?.data() ?? <String, dynamic>{};

              final fullName = (data['fullName'] ?? '').toString();
              final shopName = (data['shopName'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();
              final city = (data['city'] ?? '').toString();
              final address = (data['address'] ?? '').toString();
              final bio = (data['bio'] ?? '').toString();
              final profileImage =
                  (data['profileImage'] ?? data['imageUrl'] ?? '').toString();
              final services = _readServices(data['services']);

              return SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: KloofColors.secondarySurface,
                        backgroundImage: profileImage.trim().isNotEmpty
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage.trim().isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 42,
                                color: KloofColors.mutedGold,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _profileRow(l10n.barberProfileLabelBarberName, fullName),
                    _profileRow(l10n.barberProfileLabelShopName, shopName),
                    _profileRow(l10n.barberProfileLabelPhone, phone),
                    _profileRow(
                      l10n.barberProfileLabelCity,
                      _localizedCityName(city, l10n),
                    ),
                    _profileRow(l10n.barberProfileLabelAddress, address),
                    _profileRow(l10n.barberProfileLabelBio, bio),
                    const SizedBox(height: 6),
                    Text(
                      l10n.barberProfileServices,
                      style: TextStyle(
                        color: KloofColors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (services.isEmpty)
                      const Text(
                        '-',
                        style: TextStyle(
                          color: KloofColors.secondaryText,
                          fontSize: 15,
                        ),
                      )
                    else
                      ...services.map((service) {
                        final name = (service['name'] ?? '').toString().trim();
                        final displayName = _localizedServiceName(name, l10n);
                        final rawPrice = _formatPrice(service['price']);
                        final displayPrice = rawPrice == '-'
                            ? l10n.barberProfileNotAvailable
                            : l10n.bookingConfirmationPriceValue(rawPrice);
                        final displayDuration = _formatDuration(
                          service['duration'],
                          l10n,
                        );
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsetsDirectional.only(bottom: 10),
                          padding: const EdgeInsetsDirectional.all(12),
                          decoration: BoxDecoration(
                            color: KloofColors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: KloofColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName.isEmpty ? '-' : displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: KloofColors.primaryText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${l10n.barberProfilePriceLabel}: $displayPrice',
                                style: const TextStyle(
                                  color: KloofColors.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                              if (displayDuration !=
                                  l10n.barberProfileNotAvailable)
                                Text(
                                  '${l10n.barberProfileDurationLabel}: $displayDuration',
                                  style: const TextStyle(
                                    color: KloofColors.secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditBarberProfileScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KloofColors.primaryBlack,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l10n.barberProfileEditProfile),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
