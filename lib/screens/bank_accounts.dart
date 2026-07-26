import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<MaskedBankAccount> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final accounts = await ApiClient.getMyBankAccounts();
      setState(() { _accounts = accounts; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load bank accounts'; _loading = false; });
    }
  }

  Future<void> _setDefault(MaskedBankAccount account) async {
    try {
      await ApiClient.setDefaultBankAccount(account.id);
      _load();
    } catch (_) {
      if (mounted) _showSnack('Failed to set default account', error: true);
    }
  }

  Future<void> _delete(MaskedBankAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove bank account?'),
        content: Text('Remove ${account.bankName} ${account.maskedAccountNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: AppColors.coral))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.deleteMyBankAccount(account.id);
      _load();
    } catch (_) {
      if (mounted) _showSnack('Failed to remove account', error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.coral : null),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBankAccountSheet(onAdded: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Bank Details'),
        leading: const BackButton(),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Text('ℹ️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Used for payroll transfer. Account numbers are encrypted and always shown masked — even to you.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: AppColors.muted))))
                  else if (_accounts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Text('🏦', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 10),
                          Text('No bank account on file', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.muted)),
                        ],
                      ),
                    )
                  else
                    ..._accounts.map((a) => _BankAccountCard(
                          account: a,
                          onSetDefault: () => _setDefault(a),
                          onDelete: () => _delete(a),
                        )),
                  const SizedBox(height: 20),
                  if (_accounts.length < 2)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openAddSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Bank Account'),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  final MaskedBankAccount account;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _BankAccountCard({required this.account, required this.onSetDefault, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(account.accountHolderName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
            ),
            if (account.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('Default', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.green)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(account.maskedAccountNumber, style: const TextStyle(fontSize: 14, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text('${account.bankName} · ${account.ifsc}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!account.isDefault)
              TextButton(onPressed: onSetDefault, child: const Text('Set as Default')),
            const Spacer(),
            TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(foregroundColor: AppColors.coral),
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AddBankAccountSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddBankAccountSheet({required this.onAdded});

  @override
  State<_AddBankAccountSheet> createState() => _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends State<_AddBankAccountSheet> {
  final _holderCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  bool _saving = false;
  bool _showAccountNumber = false;
  bool _consentChecked = false;
  String? _error;

  @override
  void dispose() {
    _holderCtrl.dispose();
    _numberCtrl.dispose();
    _confirmCtrl.dispose();
    _ifscCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final holder = _holderCtrl.text.trim();
    final number = _numberCtrl.text.trim();
    if (holder.length < 2 || holder.length > 30) {
      setState(() => _error = 'Account holder name must be 2–30 characters');
      return;
    }
    if (_bankCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Bank name is required');
      return;
    }
    if (!RegExp(r'^\d{9,18}$').hasMatch(number)) {
      setState(() => _error = 'Account number must be 9–18 digits');
      return;
    }
    if (number != _confirmCtrl.text.trim()) {
      setState(() => _error = 'Account number and confirmation do not match');
      return;
    }
    if (!_consentChecked) {
      setState(() => _error = 'Please confirm these details are correct before saving');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiClient.addMyBankAccount(
        accountHolderName: holder,
        accountNumber: number,
        confirmAccountNumber: _confirmCtrl.text.trim(),
        ifsc: _ifscCtrl.text.trim().toUpperCase(),
        bankName: _bankCtrl.text.trim(),
        confirmed: _consentChecked,
      );
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e is ApiError ? e.message : 'Failed to add account. Check your details and try again.'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Add Bank Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 16),
              _field('Account Holder Name', _holderCtrl, maxLength: 30),
              const SizedBox(height: 12),
              _field('Account Number', _numberCtrl, keyboardType: TextInputType.number, maxLength: 18, masked: true),
              const SizedBox(height: 12),
              _field('Confirm Account Number', _confirmCtrl, keyboardType: TextInputType.number, maxLength: 18, masked: true),
              const SizedBox(height: 12),
              _field('IFSC Code', _ifscCtrl, hint: 'SBIN0001234'),
              const SizedBox(height: 12),
              _field('Bank Name', _bankCtrl),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => _consentChecked = !_consentChecked),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _consentChecked,
                      onChanged: (v) => setState(() => _consentChecked = v ?? false),
                      activeColor: context.primary,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          'I confirm these bank details are correct',
                          style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.coral)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {TextInputType? keyboardType, String? hint, int? maxLength, bool masked = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          obscureText: masked && !_showAccountNumber,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: masked
                ? IconButton(
                    icon: Icon(_showAccountNumber ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20, color: AppColors.muted),
                    onPressed: () => setState(() => _showAccountNumber = !_showAccountNumber),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
