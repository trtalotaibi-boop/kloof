import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';

import '../utils/barber_document_utils.dart';
import 'booking_screen.dart';

class BarberDetailsScreen extends StatelessWidget {
  final String barberId;
  final String name;
  final String rating;
  final String imageUrl;
  final String services;
  final String address;
  final double? latitude;
  final double? longitude;

  const BarberDetailsScreen({
    super.key,
    required this.barberId,
    required this.name,
    required this.rating,
    required this.imageUrl,
    required this.services,
    required this.address,
    this.latitude,
    this.longitude,
  });

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
      case 'full head shave (zero cut)':
      case 'full head shave':
      case 'zero cut':
      case 'حلاقة كاملة':
      case 'حلاقة كاملة (زيرو)':
        return l10n.serviceFullHeadShave;
      default:
        return rawName.trim();
    }
  }

  List<Map<String, dynamic>> _serviceItems(Map<String, dynamic>? data) {
    final rawServices = data?['services'];
    final result = <Map<String, dynamic>>[];

    if (rawServices is List) {
      for (final item in rawServices) {
        if (item is Map<String, dynamic>) {
          final service = Map<String, dynamic>.from(item);
          final serviceName = (service['name'] ?? '').toString().trim();
          if (serviceName.isNotEmpty) result.add(service);
        } else if (item is Map) {
          final service = Map<String, dynamic>.from(item);
          final serviceName = (service['name'] ?? '').toString().trim();
          if (serviceName.isNotEmpty) result.add(service);
        } else {
          final serviceName = item.toString().trim();
          if (serviceName.isNotEmpty) {
            result.add({'name': serviceName});
          }
        }
      }
    } else if (rawServices is String && rawServices.trim().isNotEmpty) {
      result.addAll(
        rawServices
            .replaceAll('•', ',')
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .map((item) => <String, dynamic>{'name': item}),
      );
    }

    if (result.isNotEmpty) return result;

    return services
        .replaceAll('•', ',')
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) => <String, dynamic>{'name': item})
        .toList();
  }

  String _formatPrice(BuildContext context, dynamic rawPrice) {
    if (rawPrice == null) return '';

    final parsed = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice.toString());
    if (parsed == null || parsed <= 0) return '';

    final value = parsed == parsed.roundToDouble()
        ? parsed.toInt().toString()
        : parsed.toStringAsFixed(2);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? '$value ر.س' : '$value SAR';
  }

  TimeOfDay? _parseStoredTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split(' ');
    if (parts.length != 2) return null;

    final hm = parts[0].split(':');
    if (hm.length != 2) return null;

    final rawHour = int.tryParse(hm[0]);
    final minute = int.tryParse(hm[1]);
    if (rawHour == null || minute == null) return null;

    var hour = rawHour;
    final period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatStoredTime(BuildContext context, String? value) {
    final parsed = _parseStoredTime(value);
    if (parsed == null) return value?.trim() ?? '';
    return MaterialLocalizations.of(context).formatTimeOfDay(parsed);
  }

  String _localizedDay(String day, AppLocalizations l10n) {
    switch (day) {
      case 'Mon':
        return l10n.barberDashboardDayMon;
      case 'Tue':
        return l10n.barberDashboardDayTue;
      case 'Wed':
        return l10n.barberDashboardDayWed;
      case 'Thu':
        return l10n.barberDashboardDayThu;
      case 'Fri':
        return l10n.barberDashboardDayFri;
      case 'Sat':
        return l10n.barberDashboardDaySat;
      case 'Sun':
        return l10n.barberDashboardDaySun;
      default:
        return day;
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

  Widget _serviceRow(String service, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.content_cut, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              service,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (price.isNotEmpty)
            Text(
              price,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('barbers')
          .doc(barberId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final liveName = barberDisplayName(data, fallback: name);
        final liveAddress = (data?['address'] ?? address).toString();
        final liveImageUrl = (data?['profileImage']?.toString().trim().isNotEmpty ?? false)
            ? data!['profileImage'].toString().trim()
            : ((data?['imageUrl']?.toString().trim().isNotEmpty ?? false)
                ? data!['imageUrl'].toString().trim()
                : imageUrl);
        final serviceItems = _serviceItems(data);
        final bookingServices = serviceItems
            .map((item) => (item['name'] ?? '').toString().trim())
            .where((item) => item.isNotEmpty)
            .join(' • ');
        final workingHours = barberWorkingHoursData(data);
        final workingDays = List<String>.from(
          workingHours['workingDays'] ?? const <String>[],
        );
        final openingTime = _formatStoredTime(
          context,
          workingHours['openingTime']?.toString(),
        );
        final closingTime = _formatStoredTime(
          context,
          workingHours['closingTime']?.toString(),
        );
        final hasWorkingHours =
            workingDays.isNotEmpty && openingTime.isNotEmpty && closingTime.isNotEmpty;
        final hoursText = hasWorkingHours ? '$openingTime - $closingTime' : '';

        return Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            title: Text(liveName, style: const TextStyle(color: Colors.black)),
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
                          child: liveImageUrl.isNotEmpty
                              ? Image.network(
                                  liveImageUrl,
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
                          liveName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
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
                                  liveAddress,
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
                              ...serviceItems.map((item) {
                                final serviceName =
                                    (item['name'] ?? '').toString().trim();
                                return _serviceRow(
                                  _localizedServiceName(serviceName, l10n),
                                  _formatPrice(context, item['price']),
                                );
                              }),
                            ],
                          ),
                        ),
                        if (hasWorkingHours) ...[
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
                                ...workingDays.map(
                                  (day) => _workingHourRow(
                                    _localizedDay(day, l10n),
                                    hoursText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: serviceItems.isEmpty
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookingScreen(
                                    barberId: barberId,
                                    barberName: liveName,
                                    service: bookingServices,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.black26,
                        disabledForegroundColor: Colors.white70,
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
      },
    );
  }
}
