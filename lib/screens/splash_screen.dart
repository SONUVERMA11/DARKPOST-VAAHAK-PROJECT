import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/encryption_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'INITIALIZING...';
  double _progress = 0;

  final _steps = [
    'GENERATING KEYPAIR...',
    'SEEDING ENTROPY...',
    'BUILDING MESH TABLE...',
    'LOADING SIGNAL PROTOCOL...',
    'READY.',
  ];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await EncryptionService().initialize();

    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _status = _steps[i];
          _progress = (i + 1) / _steps.length;
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),

            // Logo
            Text(
              'DARKPOST',
              style: TextStyle(
                fontFamily: 'ShareTechMono',
                fontSize: 48,
                fontWeight: FontWeight.w400,
                color: AppTheme.primary,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, end: 0),

            const SizedBox(height: 8),

            Text(
              'OFFLINE · ENCRYPTED · FREE',
              style: AppTheme.mono(color: AppTheme.textMuted, size: 12),
            ).animate(delay: 400.ms).fadeIn(),

            const Spacer(flex: 2),

            // Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppTheme.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 2,
              ),
            ).animate(delay: 200.ms).fadeIn(),

            const SizedBox(height: 16),

            Text(
              _status,
              style: AppTheme.mono(color: AppTheme.primary, size: 12),
            ).animate(key: ValueKey(_status)).fadeIn(duration: 300.ms),

            const Spacer(),

            Text(
              'v1.0.0 · NO INTERNET · NO SIM',
              style: AppTheme.mono(color: AppTheme.textMuted, size: 10),
            ).animate(delay: 600.ms).fadeIn(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
