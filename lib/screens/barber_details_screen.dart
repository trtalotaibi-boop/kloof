import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

import 'booking_screen.dart';

class BarberDetailsScreen extends StatelessWidget {
  final String barberId;
  final String name;
  final String shopName;
  final String rating;
  final String imageUrl;
  final Object? services;
  final String address;
  final double? latitude;
  final double? longitude;

  const BarberDetailsScreen({
    super.key,
    required this.barberId,
    required this.name,
    required this.shopName,
    required this.rating,
    required this.imageUrl,
    required this.services,
    required this.address,
    this.latitude,
    this.longitude,
  });

  List<_ServiceDisplayData> _serviceEntries() {
    if (services is String) {
      return (services as String)
          .replaceAll('•', ',')
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .map((name) => _ServiceDisplayData(name: name, price: null))
          .toList();
    }
    if (services is! List) return <_ServiceDisplayData>[];
    return (services as List)
        .map((service) {
          if (service is Map) {
            final name = (service['name'] ?? '').toString().trim();
            final rawPrice = service['price'];
            final price = rawPrice is num
                ? rawPrice.toDouble()
                : double.tryParse(rawPrice?.toString() ?? '');
            return _ServiceDisplayData(name: name, price: price);
          }
          return _ServiceDisplayData(
            name: service.toString().trim(),
            price: null,
          );
        })
        .where((service) => service.name.isNotEmpty)
        .toList();
  }

  String _localizedServiceDisplayName(String service, AppLocalizations l10n) {
    final normalized = service.trim().toLowerCase();
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
        return service.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _serviceRow(
    String service,
    double? price,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.content_cut, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              service,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (price != null)
            Text(
              l10n.bookingConfirmationPriceValue(
                price == price.toInt()
                    ? price.toInt().toString()
                    : price.toStringAsFixed(2),
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _workingHourRow(String day, String hours) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final serviceList = _serviceEntries();
    final displayAddress = address.trim().isEmpty
      ? l10n.homeAddressNotAvailable
      : address;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(name, style: const TextStyle(color: Colors.black)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 240,
                              width: double.infinity,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.content_cut,
                                size: 64,
                                color: Colors.black,
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    if (shopName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rating,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.black54,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayAddress,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(l10n.barberDetailsServicesAndPrices),
                          const SizedBox(height: 8),
                          if (serviceList.isEmpty)
                            Text(l10n.bookingNoServicesAvailable)
                          else
                          ...serviceList.map((service) {
                            final displayName = _localizedServiceDisplayName(
                              service.name,
                              l10n,
                            );
                            return _serviceRow(
                              displayName,
                              service.price,
                              l10n,
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(l10n.barberDetailsWorkingHours),
                          const SizedBox(height: 8),
                          _workingHourRow(
                            l10n.barberDetailsMondayToFriday,
                            l10n.barberDetailsHoursWeekday,
                          ),
                          _workingHourRow(
                            l10n.barberDetailsSaturday,
                            l10n.barberDetailsHoursSaturday,
                          ),
                          _workingHourRow(
                            l10n.barberDetailsSunday,
                            l10n.barberDetailsClosed,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            BookingScreen(
                              barberId: barberId,
                              barberName: name,
                              service: serviceList
                                  .map((service) => service.name)
                                  .join(','),
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    l10n.barberDetailsBookAppointment,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceDisplayData {
  final String name;
  final double? price;

  const _ServiceDisplayData({required this.name, required this.price});
}
