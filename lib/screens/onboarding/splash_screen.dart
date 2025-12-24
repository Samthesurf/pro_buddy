import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../bloc/auth_cubit.dart';
import '../../bloc/auth_state.dart';
import '../../core/routes.dart';
import '../../services/onboarding_storage.dart';
import '../../widgets/onboarding_button.dart';

/// Dramatic splash screen with hawk imagery.
class OnboardingSplashScreen extends StatefulWidget {
  const OnboardingSplashScreen({super.key});

  @override
  State<OnboardingSplashScreen> createState() => _OnboardingSplashScreenState();
}

class _OnboardingSplashScreenState extends State<OnboardingSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  static const List<String> _taglineSteps = [
    'For',
    'For those',
    'For those who',
    'For those who want to achieve their goals!',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    // Start the sequence after layout to ensure the animation always plays.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _beginOnboarding() {
    Navigator.of(context).pushNamed(AppRoutes.onboardingQuiz);
  }

  Future<void> _skipOnboarding() async {
    await OnboardingStorage.setHasSeenOnboarding(true);
    if (!mounted) return;

    final authStatus = context.read<AuthCubit>().state.status;
    final targetRoute =
        authStatus == AuthStatus.authenticated ? AppRoutes.dashboard : AppRoutes.signIn;

    Navigator.of(context).pushNamedAndRemoveUntil(
      targetRoute,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar light for dark background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image
          Positioned.fill(
            child: Image.asset(
              'assets/images/onboarding/hawk_hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Hawk Buddy',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _skipOnboarding,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  child: const Text('Skip'),
                                ),
                              ],
                            ),
                          ),

                          // Bottom
                          Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tagline
                                FadeTransition(
                                  opacity: _fadeIn,
                                  child: SlideTransition(
                                    position: _slideUp,
                                    child: AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, _) {
                                        final progress = _controller.value;
                                        final stepIndex = (progress * _taglineSteps.length)
                                            .floor()
                                            .clamp(0, _taglineSteps.length - 1);
                                        final animatedText = _taglineSteps[stepIndex];

                                        return Text(
                                          animatedText,
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                            fontStyle: FontStyle.italic,
                                            letterSpacing: 0.5,
                                            height: 1.3,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // Begin button
                                FadeTransition(
                                  opacity: _fadeIn,
                                  child: OnboardingButton(
                                    label: 'Begin',
                                    onPressed: _beginOnboarding,
                                    isDark: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
