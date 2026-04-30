import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/encryption_service.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  final _upiController = TextEditingController();
  final _box = Hive.box('identityBox');

  @override
  void initState() {
    super.initState();
    _upiController.text = _box.get('upi_id', defaultValue: '');
  }

  void _saveUpi() {
    _box.put('upi_id', _upiController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI ID SAVED', style: AppTheme.mono(color: AppTheme.bg, size: 12)),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enc = EncryptionService();
    final alias = enc.generateAlias();
    final pub = enc.publicKeyHex;
    final fp = enc.shortFingerprint;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppTheme.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MY IDENTITY',
          style: AppTheme.mono(color: AppTheme.textPrimary, size: 14),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Node icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3), width: 1),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppTheme.primary, size: 36),
              ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                alias,
                style: AppTheme.mono(
                    color: AppTheme.textPrimary,
                    size: 18,
                    weight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 32),

            _InfoCard(
              label: 'FINGERPRINT',
              value: fp,
              mono: true,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              label: 'PUBLIC KEY',
              value: '${pub.substring(0, 32)}...',
              mono: true,
              color: AppTheme.accent,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: pub));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'PUBLIC KEY COPIED',
                      style: AppTheme.mono(color: AppTheme.bg, size: 12),
                    ),
                    backgroundColor: AppTheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // UPI ID CONFIGURATION
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glowBox(glowColor: AppTheme.primary, glowBlur: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.account_balance_wallet,
                        color: AppTheme.primary, size: 14),
                    const SizedBox(width: 8),
                    Text('UPI PAYMENT ID',
                        style: AppTheme.mono(
                            color: AppTheme.primary, size: 11)),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _upiController,
                          style: AppTheme.mono(color: AppTheme.textPrimary, size: 14),
                          decoration: InputDecoration(
                            hintText: 'e.g. username@upi',
                            hintStyle: AppTheme.mono(color: AppTheme.textMuted, size: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save, color: AppTheme.primary, size: 20),
                        onPressed: _saveUpi,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glowBox(glowColor: AppTheme.warning),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber,
                        color: AppTheme.warning, size: 14),
                    const SizedBox(width: 8),
                    Text('SECURITY NOTICE',
                        style: AppTheme.mono(
                            color: AppTheme.warning, size: 11)),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Your private key is stored locally and never transmitted. '
                    'Your identity is your keypair — no phone number, no account. '
                    'Loss of device means loss of identity.',
                    style: AppTheme.mono(color: AppTheme.textMuted, size: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://github.com/SONUVERMA11');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Column(
                  children: [
                    Text(
                      'DARKPOST v1.0 · NO INTERNET · NO SIM',
                      style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MADE WITH LOVE BY SONU VERMA ❤️',
                      style: AppTheme.mono(color: AppTheme.primary, size: 10, weight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Color color;
  final VoidCallback? onCopy;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.color,
    this.mono = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glowBox(glowColor: color, glowBlur: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      AppTheme.mono(color: AppTheme.textMuted, size: 10),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: mono
                      ? AppTheme.mono(color: color, size: 13)
                      : TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, color: AppTheme.textMuted, size: 16),
              onPressed: onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
