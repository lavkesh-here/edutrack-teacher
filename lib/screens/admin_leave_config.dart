import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminLeaveConfigScreen extends StatefulWidget {
  const AdminLeaveConfigScreen({super.key});

  @override
  State<AdminLeaveConfigScreen> createState() => _AdminLeaveConfigScreenState();
}

class _AdminLeaveConfigScreenState extends State<AdminLeaveConfigScreen> {
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _casualCtrl;
  late TextEditingController _sickCtrl;
  late TextEditingController _earnedCtrl;
  late TextEditingController _workingDaysCtrl;
  late TextEditingController _probationCtrl;

  @override
  void initState() {
    super.initState();
    _casualCtrl = TextEditingController();
    _sickCtrl = TextEditingController();
    _earnedCtrl = TextEditingController();
    _workingDaysCtrl = TextEditingController();
    _probationCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _casualCtrl.dispose();
    _sickCtrl.dispose();
    _earnedCtrl.dispose();
    _workingDaysCtrl.dispose();
    _probationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminGetLeaveConfig();
      setState(() {
        _casualCtrl.text = (data['casual_per_year'] ?? 12).toString();
        _sickCtrl.text = (data['sick_per_year'] ?? 12).toString();
        _earnedCtrl.text = (data['earned_per_year'] ?? 0).toString();
        _workingDaysCtrl.text = (data['working_days_per_month'] ?? 26).toString();
        _probationCtrl.text = (data['probation_months'] ?? 0).toString();
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.adminUpdateLeaveConfig({
        'casual_per_year': int.tryParse(_casualCtrl.text) ?? 12,
        'sick_per_year': int.tryParse(_sickCtrl.text) ?? 12,
        'earned_per_year': int.tryParse(_earnedCtrl.text) ?? 0,
        'working_days_per_month': int.tryParse(_workingDaysCtrl.text) ?? 26,
        'probation_months': int.tryParse(_probationCtrl.text) ?? 0,
      });
      if (mounted) showSnack(context, 'Leave config saved');
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
      appBar: AppBar(title: const Text('Leave Config'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.skyLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'These settings apply to all teachers in your school. Changes take effect immediately for new leave requests.',
                      style: TextStyle(fontSize: 12, color: AppColors.sky),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Annual Leave Allowances'),
                  const SizedBox(height: 12),
                  _ConfigField(fieldKey: const Key('casual_leave_field'), ctrl: _casualCtrl, label: 'Casual Leave (days/year)', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _ConfigField(fieldKey: const Key('sick_leave_field'), ctrl: _sickCtrl, label: 'Sick Leave (days/year)', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _ConfigField(fieldKey: const Key('earned_leave_field'), ctrl: _earnedCtrl, label: 'Earned Leave (days/year)', keyboardType: TextInputType.number),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Salary Calculation'),
                  const SizedBox(height: 12),
                  _ConfigField(fieldKey: const Key('working_days_field'), ctrl: _workingDaysCtrl, label: 'Working Days per Month', keyboardType: TextInputType.number),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Probation'),
                  const SizedBox(height: 12),
                  _ConfigField(fieldKey: const Key('probation_months_field'), ctrl: _probationCtrl, label: 'Probation Period (months)', keyboardType: TextInputType.number),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      key: const Key('save_leave_config_button'),
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.sun),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ConfigField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType? keyboardType;
  final Key? fieldKey;
  const _ConfigField({required this.ctrl, required this.label, this.keyboardType, this.fieldKey});

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      );
}
