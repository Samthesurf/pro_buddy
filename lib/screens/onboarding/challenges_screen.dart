import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/routes.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/onboarding_button.dart';

/// Multi-select challenges screen with categorized options.
class OnboardingChallengesScreen extends StatefulWidget {
  const OnboardingChallengesScreen({super.key});

  @override
  State<OnboardingChallengesScreen> createState() => _OnboardingChallengesScreenState();
}

class _OnboardingChallengesScreenState extends State<OnboardingChallengesScreen> {
  final Set<String> _selectedChallenges = {};
  OnboardingData? _previousData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get data from previous screen
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is OnboardingData && _previousData == null) {
      _previousData = args;
    }
  }

  void _toggleChallenge(String id) {
    setState(() {
      if (_selectedChallenges.contains(id)) {
        _selectedChallenges.remove(id);
      } else {
        _selectedChallenges.add(id);
      }
    });
  }

  void _continue() {
    final data = (_previousData ?? OnboardingData()).copyWith(
      selectedChallenges: _selectedChallenges.toList(),
    );
    Navigator.of(context).pushNamed(
      AppRoutes.onboardingRoutine,
      arguments: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A1942),
              Color(0xFF2D0F29),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              
              // Back button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "What's holding you back?",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Select all that apply',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Scrollable challenges list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    for (final category in OnboardingChallenges.categories) ...[
                      _buildCategoryHeader(category),
                      const SizedBox(height: 12),
                      ...OnboardingChallenges.byCategory(category).map(
                        (challenge) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ChallengeOption(
                            challenge: challenge,
                            isSelected: _selectedChallenges.contains(challenge.id),
                            onTap: () => _toggleChallenge(challenge.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 80), // Space for button
                  ],
                ),
              ),
              
              // Continue button
              Padding(
                padding: const EdgeInsets.all(24),
                child: OnboardingButton(
                  label: 'Continue',
                  onPressed: _continue,
                  isDark: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    return Text(
      category,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ChallengeOption extends StatelessWidget {
  const _ChallengeOption({
    required this.challenge,
    required this.isSelected,
    required this.onTap,
  });

  final Challenge challenge;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.white 
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Colors.white 
                : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Emoji
            Text(
              challenge.emoji,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 14),
            
            // Label
            Expanded(
              child: Text(
                challenge.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFF2D0F29) : Colors.white,
                ),
              ),
            ),
            
            // Checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF4A1942) 
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? const Color(0xFF4A1942) 
                      : Colors.white.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

