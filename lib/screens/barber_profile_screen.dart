import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_barber_profile_screen.dart';

class BarberProfileScreen extends StatefulWidget {
  const BarberProfileScreen({super.key});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  static const List<String> _defaultServiceNames = [
    'Haircut',
    'Beard Trim',
    'Haircut + Beard',
    'Kids Haircut',
    'Full Head Shave (Zero Cut)',
  ];

  Future<DocumentReference<Map<String, dynamic>>> _ensureProfileDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No signed-in barber user found.');
    }

    final docRef = FirebaseFirestore.instance
        .collection('barbers')
        .doc(user.uid);

    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'fullName': '',
        'shopName': '',
        'phone': '',
        'city': '',
        'address': '',
        'bio': '',
        'profileImage': '',
        'services': _defaultServiceNames
            .map(
              (name) => <String, dynamic>{
                'name': name,
                'price': null,
                'duration': null,
              },
            )
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return docRef;
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              color: Colors.black,
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
        return '${price.toInt()} SAR';
      }
      return '${price.toStringAsFixed(2)} SAR';
    }

    final parsed = double.tryParse(price.toString());
    if (parsed == null) {
      return '${price.toString()} SAR';
    }
    if (parsed == parsed.toInt()) {
      return '${parsed.toInt()} SAR';
    }
    return '${parsed.toStringAsFixed(2)} SAR';
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '-';
    if (duration is num) return '${duration.toInt()} min';
    final parsed = int.tryParse(duration.toString());
    if (parsed == null) return duration.toString();
    return '$parsed min';
  }

  List<Map<String, dynamic>> _readServices(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      return _defaultServiceNames
          .map(
            (name) => <String, dynamic>{
              'name': name,
              'price': null,
              'duration': null,
            },
          )
          .toList();
    }

    return raw.map<Map<String, dynamic>>((item) {
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
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Barber Profile',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: FutureBuilder<DocumentReference<Map<String, dynamic>>>(
        future: _ensureProfileDoc(),
        builder: (context, refSnapshot) {
          if (refSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (refSnapshot.hasError || !refSnapshot.hasData) {
            return const Center(
              child: Text(
                'Failed to load profile.',
                style: TextStyle(color: Colors.black54),
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
              final profileImage = (data['profileImage'] ?? '').toString();
              final services = _readServices(data['services']);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: profileImage.trim().isNotEmpty
                            ? NetworkImage(profileImage)
                            : null,
                        child: profileImage.trim().isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 42,
                                color: Colors.black54,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _profileRow('Barber Name', fullName),
                    _profileRow('Shop Name', shopName),
                    _profileRow('Phone', phone),
                    _profileRow('City', city),
                    _profileRow('Address', address),
                    _profileRow('Bio', bio),
                    const SizedBox(height: 6),
                    const Text(
                      'Services',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (services.isEmpty)
                      const Text(
                        '-',
                        style: TextStyle(color: Colors.black87, fontSize: 15),
                      )
                    else
                      ...services.map((service) {
                        final name = (service['name'] ?? '').toString().trim();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? '-' : name,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Price: ${_formatPrice(service['price'])}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Duration: ${_formatDuration(service['duration'])}',
                                style: const TextStyle(
                                  color: Colors.black87,
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
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Edit Profile'),
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
