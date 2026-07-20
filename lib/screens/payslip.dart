import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  PayslipRecord? _record;
  List<PayslipRecord> _history = [];
  bool _loading = false;
  bool _loadingHistory = true;
  bool _notFound = false;
  bool _currentMonthEmpty = false;

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _monthShort = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await Future.wait([_loadCurrent(), _loadHistory()]);
    if (mounted && _notFound && _history.isNotEmpty) {
      final latest = _history.first;
      setState(() {
        _selectedMonth = latest.month;
        _selectedYear = latest.year;
        _record = latest;
        _notFound = false;
        _currentMonthEmpty = true;
      });
    }
  }

  Future<void> _loadCurrent() async {
    setState(() { _loading = true; _notFound = false; _record = null; });
    try {
      final rec = await ApiClient.getPayslip(
          month: _selectedMonth, year: _selectedYear);
      setState(() { _record = rec; _notFound = rec == null; _loading = false; });
    } catch (_) {
      setState(() { _notFound = true; _loading = false; });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await ApiClient.getPayslipHistory();
      setState(() { _history = list; _loadingHistory = false; });
    } catch (_) {
      setState(() => _loadingHistory = false);
    }
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
    _loadCurrent();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_selectedYear == now.year && _selectedMonth == now.month) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
    _loadCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final isCurrentMonth = _selectedMonth == DateTime.now().month &&
        _selectedYear == DateTime.now().year;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Payslip'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('prev_month_button'),
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _previousMonth,
                    color: AppColors.muted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[_selectedMonth]} $_selectedYear',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('next_month_button'),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: isCurrentMonth ? AppColors.border : AppColors.muted,
                    ),
                    onPressed: isCurrentMonth ? null : _nextMonth,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payslip card
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_notFound || _record == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('💰', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    const Text(
                      'No payslip for this month',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payroll for ${_monthNames[_selectedMonth]} ${_selectedYear} has not been processed yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              )
            else
              _PayslipCard(
                record: _record!,
                teacherName: user.teacherName,
                schoolName: user.schoolName,
              ),

            const SizedBox(height: 16),

            // Info banner when current month has no payslip yet
            if (_currentMonthEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('ℹ️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payroll for ${_monthNames[DateTime.now().month]} ${DateTime.now().year} hasn\'t been processed yet.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.amber),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // History chips
            if (!_loadingHistory && _history.isNotEmpty) ...[
              const Text(
                'PREVIOUS MONTHS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _history.map((rec) {
                  final isSelected =
                      rec.month == _selectedMonth && rec.year == _selectedYear;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMonth = rec.month;
                        _selectedYear = rec.year;
                        _record = rec;
                        _notFound = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? context.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected ? context.primary : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _monthShort[rec.month],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : AppColors.text,
                            ),
                          ),
                          Text(
                            '${rec.year}',
                            style: TextStyle(
                              fontSize: 9,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final PayslipRecord record;
  final String teacherName;
  final String schoolName;

  const _PayslipCard({
    required this.record,
    required this.teacherName,
    required this.schoolName,
  });

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final isApproved = record.status == 'approved';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.primary, Color.lerp(context.primary, Colors.black, 0.15)!],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schoolName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  teacherName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_monthNames[record.month]} ${record.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? Colors.white.withOpacity(0.2)
                            : Colors.amber.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isApproved ? '✓ Approved' : '⏳ Pending',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Breakdown
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _PayRow(
                  label: 'Base Salary',
                  amount: record.baseSalary,
                  color: AppColors.text,
                ),
                const SizedBox(height: 10),
                _PayRow(
                  label: 'Bonus',
                  amount: record.bonus,
                  color: AppColors.green,
                  prefix: '+',
                ),
                const SizedBox(height: 10),
                _PayRow(
                  label: 'Deductions',
                  amount: record.deductions,
                  color: AppColors.coral,
                  prefix: '-',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.border, thickness: 1.5),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Net Payable',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Text(
                      '₹ ${record.netPay.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String prefix;

  const _PayRow({
    required this.label,
    required this.amount,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '$prefix₹ ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
}
