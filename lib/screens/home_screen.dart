import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/p2p_service.dart';
import '../services/encryption_service.dart';
import 'chat_screen.dart';
import 'identity_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final _p2p = P2PService();
  final _enc = EncryptionService();
  List<DarkNode> _nodes = [];
  bool _scanning = false;
  late AnimationController _pulseCtrl;
  StreamSubscription? _nodeSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _nodeSub = _p2p.nodesStream.listen((nodes) {
      if (mounted) setState(() => _nodes = nodes);
    });

    _startScan();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nodeSub?.cancel();
    _p2p.stopScan();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _scanning = true;
      _nodes = [];
    });
    _p2p.startScan();
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted) {
        setState(() => _scanning = false);
        _p2p.stopScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: Row(
          children: [
            Text(
              'DARKPOST',
              style: TextStyle(
                fontFamily: 'ShareTechMono',
                fontSize: 20,
                color: AppTheme.primary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(width: 12),
            _StatusPill(scanning: _scanning),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint, color: AppTheme.textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IdentityScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MyNodeCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'NEARBY NODES',
                  style: AppTheme.mono(
                      color: AppTheme.textMuted, size: 11),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_nodes.length}',
                    style: AppTheme.mono(color: AppTheme.primary, size: 11),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _scanning ? null : _startScan,
                  child: Text(
                    _scanning ? 'SCANNING...' : 'RESCAN',
                    style: AppTheme.mono(
                      color: _scanning
                          ? AppTheme.textMuted
                          : AppTheme.accent,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _nodes.isEmpty
                  ? _EmptyState(scanning: _scanning)
                  : ListView.separated(
                      itemCount: _nodes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _NodeTile(
                        node: _nodes[i],
                        index: i,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(node: _nodes[i]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyNodeCard extends StatelessWidget {
  final _enc = EncryptionService();

  _MyNodeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glowBox(glowColor: AppTheme.primary),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.primary.withOpacity(0.4), width: 1),
            ),
            child: const Icon(Icons.person_outline,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enc.generateAlias(),
                  style: AppTheme.mono(
                      color: AppTheme.textPrimary,
                      size: 14,
                      weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _enc.shortFingerprint,
                  style: AppTheme.mono(color: AppTheme.textMuted, size: 11),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  final DarkNode node;
  final int index;
  final VoidCallback onTap;

  const _NodeTile({
    required this.node,
    required this.index,
    required this.onTap,
  });

  Color get _signalColor {
    if (node.signalStrength > 0.7) return AppTheme.primary;
    if (node.signalStrength > 0.4) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glowBox(
          glowColor: _signalColor,
          glowBlur: 8,
        ),
        child: Row(
          children: [
            // Signal strength bars
            _SignalBars(strength: node.signalStrength, color: _signalColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.alias,
                    style: AppTheme.mono(
                        color: AppTheme.textPrimary,
                        size: 13,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        node.shortId,
                        style: AppTheme.mono(
                            color: AppTheme.textMuted, size: 10),
                      ),
                      if (node.hopCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                                color: AppTheme.accent.withOpacity(0.3),
                                width: 1),
                          ),
                          child: Text(
                            '${node.hopCount} HOP${node.hopCount > 1 ? 'S' : ''}',
                            style: AppTheme.mono(
                                color: AppTheme.accent, size: 9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textMuted, size: 18),
          ],
        ),
      ).animate(delay: (index * 100).ms).fadeIn().slideX(begin: 0.1, end: 0),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final double strength;
  final Color color;

  const _SignalBars({required this.strength, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = strength > (i + 1) / 4;
        return Container(
          width: 4,
          height: 6.0 + i * 4,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? color : AppTheme.border,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool scanning;
  const _StatusPill({required this.scanning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (scanning ? AppTheme.primary : AppTheme.textMuted)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: (scanning ? AppTheme.primary : AppTheme.textMuted)
              .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        scanning ? 'SCANNING' : 'IDLE',
        style: AppTheme.mono(
          color: scanning ? AppTheme.primary : AppTheme.textMuted,
          size: 9,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool scanning;
  const _EmptyState({required this.scanning});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            scanning ? Icons.radar : Icons.wifi_off,
            color: AppTheme.textMuted,
            size: 48,
          ).animate(onPlay: (c) => c.repeat())
            .then(delay: 1000.ms)
            .shimmer(color: AppTheme.primary.withOpacity(0.3), duration: 1500.ms),
          const SizedBox(height: 16),
          Text(
            scanning ? 'SCANNING FOR NODES...' : 'NO NODES FOUND',
            style: AppTheme.mono(color: AppTheme.textMuted, size: 12),
          ),
          const SizedBox(height: 8),
          Text(
            scanning
                ? 'WiFi Direct & Bluetooth active'
                : 'Ensure WiFi & BT are enabled',
            style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
