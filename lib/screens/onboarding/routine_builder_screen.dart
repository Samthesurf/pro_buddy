import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/routes.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/onboarding_button.dart';

/// Routine builder screen with image card grid.
class OnboardingRoutineBuilderScreen extends StatefulWidget {
  const OnboardingRoutineBuilderScreen({super.key});

  @override
  State<OnboardingRoutineBuilderScreen> createState() => _OnboardingRoutineBuilderScreenState();
}

class _OnboardingRoutineBuilderScreenState extends State<OnboardingRoutineBuilderScreen> {
  String _selectedCategory = 'All';
  final Set<String> _selectedHabits = {};
  OnboardingData? _previousData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is OnboardingData && _previousData == null) {
      _previousData = args;
    }
  }

  void _toggleHabit(String id) {
    setState(() {
      if (_selectedHabits.contains(id)) {
        _selectedHabits.remove(id);
      } else {
        _selectedHabits.add(id);
      }
    });
  }

  void _createPlan() {
    final data = (_previousData ?? OnboardingData()).copyWith(
      selectedHabits: _selectedHabits.toList(),
    );
    
    // Navigate to sign up with all onboarding data
    Navigator.of(context).pushNamed(
      AppRoutes.signUp,
      arguments: {
        'onboarding_data': data.toJson(),
      },
    );
  }

  List<Habit> get _filteredHabits => OnboardingHabits.byCategory(_selectedCategory);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
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
                    color: Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.black87,
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
                'Build Your Routine',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Select 3+ daily habits to start with',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Category filters
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: OnboardingHabits.categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final category = OnboardingHabits.categories[index];
                  final isSelected = category == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.black 
                              : Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Habits grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _filteredHabits.length,
                itemBuilder: (context, index) {
                  final habit = _filteredHabits[index];
                  return HabitCard(
                    name: habit.name,
                    imagePath: habit.imagePath,
                    isSelected: _selectedHabits.contains(habit.id),
                    onTap: () => _toggleHabit(habit.id),
                  );
                },
              ),
            ),
            
            // Create plan button
            Padding(
              padding: const EdgeInsets.all(24),
              child: OnboardingButton(
                label: 'Create My Plan${_selectedHabits.isNotEmpty ? ' (${_selectedHabits.length})' : ''}',
                onPressed: _createPlan,
                isDark: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

