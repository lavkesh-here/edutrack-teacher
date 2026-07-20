import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class WhatsAppReportScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const WhatsAppReportScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<WhatsAppReportScreen> createState() => _WhatsAppReportScreenState();
}

class _WhatsAppReportScreenState extends State<WhatsAppReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  late TextEditingController _msgCtrl;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController();
    _generate();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.generateWhatsAppReport(widget.studentId);
      if (mounted) {
        setState(() {
          _data = data;
          _msgCtrl.text = data['message'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = (_data?['guardian_phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    final message = Uri.encodeComponent(_msgCtrl.text.trim());
    final uri = phone.isNotEmpty
        ? Uri.parse('https://wa.me/91$phone?text=$message')
        : Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) showSnack(context, 'WhatsApp not found on device');
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _msgCtrl.text.trim()));
    showSnack(context, 'Message copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Report for ${widget.studentName}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.teal),
                  SizedBox(height: 16),
                  Text('Generating report…', style: TextStyle(color: AppColors.muted)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.coral)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _generate, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Guardian info card
                      if (_data?['guardian_name'] != null || _data?['guardian_phone'] != null)
                        AppCard(
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(12)),
                                child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 18))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _data?['guardian_name'] as String? ?? 'Parent/Guardian',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                                    ),
                                    if (_data?['guardian_phone'] != null)
                                      Text(
                                        '+91 ${_data!['guardian_phone']}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Editable message
                      const Text(
                        'MESSAGE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: TextField(
                          key: const Key('whatsapp_message_field'),
                          controller: _msgCtrl,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14, color: AppColors.text, height: 1.6),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(16),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Edit the message above before sending.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('copy_report_button'),
                              onPressed: _copyToClipboard,
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.teal,
                                side: const BorderSide(color: AppColors.teal),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              key: const Key('open_whatsapp_button'),
                              onPressed: _openWhatsApp,
                              icon: const Text('💬', style: TextStyle(fontSize: 16)),
                              label: const Text('Open in WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      // Regenerate
                      Center(
                        child: TextButton.icon(
                          onPressed: _generate,
                          icon: const Icon(Icons.refresh, size: 16, color: AppColors.muted),
                          label: const Text('Regenerate', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
