import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/routes.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/circular_gauge.dart';
import '../../widgets/onboarding_button.dart';
import '../../widgets/onboarding_progress_bar.dart';

/// Quiz screen with circular gauge and multiple question types.
class OnboardingQuizScreen extends StatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  State<OnboardingQuizScreen> createState() => _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends State<OnboardingQuizScreen> {
  int _currentQuestion = 0;
  
  // Quiz answers
  double _distractionHours = 2.0;
  double _focusDuration = 30.0; // minutes
  int _goalClarity = 5;
  String _productiveTime = 'Morning';
  String _checkInFrequency = 'Daily';

  static const int _totalQuestions = 5;

  void _nextQuestion() {
    if (_currentQuestion < _totalQuestions - 1) {
      setState(() => _currentQuestion++);
    } else {
      _finishQuiz();
    }
  }

  void _previousQuestion() {
    if (_currentQuestion > 0) {
      setState(() => _currentQuestion--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skipQuiz() {
    _finishQuiz();
  }

  void _finishQuiz() {
    final data = OnboardingData(
      distractionHours: _distractionHours,
      focusDurationMinutes: _focusDuration,
      goalClarity: _goalClarity,
      productiveTime: _productiveTime,
      checkInFrequency: _checkInFrequency,
    );
    Navigator.of(context).pushNamed(
      AppRoutes.onboardingChallenges,
      arguments: data,
    );
  }

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}hr';
    }
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}min';
    return '${h}h ${m}m';
  }

  String _formatMinutes(double minutes) {
    if (minutes >= 60) {
      final h = (minutes / 60).floor();
      final m = (minutes % 60).round();
      if (m == 0) return '${h}hr';
      return '${h}h ${m}m';
    }
    return '${minutes.toInt()}min';
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
              Color(0xFF1A4CFF),
              Color(0xFF0D2B99),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                
                // Header with back button and progress
                _buildHeader(),
                
                const SizedBox(height: 24),
                
                // Question content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildQuestion(_currentQuestion),
                  ),
                ),
                
                // Next button
                OnboardingButton(
                  label: _currentQuestion < _totalQuestions - 1 ? 'Next' : 'Continue',
                  onPressed: _nextQuestion,
                  isDark: false,
                ),
                
                const SizedBox(height: 16),
                
                // Skip button
                OnboardingTextButton(
                  label: 'Skip Quiz',
                  onPressed: _skipQuiz,
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Back button
        GestureDetector(
          onTap: _previousQuestion,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Progress bar
        Expanded(
          child: OnboardingProgressBar(
            progress: (_currentQuestion + 1) / _totalQuestions,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Placeholder for symmetry (could add language selector like reference)
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildQuestion(int index) {
    switch (index) {
      case 0:
        return _buildGaugeQuestion(
          key: const ValueKey('q0'),
          questionNumber: 1,
          question: 'How many hours a day do you lose to distracting apps?',
          value: _distractionHours,
          maxValue: 8,
          label: _formatHours(_distractionHours),
          onChanged: (v) => setState(() => _distractionHours = v),
          min: 0,
          max: 8,
          divisions: 16,
        );
      case 1:
        return _buildGaugeQuestion(
          key: const ValueKey('q1'),
          questionNumber: 2,
          question: 'How long can you focus before checking your phone?',
          value: _focusDuration,
          maxValue: 120,
          label: _formatMinutes(_focusDuration),
          onChanged: (v) => setState(() => _focusDuration = v),
          min: 5,
          max: 120,
          divisions: 23,
        );
      case 2:
        return _buildGaugeQuestion(
          key: const ValueKey('q2'),
          questionNumber: 3,
          question: 'How clear are you on your main goal right now?',
          value: _goalClarity.toDouble(),
          maxValue: 10,
          label: '$_goalClarity/10',
          onChanged: (v) => setState(() => _goalClarity = v.round()),
          min: 1,
          max: 10,
          divisions: 9,
        );
      case 3:
        return _buildChipQuestion(
          key: const ValueKey('q3'),
          questionNumber: 4,
          question: 'When are you most productive?',
          options: const ['Morning', 'Afternoon', 'Evening', 'Night'],
          selected: _productiveTime,
          onSelected: (v) => setState(() => _productiveTime = v),
        );
      case 4:
        return _buildChipQuestion(
          key: const ValueKey('q4'),
          questionNumber: 5,
          question: 'How often do you want Hawk Buddy to check in?',
          options: const ['Multiple times daily', 'Daily', 'Weekly'],
          selected: _checkInFrequency,
          onSelected: (v) => setState(() => _checkInFrequency = v),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGaugeQuestion({
    required Key key,
    required int questionNumber,
    required String question,
    required double value,
    required double maxValue,
    required String label,
    required ValueChanged<double> onChanged,
    required double min,
    required double max,
    required int divisions,
  }) {
    return Column(
      key: key,
      children: [
        // Question header
        Text(
          'Question #$questionNumber',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          question,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        
        const Spacer(),
        
        // Gauge
        CircularGaugeWidget(
          value: value,
          maxValue: maxValue,
          label: label,
          size: 240,
        ),
        
        const Spacer(),
        
        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChipQuestion({
    required Key key,
    required int questionNumber,
    required String question,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      key: key,
      children: [
        // Question header
        Text(
          'Question #$questionNumber',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          question,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 48),
        
        // Options
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: options.map((option) {
            final isSelected = option == selected;
            return GestureDetector(
              onTap: () => onSelected(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF1A4CFF) : Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        
        const Spacer(),
      ],
    );
  }
}

