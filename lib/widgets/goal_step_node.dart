import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/goal_journey_cubit.dart';
import '../core/semantic_colors.dart';
import '../models/goal_journey.dart';
import 'current_position_marker.dart';
import 'journey_celebrations.dart';
import 'node_unlock_animation.dart';

class GoalStepNode extends StatelessWidget {
  final GoalStep step;
  final Function(CelebrationType) onCelebration;

  const GoalStepNode({
    super.key,
    required this.step,
    required this.onCelebration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = step.status == StepStatus.inProgress;
    final isCompleted = step.status == StepStatus.completed;
    final isAvailable = step.status == StepStatus.available;
    final isLocked = step.status == StepStatus.locked;

    Color nodeColor;
    Color lineColor;
    IconData nodeIcon;

    if (isCompleted) {
      nodeColor = theme.successColor;
      lineColor = theme.successColor;
      nodeIcon = Icons.check_rounded;
    } else if (isCurrent) {
      nodeColor = theme.warningColor;
      lineColor = theme.outlineColor;
      nodeIcon = Icons.person_pin_circle;
    } else if (isAvailable) {
      nodeColor = theme.primaryColor;
      lineColor = theme.outlineColor;
      nodeIcon = Icons.circle_outlined;
    } else {
      nodeColor = theme.mutedTextColor;
      lineColor = theme.outlineColor;
      nodeIcon = Icons.lock_rounded;
    }

    return GestureDetector(
      onTap: step.isUnlocked ? () => _showStepDetails(context) : null,
      child: Column(
        children: [
          NodeUnlockAnimation(
            isUnlocked: step.isUnlocked,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCurrent ? 80 : 70,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: nodeColor.withValues(alpha: isLocked ? 0.3 : 1.0),
                    borderRadius: BorderRadius.circular(16),
                    border: isCurrent
                        ? Border.all(color: nodeColor, width: 3)
                        : null,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: nodeColor.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        nodeIcon,
                        color: isLocked ? nodeColor : Colors.white,
                        size: isCurrent ? 28 : 24,
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  const Positioned(
                    top: -25,
                    child: CurrentPositionMarker(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 150,
            child: Text(
              step.displayTitle,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isLocked
                    ? theme.mutedTextColor
                    : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  void _showStepDetails(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.outlineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildStatusBadge(context, step.status),
              const SizedBox(height: 16),
              Text(
                step.displayTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: theme.mutedTextColor),
                  const SizedBox(width: 4),
                  Text(
                    'Estimated: ${step.estimatedDays} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.mutedTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (step.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(step.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              if (step.notes.isNotEmpty) ...[
                Text(
                  'Your Notes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...step.notes.map(
                  (note) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surfaceVariantColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(note),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (step.status == StepStatus.available)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<GoalJourneyCubit>().updateStepStatus(
                            stepId: step.id,
                            status: StepStatus.inProgress,
                          );
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Start This Step'),
                  ),
                )
              else if (step.status == StepStatus.inProgress)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<GoalJourneyCubit>().updateStepStatus(
                            stepId: step.id,
                            status: StepStatus.completed,
                          );
                      Navigator.of(sheetContext).pop();
                      // Trigger celebration
                      onCelebration(CelebrationType.stepCompleted);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.successColor,
                    ),
                    child: const Text('Mark as Complete'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, StepStatus status) {
    final theme = Theme.of(context);

    Color color;
    String text;
    IconData icon;

    switch (status) {
      case StepStatus.completed:
        color = theme.successColor;
        text = 'Completed';
        icon = Icons.check_circle;
        break;
      case StepStatus.inProgress:
        color = theme.warningColor;
        text = 'In Progress';
        icon = Icons.timelapse;
        break;
      case StepStatus.available:
        color = theme.primaryColor;
        text = 'Available';
        icon = Icons.radio_button_unchecked;
        break;
      case StepStatus.locked:
        color = theme.mutedTextColor;
        text = 'Locked';
        icon = Icons.lock;
        break;
      case StepStatus.skipped:
        color = theme.mutedTextColor;
        text = 'Skipped';
        icon = Icons.skip_next;
        break;
      case StepStatus.alternative:
        color = theme.mutedTextColor;
        text = 'Alternative';
        icon = Icons.alt_route;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
