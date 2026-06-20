import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminSchoolSettingsScreen extends StatefulWidget {
  const AdminSchoolSettingsScreen({super.key});

  @override
  State<AdminSchoolSettingsScreen> createState() => _AdminSchoolSettingsScreenState();
}

class _AdminSchoolSettingsScreenState extends State<AdminSchoolSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _boardCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminGetSchool();
      _nameCtrl.text = data['name'] as String? ?? '';
      _boardCtrl.text = data['board_affiliation'] as String? ?? '';
      _phoneCtrl.text = data['phone'] as String? ?? '';
      _emailCtrl.text = data['email'] as String? ?? '';
      _addressCtrl.text = data['address'] as String? ?? '';
      _websiteCtrl.text = data['website'] as String? ?? '';
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
      setState(() => _loading = false);
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _useMyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        showSnack(
          context,
          permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Enable in device Settings.'
              : 'Location permission is required.',
          error: true,
        );
      }
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) showSnack(context, 'Please enable location services.', error: true);
      return;
    }
    setState(() => _gettingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      if (mounted) showSnack(context, 'Location captured. Tap Save Changes to apply.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not get location. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'board_affiliation': _boardCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
      };
      if (_latitude != null) body['latitude'] = _latitude;
      if (_longitude != null) body['longitude'] = _longitude;
      await ApiClient.adminUpdateSchool(body);
      if (mounted) showSnack(context, 'Settings saved successfully');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('School Settings'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.violetLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.violet.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🏫', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Update your school\'s contact info and basic details.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.violet,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'SCHOOL INFO',
                    children: [
                      _LabeledField(
                        label: 'School Name',
                        controller: _nameCtrl,
                        hint: 'e.g. St. Mary\'s School',
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        label: 'Board Affiliation',
                        controller: _boardCtrl,
                        hint: 'e.g. CBSE, ICSE, State Board',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'CONTACT',
                    children: [
                      _LabeledField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        hint: 'e.g. +91 98765 43210',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        label: 'Email',
                        controller: _emailCtrl,
                        hint: 'e.g. office@school.edu.in',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        label: 'Website',
                        controller: _websiteCtrl,
                        hint: 'e.g. https://school.edu.in',
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'ADDRESS',
                    children: [
                      _LabeledField(
                        label: 'Full Address',
                        controller: _addressCtrl,
                        hint: 'Street, City, State, PIN',
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // School Location section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SCHOOL LOCATION',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: AppColors.muted, letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Location status
                            Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: _latitude != null ? AppColors.tealLight : AppColors.bg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _latitude != null ? '📍' : '🗺️',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _latitude != null ? 'Location Set' : 'Location Not Set',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _latitude != null ? AppColors.teal : AppColors.muted,
                                        ),
                                      ),
                                      if (_latitude != null && _longitude != null)
                                        Text(
                                          '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                                        )
                                      else
                                        const Text(
                                          'Required for teacher GPS attendance',
                                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 12),
                            const Text(
                              'Teachers must be within 50 meters of this location to mark self-attendance.',
                              style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _gettingLocation ? null : _useMyLocation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.sky,
                                  side: const BorderSide(color: AppColors.sky),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: _gettingLocation
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(color: AppColors.sky, strokeWidth: 2))
                                    : const Icon(Icons.my_location, size: 16),
                                label: Text(
                                  _gettingLocation ? 'Getting location...' : 'Use My Current Location',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLines;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.text2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
