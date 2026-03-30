import 'dart:ui';
import 'dart:math' as math;
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
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermissions();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Light background
      body: Stack(
        children: [
          // Background Gradient Orbs (Top Right)
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15), // Lime orb
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Background Gradient Orbs (Bottom Center)
          Positioned(
            bottom: -150,
            left: -50,
            right: -50,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.08), // Subtle blue orb
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Glassmorphism Blur Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Main Layout
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  
                  // App Icon Section
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 5,
                                offset: const Offset(0, 15),
                            )
                          ],
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.1), 
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(34),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Brand Title
                  Text(
                    'AgentGo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: AppColors.secondary,
                      letterSpacing: 2.5,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Badge Subtitle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.secondary.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'Your LIC Business Partner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.secondary, // Premium Dark Green
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Bottom Progress Bar Section
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: _PremiumLoader(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom sleek status loader instead of standard circular spinner
class _PremiumLoader extends StatefulWidget {
  const _PremiumLoader();

  @override
  State<_PremiumLoader> createState() => _PremiumLoaderState();
}

class _PremiumLoaderState extends State<_PremiumLoader> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  String _text = 'Initializing secure connection...';
  int _index = 0;
  final List<String> _steps = [
    'Initializing secure connection...',
    'Checking access credentials...',
    'Loading business dashboard...',
    'Optimizing user experience...',
    'Ready!',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
        vsync: this, 
        duration: const Duration(milliseconds: 3500)
    )..forward();
    _startRotation();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _startRotation() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && _index < _steps.length - 1) {
        setState(() {
          _index += 1;
          _text = _steps[_index];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const barWidth = 220.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _progressController,
          builder: (context, child) {
            final value = _progressController.value;
            
            return SizedBox(
              width: barWidth,
              height: 40, // increased height allocation for the icon
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomLeft,
                children: [
                  // Walking Man Icon
                  Positioned(
                    left: value * (barWidth - 24), // moving x
                    bottom: 12, // stable y 
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: AppColors.secondary,
                      size: 26,
                    ),
                  ),

                  // Progress Bar Background
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Progress Bar Fill
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          _text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
