import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';

class ForceChangePasswordScreen extends StatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  State<ForceChangePasswordScreen> createState() => _ForceChangePasswordState();
}

class _ForceChangePasswordState extends State<ForceChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_newCtrl.text.length > 128) {
      setState(() => _error = 'Password must be at most 128 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiClient.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      // Any biometric enrollment made before this forced reset is stale --
      // clear it first, then offer a fresh enrollment now that the real,
      // final password is set (login.dart deliberately skips its own offer
      // while a forced change is pending, to avoid enabling here just to
      // have this disable() immediately undo it).
      await auth.disableBiometric();
      if (!mounted) return;
      final canUseBio = await auth.isBiometricAvailable;
      if (canUseBio && mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Quick unlock', style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text('Use Face ID or fingerprint to unlock Edtrack when you come back to the app.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enable')),
            ],
          ),
        );
        if (enable == true && mounted) {
          final confirmed = await auth.authenticateBiometric('Confirm your biometric to enable quick unlock');
          if (confirmed) await auth.enableBiometric();
        }
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.amberLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(child: Text('🔐', style: TextStyle(fontSize: 30))),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Set New Password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Your admin has set a temporary password.\nPlease create a new one to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
                ),
              ),
              const SizedBox(height: 36),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PasswordField(
                      fieldKey: const Key('current_password_field'),
                      label: 'TEMPORARY PASSWORD',
                      controller: _currentCtrl,
                      obscure: _obscureCurrent,
                      onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      hint: 'Enter password from admin',
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      fieldKey: const Key('new_password_field'),
                      label: 'NEW PASSWORD',
                      controller: _newCtrl,
                      obscure: _obscureNew,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      hint: 'At least 6 characters',
                    ),
                    const SizedBox(height: 16),
                    _PasswordField(
                      fieldKey: const Key('confirm_password_field'),
                      label: 'CONFIRM NEW PASSWORD',
                      controller: _confirmCtrl,
                      obscure: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      hint: 'Repeat new password',
                      onSubmit: _submit,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.coralLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('set_password_button'),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Set Password & Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String hint;
  final VoidCallback? onSubmit;
  final Key? fieldKey;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.hint,
    this.onSubmit,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: obscure,
          maxLength: 128,
          textInputAction: onSubmit != null ? TextInputAction.done : TextInputAction.next,
          onSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.muted,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
