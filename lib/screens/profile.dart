import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingPhoto = false;
  bool _sendingTestPush = false;

  Future<void> _sendTestPush(BuildContext context) async {
    setState(() => _sendingTestPush = true);
    try {
      final result = await ApiClient.sendTestPush();
      final delivered = Map<String, dynamic>.from(result['delivered'] as Map? ?? {});
      final anyDelivered = delivered.values.any((v) => v == true);
      if (!context.mounted) return;
      showSnack(
        context,
        anyDelivered
            ? 'Test notification sent — check your phone in a few seconds'
            : 'Could not deliver to any device — push token may be invalid',
        error: !anyDelivered,
      );
    } catch (e) {
      if (context.mounted) showSnack(context, 'Failed to send test notification', error: true);
    } finally {
      if (mounted) setState(() => _sendingTestPush = false);
    }
  }

  void _openPhotoFullscreen(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(photoUrl, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48)),
              ),
            ),
            Positioned(
              top: 40, right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, String? currentPhotoUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty)
              ListTile(
                leading: Icon(Icons.visibility_rounded, color: sheetCtx.primary),
                title: const Text('View Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openPhotoFullscreen(context, currentPhotoUrl);
                },
              ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: sheetCtx.primary),
              title: const Text('Change Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickAndUploadPhoto(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploadingPhoto = true);
    try {
      final resp = await ApiClient.getPhotoUploadUrl(file.name, contentType, bytes.lengthInBytes);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      final putRes = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      if (putRes.statusCode >= 400) throw Exception('Could not upload to storage (${putRes.statusCode}). Try again.');
      await ApiClient.savePhotoUrl(photoUrl);
      if (mounted) await context.read<AuthProvider>().updatePhotoUrl(photoUrl);
      if (mounted) showSnack(context, 'Photo updated');
    } catch (e) {
      if (mounted) {
        final msg = e is ApiError ? e.message : e.toString().replaceFirst('Exception: ', '');
        showSnack(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showEditSheet(BuildContext context, AuthUser user) {
    final nameCtrl = TextEditingController(text: user.teacherName);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final emailCtrl = TextEditingController(text: user.email ?? '');
    bool saving = false;
    bool fetchDone = false;
    String? nameError;
    String? phoneError;

    void fetchFresh(StateSetter setSheet) {
      if (fetchDone) return;
      fetchDone = true;
      ApiClient.getMyProfile().then((data) {
        setSheet(() {
          nameCtrl.text = data['name'] as String? ?? nameCtrl.text;
          phoneCtrl.text = data['phone'] as String? ?? phoneCtrl.text;
          emailCtrl.text = data['email'] as String? ?? emailCtrl.text;
        });
      }).catchError((_) {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          fetchFresh(setSheet);
          return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Edit Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 14),
              TextField(
                key: const Key('profile_name_field'),
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                maxLength: 30,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: nameError,
                  counterText: '',
                ),
                onChanged: (_) { if (nameError != null) setSheet(() => nameError = null); },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('profile_phone_field'),
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: phoneError,
                  counterText: '',
                ),
                onChanged: (_) { if (phoneError != null) setSheet(() => phoneError = null); },
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('profile_email_field'),
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('profile_save_button'),
                  onPressed: saving ? null : () async {
                    // Inline validation
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    String? nErr;
                    String? pErr;
                    if (name.isEmpty) nErr = 'Name is required';
                    else if (name.length > 30) nErr = 'Max 30 characters';
                    if (phone.isNotEmpty && phone.length != 10) pErr = 'Must be exactly 10 digits';
                    if (nErr != null || pErr != null) {
                      setSheet(() { nameError = nErr; phoneError = pErr; });
                      return;
                    }
                    setSheet(() => saving = true);
                    try {
                      final email = emailCtrl.text.trim();
                      await ApiClient.updateMyProfile(
                        name: name.isNotEmpty ? name : null,
                        phone: phone.isNotEmpty ? phone : null,
                        email: email.isNotEmpty ? email : null,
                      );
                      if (ctx.mounted) {
                        await ctx.read<AuthProvider>().updateProfile(
                          name: name.isNotEmpty ? name : null,
                          phone: phone.isNotEmpty ? phone : null,
                          email: email.isNotEmpty ? email : null,
                        );
                        Navigator.pop(ctx);
                        if (mounted) showSnack(context, 'Profile updated');
                      }
                    } catch (e) {
                      setSheet(() => saving = false);
                      if (ctx.mounted) {
                        final msg = e is ApiError ? e.message : 'Could not update profile. Try again.';
                        showSnack(ctx, msg, error: true);
                      }
                    }
                  },
                  child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Save'),
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0A00), Color(0xFF3D1A08)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: context.primary.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showPhotoOptions(context, user.photoUrl),
                          child: Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  gradient: user.photoUrl == null
                                      ? LinearGradient(colors: [context.primary, Color.lerp(context.primary, Colors.black, 0.15)!])
                                      : null,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 3),
                                ),
                                child: ClipOval(
                                  child: _uploadingPhoto
                                      ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : user.photoUrl != null
                                          ? Image.network(user.photoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(auth.initials, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white))))
                                          : Center(child: Text(auth.initials, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white))),
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(color: context.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user.teacherName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.schoolName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: [
                            _ProfileChip(_roleLabel(user.role)),
                            _ProfileChip('🏫 ${user.schoolName}'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Edit details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ProfileRow(
                  icon: '👤',
                  iconColor: context.primaryLight,
                  label: 'Edit Details',
                  sub: 'Name, email, contact info',
                  onTap: () => _showEditSheet(context, user),
                ),
              ),

              const SizedBox(height: 16),

              // Danger zone
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _sendingTestPush ? null : () => _sendTestPush(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: context.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(child: Text('🔔', style: TextStyle(fontSize: 15))),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Send Test Notification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                                  Text('Verify push notifications reach this device', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            if (_sendingTestPush)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.coral.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.coralLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                  child:
                                      Text('🚪', style: TextStyle(fontSize: 15))),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.coral,
                                  ),
                                ),
                                Text(
                                  'You will need to sign in again',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'hod': return '🎓 Head of Dept';
      case 'admin': return '⚙️ Admin';
      case 'principal': return '🏛️ Principal';
      case 'director': return '🏢 Director';
      default: return '👩‍🏫 Teacher';
    }
  }


  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'You will need to sign in again to access the app.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  const _ProfileChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
      );
}

class _ProfileRow extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.muted),
            ],
          ),
        ),
      );
}
