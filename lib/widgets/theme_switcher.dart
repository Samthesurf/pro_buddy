import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/theme_cubit.dart';

/// A beautiful theme switcher with card-based Light/Dark selection
class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark =
            themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        return Row(
          children: [
            Expanded(
              child: _ThemeCard(
                isSelected: !isDark,
                isDarkCard: false,
                onTap: () =>
                    context.read<ThemeCubit>().setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ThemeCard(
                isSelected: isDark,
                isDarkCard: true,
                onTap: () =>
                    context.read<ThemeCubit>().setThemeMode(ThemeMode.dark),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.isSelected,
    required this.isDarkCard,
    required this.onTap,
  });

  final bool isSelected;
  final bool isDarkCard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Card colors
    final cardBg = isDarkCard ? const Color(0xFF1E1E1E) : Colors.white;
    final lineLightColor = isDarkCard
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE8E8E8);
    final lineDarkColor = isDarkCard
        ? const Color(0xFF4A4A4A)
        : const Color(0xFFD0D0D0);
    final labelColor = isDarkCard ? Colors.white : Colors.black87;
    // Theme-specific accent colors
    final iconColor = isDarkCard
        ? const Color(0xFF818CF8) // Purple for dark theme
        : const Color(0xFFD4915C); // Warm amber for light/cozy theme

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? iconColor : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview area with mock lines
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line 1 - short
                  Container(
                    width: 40,
                    height: 6,
                    decoration: BoxDecoration(
                      color: lineDarkColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Line 2 - long
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: lineLightColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Line 3 - medium
                  Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: lineLightColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Label with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDarkCard ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isDarkCard ? 'Dark' : 'Cozy',
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
