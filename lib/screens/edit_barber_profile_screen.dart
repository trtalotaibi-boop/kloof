import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kloof/l10n/app_localizations.dart';

import '../utils/barber_document_utils.dart';

class EditBarberProfileScreen extends StatefulWidget {
  const EditBarberProfileScreen({super.key});

  @override
  State<EditBarberProfileScreen> createState() =>
      _EditBarberProfileScreenState();
}

class _EditBarberProfileScreenState extends State<EditBarberProfileScreen> {
  static const List<String> _cities = [
    'Makkah',
    'Jeddah',
    'Madinah',
    'Riyadh',
    'Dammam',
  ];
  static const List<String> _defaultServiceNames = [
    'Haircut',
    'Beard Trim',
    'Haircut + Beard',
    'Kids Haircut',
    'Full Head Shave (Zero Cut)',
  ];

  final _fullNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedCity = _cities.first;
  String _existingProfileImageUrl = '';
  XFile? _pickedImage;

  final List<_ServiceFormData> _serviceForms = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  DocumentReference<Map<String, dynamic>> _docRefForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No signed-in barber user found.');
    }

    return FirebaseFirestore.instance.collection('barbers').doc(user.uid);
  }

  Future<void> _loadProfile() async {
    try {
      final docRef = _docRefForCurrentUser();
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
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

      final data = (await docRef.get()).data() ?? <String, dynamic>{};
      final servicesRaw = (data['services'] as List?) ?? <dynamic>[];

      _fullNameController.text = barberDisplayName(data);
      _shopNameController.text = (data['shopName'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      final loadedCity = (data['city'] ?? '').toString().trim();
      _selectedCity = _cities.contains(loadedCity) ? loadedCity : _cities.first;
      _addressController.text = (data['address'] ?? '').toString();
      _bioController.text = (data['bio'] ?? '').toString();
      _existingProfileImageUrl = (data['profileImage'] ?? '').toString();

      final parsedServices = <Map<String, dynamic>>[];
      for (final service in servicesRaw) {
        if (service is Map<String, dynamic>) {
          parsedServices.add(service);
        } else if (service is Map) {
          parsedServices.add(Map<String, dynamic>.from(service));
        } else {
          final name = service.toString().trim();
          if (name.isNotEmpty) {
            parsedServices.add({'name': name, 'price': null, 'duration': null});
          }
        }
      }

      for (final defaultName in _defaultServiceNames) {
        final match = parsedServices.firstWhere(
          (item) => (item['name'] ?? '').toString().trim() == defaultName,
          orElse: () => <String, dynamic>{},
        );

        _serviceForms.add(
          _ServiceFormData(
            name: defaultName,
            price: (match['price'] ?? '').toString(),
            duration: (match['duration'] ?? '').toString(),
            isDefault: true,
          ),
        );
      }

      for (final item in parsedServices) {
        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty || _defaultServiceNames.contains(name)) {
          continue;
        }

        _serviceForms.add(
          _ServiceFormData(
            name: name,
            price: (item['price'] ?? '').toString(),
            duration: (item['duration'] ?? '').toString(),
            isDefault: false,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.editBarberLoadFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (!mounted) return;
    setState(() {
      _pickedImage = image;
    });
  }

  Future<String> _uploadProfileImageIfNeeded(String userId) async {
    if (_pickedImage == null) {
      return _existingProfileImageUrl;
    }

    final file = File(_pickedImage!.path);
    final ext = _pickedImage!.name.contains('.')
        ? _pickedImage!.name.split('.').last
        : 'jpg';
    final path =
        'barber_profiles/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSaving = true;
    });

    try {
      final docRef = _docRefForCurrentUser();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(l10n.editBarberSignedOutError);
      }

      final profileImageUrl = await _uploadProfileImageIfNeeded(user.uid);

      final services = <Map<String, dynamic>>[];
      for (final service in _serviceForms) {
        final name = service.isDefault
            ? service.defaultName
            : service.nameController.text.trim();
        final priceText = service.priceController.text.trim();
        final durationText = service.durationController.text.trim();

        if (!service.isDefault &&
            name.isEmpty &&
            priceText.isEmpty &&
            durationText.isEmpty) {
          continue;
        }

        if (!service.isDefault && name.isEmpty) {
          throw Exception(l10n.editBarberCustomServiceNameRequired);
        }

        if (service.isDefault && priceText.isEmpty) {
          throw Exception(l10n.editBarberDefaultPriceRequired);
        }

        final parsedPrice = priceText.isEmpty
            ? null
            : double.tryParse(priceText);
        if (priceText.isNotEmpty && parsedPrice == null) {
          throw Exception(l10n.editBarberInvalidPrice);
        }
        if (service.isDefault && (parsedPrice == null || parsedPrice <= 0)) {
          throw Exception(l10n.editBarberDefaultPricePositive);
        }

        final parsedDuration = durationText.isEmpty
            ? null
            : int.tryParse(durationText);
        if (durationText.isNotEmpty &&
            (parsedDuration == null || parsedDuration <= 0)) {
          throw Exception(l10n.editBarberInvalidDuration);
        }

        services.add({
          'name': name,
          'price': parsedPrice ?? 0,
          'duration': parsedDuration,
        });
      }

      await docRef.set({
        'fullName': _fullNameController.text.trim(),
        'shopName': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _selectedCity,
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
        'profileImage': profileImageUrl,
        'services': services,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().startsWith('Exception: ')
                ? e.toString().replaceFirst('Exception: ', '')
                : l10n.editBarberSaveFailed,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _localizedDefaultServiceName(
    AppLocalizations l10n,
    String canonicalName,
  ) {
    switch (canonicalName) {
      case 'Haircut':
        return l10n.serviceHaircut;
      case 'Beard Trim':
        return l10n.serviceBeard;
      case 'Haircut + Beard':
        return l10n.barberProfileServiceHaircutAndBeard;
      case 'Kids Haircut':
        return l10n.serviceKidsHaircut;
      case 'Full Head Shave (Zero Cut)':
        return l10n.serviceFullHeadShave;
      default:
        return canonicalName;
    }
  }

  String _localizedCity(AppLocalizations l10n, String canonicalCity) {
    switch (canonicalCity) {
      case 'Makkah':
        return l10n.editBarberCityMakkah;
      case 'Jeddah':
        return l10n.editBarberCityJeddah;
      case 'Madinah':
        return l10n.editBarberCityMadinah;
      case 'Riyadh':
        return l10n.editBarberCityRiyadh;
      case 'Dammam':
        return l10n.editBarberCityDammam;
      default:
        return canonicalCity;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    for (final service in _serviceForms) {
      service.dispose();
    }
    super.dispose();
  }

  Widget _serviceItem(int index) {
    final l10n = AppLocalizations.of(context)!;
    final service = _serviceForms[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.isDefault
                      ? l10n.editBarberDefaultService
                      : l10n.editBarberService,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!service.isDefault)
                IconButton(
                  tooltip: l10n.editBarberRemoveService,
                  onPressed: () {
                    setState(() {
                      final removed = _serviceForms.removeAt(index);
                      removed.dispose();
                    });
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.black54),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (service.isDefault)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.editBarberServiceName,
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  _localizedDefaultServiceName(l10n, service.defaultName),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            _field(
              label: l10n.editBarberServiceName,
              controller: service.nameController,
            ),
          _field(
            label: l10n.editBarberPriceSar,
            controller: service.priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            label: l10n.editBarberDurationMinutes,
            controller: service.durationController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          l10n.editBarberTitle,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: _pickedImage != null
                            ? FileImage(File(_pickedImage!.path))
                            : (_existingProfileImageUrl.trim().isNotEmpty
                                  ? NetworkImage(_existingProfileImageUrl)
                                  : null),
                        child:
                            _pickedImage == null &&
                                _existingProfileImageUrl.trim().isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 38,
                                color: Colors.black54,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _pickImageFromGallery,
                        child: Text(l10n.editBarberSelectProfileImage),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _field(
                      label: l10n.editBarberBarberName,
                      controller: _fullNameController,
                    ),
                    _field(
                      label: l10n.editBarberShopName,
                      controller: _shopNameController,
                    ),
                    _field(
                      label: l10n.editBarberPhone,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCity,
                        items: _cities
                            .map(
                              (city) => DropdownMenuItem<String>(
                                value: city,
                                child: Text(_localizedCity(l10n, city)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedCity = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: l10n.editBarberCity,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    _field(
                      label: l10n.editBarberAddress,
                      controller: _addressController,
                    ),
                    _field(
                      label: l10n.editBarberBio,
                      controller: _bioController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.editBarberServices,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_serviceForms.length, _serviceItem),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _serviceForms.add(
                              _ServiceFormData(
                                name: '',
                                price: '',
                                duration: '',
                                isDefault: false,
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: Text(l10n.editBarberAddNewService),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(l10n.editBarberSaveProfile),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ServiceFormData {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController durationController;
  final bool isDefault;
  final String defaultName;

  _ServiceFormData({
    required String name,
    required String price,
    required String duration,
    required this.isDefault,
  }) : nameController = TextEditingController(text: name),
       priceController = TextEditingController(text: price),
       durationController = TextEditingController(text: duration),
       defaultName = name;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    durationController.dispose();
  }
}
