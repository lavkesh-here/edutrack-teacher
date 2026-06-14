import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'force_change_password.dart';

// ── Step 1: Enter school code ─────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String _serverUrl = ApiClient.defaultBaseUrl;
  bool _bioEnabled = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    ApiClient.getBaseUrl().then((url) { if (mounted) setState(() => _serverUrl = url); });
    _checkBio();
  }

  Future<void> _checkBio() async {
    final auth = context.read<AuthProvider>();
    final available = await auth.isBiometricAvailable;
    final enabled = await auth.isBiometricEnabled;
    if (mounted) setState(() { _bioAvailable = available; _bioEnabled = enabled; });
  }

  Future<void> _biometricUnlock() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final err = await auth.biometricLogin();
    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _loading = false; });
    } else {
      setState(() => _loading = false);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeServer() async {
    final ctrl = TextEditingController(text: _serverUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Server URL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'https://your-backend.run.app'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ApiClient.setBaseUrl(result);
      if (mounted) setState(() => _serverUrl = result);
    }
  }

  Future<void> _next() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your school code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final school = await ApiClient.lookupSchool(code);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _CredentialsScreen(school: school)),
      );
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not connect. Check your network.');
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
              const SizedBox(height: 64),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.sun, Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.sun.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🎓', style: TextStyle(fontSize: 34)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'EduTrack',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Teacher App',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _changeServer,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dns_outlined, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _serverUrl.replaceFirst(RegExp(r'https?://'), ''),
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_outlined, size: 11, color: AppColors.muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sun.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter School Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your school code is provided by your school admin.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    // Biometric quick-unlock for returning users
                    if (_bioAvailable && _bioEnabled) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _biometricUnlock,
                          icon: const Icon(Icons.fingerprint_rounded, size: 22),
                          label: const Text('Unlock with Biometric',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.sun,
                            side: const BorderSide(color: AppColors.sun),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or sign in to a different account',
                              style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'SCHOOL CODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _next(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. DEMO001',
                        prefixIcon: Icon(Icons.school_outlined, color: AppColors.muted, size: 18),
                      ),
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
                        onPressed: _loading ? null : _next,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Continue'),
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

// ── Step 2: Credentials (with school branding) ────────────────────────────────

class _CredentialsScreen extends StatefulWidget {
  final SchoolInfo school;
  const _CredentialsScreen({required this.school});

  @override
  State<_CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<_CredentialsScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final mustChange = await auth.login(
        _email.text.trim(),
        _pass.text,
        schoolCode: widget.school.code,
      );
      if (!mounted) return;

      // Offer biometric enrollment after first successful password login
      final canUseBio = await auth.isBiometricAvailable;
      final alreadyEnabled = await auth.isBiometricEnabled;
      if (canUseBio && !alreadyEnabled && mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Quick unlock', style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text('Use Face ID or fingerprint to unlock EduTrack next time instead of typing your password.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enable')),
            ],
          ),
        );
        if (enable == true) {
          await auth.enableBiometric(_email.text.trim(), _pass.text);
        }
      }

      if (!mounted) return;
      if (mustChange) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ForceChangePasswordScreen()));
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // School branding banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.sun, Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('🏫', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.school.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            widget.school.code,
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.sun.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'EMAIL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'teacher@school.edu',
                        prefixIcon: Icon(Icons.mail_outline, color: AppColors.muted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'PASSWORD',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pass,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.muted,
                            size: 18,
                          ),
                        ),
                      ),
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
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Sign In'),
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
