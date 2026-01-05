import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/goal_journey_cubit.dart';
import '../core/semantic_colors.dart';
import '../models/goal_journey.dart';
import '../widgets/current_position_marker.dart';
import '../widgets/destination_node.dart';
import '../widgets/goal_adjustment_sheet.dart';
import '../widgets/goal_progress_dialog.dart';
import '../widgets/goal_step_node.dart';
import '../widgets/journey_celebrations.dart';
import '../widgets/path_draw_animation.dart';

/// Full interactive journey map screen
/// Displays the pannable/zoomable game-like map with all steps.
///
/// This screen is theme-aware and works with both Cozy and Material themes.
class GoalJourneyScreen extends StatefulWidget {
  const GoalJourneyScreen({super.key});

  @override
  State<GoalJourneyScreen> createState() => _GoalJourneyScreenState();
}

class _GoalJourneyScreenState extends State<GoalJourneyScreen> {
  final TransformationController _transformationController =
      TransformationController();
  CelebrationType? _activeCelebration;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: const Text('Journey Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _centerOnCurrentStep,
            tooltip: 'Center on current step',
          ),
        ],
      ),
      body: BlocConsumer<GoalJourneyCubit, GoalJourneyState>(
        listener: (context, state) {
          // Check for celebrations
          // Logic: If a step was just completed, show step celebration
          // If overall progress reached a milestone, show milestone celebration
          // For now, we'll just check if the last action completed a step
          // This logic would ideally be driven by specific events from the Cubit
          // But checking progress changes is a decent proxy
        },
        builder: (context, state) {
          final journey = state.journey;
          if (journey == null) {
            return const Center(child: Text('No journey found'));
          }

          return Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context, journey, state.etaData),
                  Expanded(child: _buildJourneyMap(context, journey, state)),
                  _buildBottomActionBar(context, journey),
                ],
              ),
              if (_activeCelebration != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: JourneyCelebration(
                      type: _activeCelebration!,
                      onFinished: () {
                        setState(() {
                          _activeCelebration = null;
                        });
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GoalJourney journey, ETAData? eta) {
    final theme = Theme.of(context);
    final progress = journey.overallProgress;
    final progressPercent = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, color: theme.errorColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  journey.goalContent,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: theme.outlineColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.successColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$progressPercent%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (eta != null)
            Text(
              eta.displayText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.mutedTextColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJourneyMap(
    BuildContext context,
    GoalJourney journey,
    GoalJourneyState state,
  ) {
    return InteractiveViewer(
      transformationController: _transformationController,
      boundaryMargin: const EdgeInsets.all(100),
      minScale: 0.5,
      maxScale: 3.0,
      constrained: false,
      child: Container(
        width: 400,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          children: [
            _buildStartMarker(context),
            ...journey.mainPath.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              // Only animate if this is a fresh load (optional optimization, but good for UX)
              // For now we animate every time the map builds which might be too much if it rebuilds often.
              // However, PathDrawAnimation is stateful and will only run once on init.
              return PathDrawAnimation(
                delay: Duration(milliseconds: index * 200),
                child: GoalStepNode(
                  step: step,
                  onCelebration: (type) {
                    setState(() {
                      _activeCelebration = type;
                    });
                  },
                ),
              );
            }),
            DestinationNode(journey: journey),
          ],
        ),
      ),
    );
  }

  Widget _buildStartMarker(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: theme.successColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.successColor.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'START',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.successColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          width: 3,
          height: 40,
          decoration: BoxDecoration(
            color: theme.successColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }



  Widget _buildBottomActionBar(BuildContext context, GoalJourney journey) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final step = context.read<GoalJourneyCubit>().state.journey?.currentStep;
                  if (step != null) {
                    GoalProgressDialog.show(context, step);
                  }
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Log Progress'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => GoalAdjustmentSheet.show(context),
                icon: const Icon(Icons.route_rounded),
                label: const Text('Adjust Path'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnCurrentStep() {
    _transformationController.value = Matrix4.identity();
  }





}
