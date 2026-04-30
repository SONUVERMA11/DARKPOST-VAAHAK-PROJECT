import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/p2p_service.dart';
import '../services/encryption_service.dart';

class ChatScreen extends StatefulWidget {
  final DarkNode node;
  const ChatScreen({super.key, required this.node});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _p2p = P2PService();
  final _enc = EncryptionService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<DarkMessage> _messages = [];
  bool _sending = false;
  bool _showEncrypted = false;
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    
    // Load historical messages from Hive
    final box = Hive.box('messagesBox');
    final history = box.values
        .map((e) => DarkMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((m) => m.toId == widget.node.id || m.fromId == widget.node.id)
        .toList();
        
    history.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messages.addAll(history);

    _msgSub = _p2p.messageStream.listen((msg) {
      if (msg.fromId == widget.node.id || msg.toId == widget.node.id) {
        setState(() => _messages.add(msg));
        _scrollDown();
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollDown();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _requestPayment() async {
    final myUpi = Hive.box('identityBox').get('upi_id', defaultValue: '');
    if (myUpi == null || myUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PLEASE CONFIGURE UPI ID IN IDENTITY SCREEN', style: AppTheme.mono(color: AppTheme.bg, size: 12)),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text('REQUEST PAYMENT', style: AppTheme.mono(color: AppTheme.primary, size: 14)),
        content: TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Amount (INR)',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: AppTheme.mono(color: AppTheme.textMuted, size: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, amountCtrl.text.trim()),
            child: Text('SEND', style: AppTheme.mono(color: AppTheme.primary, size: 12)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && double.tryParse(result) != null) {
      _controller.text = 'PAYMENT_REQ|$myUpi|$result';
      _send();
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final encrypted = _enc.encryptFor(text, widget.node.publicKeyHex);
    final msg = DarkMessage.create(
      fromId: 'self',
      toId: widget.node.id,
      text: text,
      encrypted: encrypted,
      isMine: true,
    );

    setState(() {
      _messages.add(msg);
      _sending = true;
    });
    _controller.clear();
    _scrollDown();

    final success = await _p2p.sendMessage(msg);
    setState(() {
      _sending = false;
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx >= 0) {
        _messages[idx] = DarkMessage(
          id: msg.id,
          fromId: msg.fromId,
          toId: msg.toId,
          encryptedPayload: msg.encryptedPayload,
          decryptedText: msg.decryptedText,
          timestamp: msg.timestamp,
          status: success ? MessageStatus.delivered : MessageStatus.failed,
          isMine: true,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppTheme.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.node.alias,
              style: AppTheme.mono(
                  color: AppTheme.textPrimary,
                  size: 14,
                  weight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              widget.node.shortId,
              style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showEncrypted ? Icons.lock : Icons.lock_open,
              color: _showEncrypted ? AppTheme.primary : AppTheme.textMuted,
              size: 18,
            ),
            onPressed: () =>
                setState(() => _showEncrypted = !_showEncrypted),
            tooltip: 'Toggle encrypted view',
          ),
        ],
      ),
      body: Column(
        children: [
          // Encryption status bar
          _EncryptionBar(nodeAlias: widget.node.alias),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _WaitingState()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(
                      message: _messages[i],
                      showEncrypted: _showEncrypted,
                    ),
                  ),
          ),

          // Input
          _InputBar(
            controller: _controller,
            sending: _sending,
            onSend: _send,
            onRequestPayment: _requestPayment,
          ),
        ],
      ),
    );
  }
}

class _EncryptionBar extends StatelessWidget {
  final String nodeAlias;
  const _EncryptionBar({required this.nodeAlias});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primary.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(Icons.lock, color: AppTheme.primary, size: 12),
          const SizedBox(width: 8),
          Text(
            'AES-256 END-TO-END ENCRYPTED',
            style: AppTheme.mono(color: AppTheme.primary, size: 10),
          ),
          const Spacer(),
          Text(
            'OFFLINE',
            style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DarkMessage message;
  final bool showEncrypted;

  const _MessageBubble({
    required this.message,
    required this.showEncrypted,
  });

  Widget _buildPaymentCard(String upiId, String amount, bool isMine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppTheme.accent, size: 16),
            const SizedBox(width: 6),
            Text('PAYMENT REQUEST', style: AppTheme.mono(color: AppTheme.accent, size: 10)),
          ],
        ),
        const SizedBox(height: 12),
        Text('₹$amount', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('To: $upiId', style: AppTheme.mono(color: AppTheme.textMuted, size: 10)),
        if (!isMine) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final uri = Uri.parse('upi://pay?pa=$upiId&pn=DarkpostNode&am=$amount&cu=INR');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: Text('PAY NOW', style: AppTheme.mono(size: 12, weight: FontWeight.bold)),
            ),
          ),
        ]
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final text = showEncrypted
        ? message.encryptedPayload.substring(
            0, message.encryptedPayload.length.clamp(0, 40))
        : (message.decryptedText ?? '[ENCRYPTED]');

    final isPaymentReq = text.startsWith('PAYMENT_REQ|');
    String upiId = '';
    String amount = '';
    if (isPaymentReq) {
      final parts = text.split('|');
      if (parts.length >= 3) {
        upiId = parts[1];
        amount = parts[2];
      }
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: AppTheme.glowBox(
                glowColor: isMine
                    ? AppTheme.primary
                    : (isPaymentReq ? AppTheme.accent : AppTheme.surfaceHigh),
                glowBlur: isMine || isPaymentReq ? 8 : 0,
              ).copyWith(
                color: isMine ? AppTheme.primary.withOpacity(0.1) : AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: !isMine ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: isPaymentReq 
                ? _buildPaymentCard(upiId, amount, isMine)
                : Text(
                  text,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                    fontFamily: showEncrypted ? 'ShareTechMono' : null,
                  ),
                ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.status == MessageStatus.sending
                        ? Icons.access_time
                        : (message.status == MessageStatus.failed
                            ? Icons.error_outline
                            : Icons.check),
                    size: 10,
                    color: message.status == MessageStatus.failed
                        ? AppTheme.warning
                        : AppTheme.textMuted,
                  ),
                ]
              ],
            ),
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onRequestPayment;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onRequestPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onRequestPayment,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.currency_rupee, color: AppTheme.accent, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              cursorColor: AppTheme.primary,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppTheme.surfaceHigh,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.primary.withOpacity(0.4), width: 1),
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(Icons.send, color: AppTheme.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 36),
          const SizedBox(height: 12),
          Text(
            'ESTABLISHING SECURE CHANNEL',
            style: AppTheme.mono(color: AppTheme.textMuted, size: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Messages are end-to-end encrypted',
            style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
          ),
        ],
      ).animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn().then(delay: 1500.ms).fadeOut(),
    );
  }
}
