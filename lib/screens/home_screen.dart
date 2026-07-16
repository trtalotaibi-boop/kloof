import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'barber_details_screen.dart';
import 'barber_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "KLOOF",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Current Location",
                  style: TextStyle(color: Colors.grey),
                ),
                Row(
                  children: const [
                    Icon(Icons.location_on, color: Colors.red),
                    SizedBox(width: 5),
                    Text(
                      "Makkah",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            const Text(
              "👋 Welcome",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Categories",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _categoryChip("Haircut"),
                  const SizedBox(width: 10),
                  _categoryChip("Beard"),
                  const SizedBox(width: 10),
                  _categoryChip("Kids"),
                  const SizedBox(width: 10),
                  _categoryChip("VIP"),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Find your favorite barber",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 25),
            TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BarberDashboardScreen(
                        barberName: 'Demo Barber',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Open Barber Dashboard'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Top Rated",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("barbers").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("No barbers found");
                }

                final barbers = snapshot.data!.docs.map((doc) {
                  final barberData = doc.data() as Map<String, dynamic>;
                  final name = barberData['name']?.toString();
                  final rawRating = barberData['rating'];
                  final services = barberData['services']?.toString();

                  if (name == null || name.trim().isEmpty || services == null || services.trim().isEmpty) {
                    return null;
                  }

                  final ratingText = rawRating == null
                      ? "0.0"
                      : (rawRating is num
                          ? rawRating.toDouble().toStringAsFixed(1)
                          : (double.tryParse(rawRating.toString())?.toStringAsFixed(1) ?? "0.0"));
                  final imageUrl = barberData['imageUrl']?.toString() ?? '';
                  final address = barberData['address']?.toString() ?? 'Address not available';
                  final latitude = barberData['latitude'] is num
                      ? (barberData['latitude'] as num).toDouble()
                      : null;
                  final longitude = barberData['longitude'] is num
                      ? (barberData['longitude'] as num).toDouble()
                      : null;
                  final isOnline = barberData['isOnline'] == true;

                  return {
                    'name': name,
                    'rating': "⭐ $ratingText",
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarberDetailsScreen(
              name: name,
              rating: rating,
              imageUrl: imageUrl ?? '',
              services: services ?? 'Haircut • Beard',
              address: address ?? 'Address not available',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                      ? NetworkImage(imageUrl)
                      : null,
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? null
                      : const Icon(
                          Icons.content_cut,
                          size: 30,
                          color: Colors.black,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Offline',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        rating,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Haircut • Beard",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isOffline ? null : () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Book"),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
