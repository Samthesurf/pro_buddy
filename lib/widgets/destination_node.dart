import 'package:flutter/material.dart';
import '../core/semantic_colors.dart';
import '../models/goal_journey.dart';

class DestinationNode extends StatelessWidget {
  final GoalJourney journey;

  const DestinationNode({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepsAway = journey.stepsToDestination;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: theme.destinationGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.errorColor.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_pin, color: Colors.white, size: 24),
                  SizedBox(width: 4),
                  Text(
                    'DESTINATION',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Icon(Icons.flag_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(
                journey.goalContent,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            stepsAway == 0
                ? '🎉 You made it!'
                : '$stepsAway step${stepsAway > 1 ? 's' : ''} away',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
