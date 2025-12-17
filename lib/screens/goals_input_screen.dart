import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class GoalsInputScreen extends StatefulWidget {
  const GoalsInputScreen({super.key});

  @override
  State<GoalsInputScreen> createState() => _GoalsInputScreenState();
}

class _GoalsInputScreenState extends State<GoalsInputScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _timelineController = TextEditingController();

  int _pageIndex = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _goalController.dispose();
    _reasonController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  bool _isStepValid(int step) {
    final goal = _goalController.text.trim();
    final reason = _reasonController.text.trim();
    final timeline = _timelineController.text.trim();

    switch (step) {
      case 0:
        return goal.length >= AppConstants.minGoalLength;
      case 1:
        return reason.isNotEmpty;
      case 2:
        return timeline.isNotEmpty;
      default:
        return false;
    }
  }

  void _showValidationMessage(int step) {
    String message;
    switch (step) {
      case 0:
        message =
            'Please tell us what you want to achieve (at least ${AppConstants.minGoalLength} characters).';
      case 1:
        message = 'Please tell us why this is important to you.';
      case 2:
        message = 'Please add a timeline (for example: “3 months”).';
      default:
        message = 'Please answer before continuing.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onPageChanged(int newIndex) {
    if (newIndex > _pageIndex && !_isStepValid(_pageIndex)) {
      _showValidationMessage(_pageIndex);
      _pageController.animateToPage(
        _pageIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    setState(() => _pageIndex = newIndex);
  }

  Future<void> _handlePrimaryAction() async {
    if (_isSaving) return;

    if (!_isStepValid(_pageIndex)) {
      _showValidationMessage(_pageIndex);
      return;
    }

    if (_pageIndex < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await _saveGoals();
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);

    try {
      await ApiService.instance.saveGoals(
        content: _goalController.text.trim(),
        reason: _reasonController.text.trim(),
        timeline: _timelineController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacementNamed(AppRoutes.goalDiscovery);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final orange = AppColors.warning;
    final orangeLight = AppColors.warningLight;

    final primaryLabel = _pageIndex < 2 ? 'Next' : 'Save';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppColors.backgroundDark,
                    AppColors.surfaceDark,
                  ]
                : [
                    Colors.white,
                    orangeLight.withValues(alpha: 0.12),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                pageIndex: _pageIndex,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _QuestionPage(
                      title: 'What do you want to achieve?',
                      subtitle:
                          'Keep it simple. One clear goal is perfect.',
                      controller: _goalController,
                      hintText: 'Example: Finish my portfolio and apply for 10 jobs',
                      multiline: true,
                      icon: Icons.flag_rounded,
                      accent: orange,
                      onEditingComplete: _handlePrimaryAction,
                    ),
                    _QuestionPage(
                      title: 'Why is this important to you?',
                      subtitle:
                          'This will help Hawk Buddy keep you motivated.',
                      controller: _reasonController,
                      hintText: 'Example: It will help me get a better role and support my family',
                      multiline: true,
                      icon: Icons.favorite_rounded,
                      accent: orange,
                      onEditingComplete: _handlePrimaryAction,
                    ),
                    _QuestionPage(
                      title: "What's your timeline?",
                      subtitle:
                          'A deadline helps us keep your plan realistic.',
                      controller: _timelineController,
                      hintText: 'Example: 3 months',
                      multiline: false,
                      icon: Icons.schedule_rounded,
                      accent: orange,
                      suggestions: const ['1 week', '1 month', '3 months', '6 months'],
                      onSuggestion: (value) {
                        _timelineController.text = value;
                        _timelineController.selection = TextSelection.fromPosition(
                          TextPosition(offset: value.length),
                        );
                      },
                      onEditingComplete: _handlePrimaryAction,
                    ),
                  ],
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handlePrimaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      elevation: isDark ? 0 : 3,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(primaryLabel),
                              const SizedBox(width: 10),
                              Icon(
                                _pageIndex < 2
                                    ? Icons.arrow_forward_rounded
                                    : Icons.check_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pageIndex,
    required this.onBack,
  });

  final int pageIndex;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Question ${pageIndex + 1} of 3',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _DotsIndicator(current: pageIndex, count: 3),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.current, required this.count});

  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = AppColors.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(left: 6),
          width: isActive ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? active
                : theme.colorScheme.outline.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.hintText,
    required this.multiline,
    required this.icon,
    required this.accent,
    required this.onEditingComplete,
    this.suggestions,
    this.onSuggestion,
  });

  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String hintText;
  final bool multiline;
  final IconData icon;
  final Color accent;
  final Future<void> Function() onEditingComplete;
  final List<String>? suggestions;
  final ValueChanged<String>? onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, AppColors.warningLight],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            maxLines: multiline ? 5 : 1,
            minLines: multiline ? 3 : 1,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
            decoration: InputDecoration(
              hintText: hintText,
            ),
            onEditingComplete: () => onEditingComplete(),
          ),
          if (suggestions != null && suggestions!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions!
                  .map(
                    (s) => ActionChip(
                      label: Text(s),
                      backgroundColor:
                          theme.colorScheme.surface.withValues(alpha: 0.9),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.6),
                      ),
                      onPressed: () => onSuggestion?.call(s),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.swipe_rounded, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can swipe to move between questions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
