import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/utils/preferences_helper.dart';
import '../../data/repositories/auth_service.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Simple fade-in animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    // Navigate after delay
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Minimal delay - just enough for splash animation to be visible
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Determine which screen to show
    final needsAuth = AuthService.isAppLockEnabled();
    final isOnboardingComplete = PreferencesHelper.isOnboardingComplete();

    Widget nextScreen;
    
    if (needsAuth) {
      // Show auth screen first
      final authResult = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => const AuthScreen(),
          fullscreenDialog: true,
        ),
      );
      
      if (authResult != true && mounted) {
        // Auth failed, stay on splash or exit
        return;
      }
      
      // After successful auth, show home or welcome
      nextScreen = isOnboardingComplete ? const HomeScreen() : const WelcomeScreen();
    } else {
      // No auth needed, show home or welcome
      nextScreen = isOnboardingComplete ? const HomeScreen() : const WelcomeScreen();
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => nextScreen),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Image.asset(
            colorScheme.brightness == Brightness.dark
                ? 'assets/Kpit_for_darktheme.png'
                : 'assets/Kpit_for_lighttheme.png',
            width: 120,
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.inventory_2_outlined,
                size: 100,
                color: colorScheme.primary,
              );
            },
          ),
        ),
      ),
    );
  }
}
