import 'package:flutter/material.dart';
import 'package:kloof/l10n/app_localizations.dart';
import 'package:kloof/theme/kloof_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_screen.dart';

class BarberDetailsScreen extends StatelessWidget {
  final String barberId;
  final String name;
  final String shopName;
  final String rating;
  final String imageUrl;
  final Object? services;
  final Object? workingHours;
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
    this.workingHours,
    required this.address,
    this.latitude,
    this.longitude,
  });

  bool get _hasValidCoordinates {
    final lat = latitude;
    final lng = longitude;
    return lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  Future<void> _openLocation(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final query = _hasValidCoordinates
        ? '${latitude!},${longitude!}'
        : address.trim();
    if (query.isEmpty) return;

    final uri = Uri.https('maps.apple.com', '/', {'q': query});
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.barberDetailsLocationOpenFailed)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.barberDetailsLocationOpenFailed)),
      );
    }
  }

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
        color: KloofColors.primaryText,
      ),
    );
  }

  Widget _serviceRow(String service, double? price, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.content_cut, size: 18, color: KloofColors.mutedGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              service,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                color: KloofColors.primaryText,
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
                color: KloofColors.softGold,
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
              style: const TextStyle(
                fontSize: 14,
                color: KloofColors.primaryText,
              ),
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 14,
              color: KloofColors.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _localizedDayLabel(String day, AppLocalizations l10n) {
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

  TimeOfDay? _parseSavedTime(Object? rawValue) {
    final value = rawValue?.toString().trim();
    if (value == null || value.isEmpty) return null;

    final normalized = value.replaceAll('ص', 'AM').replaceAll('م', 'PM');
    final parts = normalized.split(RegExp(r'\s+'));
    final hourAndMinute = parts.first.split(':');
    if (hourAndMinute.length != 2) return null;

    var hour = int.tryParse(hourAndMinute[0]);
    final minute = int.tryParse(hourAndMinute[1]);
    if (hour == null || minute == null) return null;

    if (parts.length > 1) {
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
    }

    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  List<Widget> _workingHourRows(BuildContext context, AppLocalizations l10n) {
    if (workingHours is! Map) {
      return [
        _workingHourRow(
          l10n.barberDetailsMondayToFriday,
          l10n.barberDetailsHoursWeekday,
        ),
        _workingHourRow(
          l10n.barberDetailsSaturday,
          l10n.barberDetailsHoursSaturday,
        ),
        _workingHourRow(l10n.barberDetailsSunday, l10n.barberDetailsClosed),
      ];
    }

    final data = Map<String, dynamic>.from(workingHours as Map);
    final workingDays = (data['workingDays'] is List)
        ? List<String>.from(data['workingDays'] as List)
        : const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final openingTime = _parseSavedTime(data['openingTime']);
    final closingTime = _parseSavedTime(data['closingTime']);
    final hours = openingTime == null || closingTime == null
        ? l10n.barberDashboardNotSet
        : '${MaterialLocalizations.of(context).formatTimeOfDay(openingTime)} – '
              '${MaterialLocalizations.of(context).formatTimeOfDay(closingTime)}';

    return const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        .map(
          (day) => _workingHourRow(
            _localizedDayLabel(day, l10n),
            workingDays.contains(day) ? hours : l10n.barberDetailsClosed,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final serviceList = _serviceEntries();
    final displayAddress = address.trim().isEmpty
        ? l10n.homeAddressNotAvailable
        : address;
    final hasLocation = _hasValidCoordinates || address.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: KloofColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: KloofColors.warmOffWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: KloofColors.primaryText),
        title: Text(name),
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
                              color: KloofColors.secondarySurface,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.content_cut,
                                size: 64,
                                color: KloofColors.softGold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: KloofColors.primaryText,
                      ),
                    ),
                    if (shopName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 17,
                          color: KloofColors.secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: KloofColors.luxuryGold,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rating,
                          style: const TextStyle(
                            color: KloofColors.luxuryGold,
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
                        color: KloofColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: KloofColors.mutedGold,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  displayAddress,
                                  style: const TextStyle(
                                    color: KloofColors.secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (hasLocation) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton.icon(
                                onPressed: () => _openLocation(context),
                                icon: const Icon(Icons.map_outlined),
                                label: Text(l10n.barberDetailsOpenLocation),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KloofColors.cardBackground,
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
                        color: KloofColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(l10n.barberDetailsWorkingHours),
                          const SizedBox(height: 8),
                          ..._workingHourRows(context, l10n),
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
                        builder: (context) => BookingScreen(
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
                    backgroundColor: KloofColors.primaryBlack,
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
