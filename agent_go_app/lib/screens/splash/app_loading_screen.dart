import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme/app_colors.dart';
import '../../services/notification_service.dart';

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermissions();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'AgentGo',
              style: GoogleFonts.outfit(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your LIC Business Partner',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 60),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const TimerText(),
          ],
        ),
      ),
    );
  }
}

class TimerText extends StatefulWidget {
  const TimerText({super.key});

  @override
  State<TimerText> createState() => _TimerTextState();
}

class _TimerTextState extends State<TimerText> {
  String _text = 'Initializing...';
  int _index = 0;
  final List<String> _steps = [
    'Initializing...',
    'Checking credentials...',
    'Verifying subscription...',
    'Loading business data...',
    'Optimizing experience...',
  ];

  @override
  void initState() {
    super.initState();
    _startRotation();
  }

  void _startRotation() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _index = (_index + 1) % _steps.length;
          _text = _steps[_index];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        _text,
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: Colors.white54,
        ),
      ),
    );
  }
}
