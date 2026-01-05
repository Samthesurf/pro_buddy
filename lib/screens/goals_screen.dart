import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/goal_journey_cubit.dart';
import '../core/routes.dart';
import '../core/semantic_colors.dart';
import '../models/goal_journey.dart';
import '../services/api_service.dart';
import '../widgets/goal_adjustment_sheet.dart';
import '../widgets/goal_progress_dialog.dart';
import 'goal_journey_screen.dart';

/// Goals screen - replaces UsageHistoryScreen in the navigation
/// Shows either an empty state prompting to start a journey,
/// or a summary of the current journey with quick actions.
///
/// This screen is theme-aware and works with both Cozy and Material themes.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _GoalsScreenContent();
  }
}

class _GoalsScreenContent extends StatelessWidget {
  const _GoalsScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<GoalJourneyCubit, GoalJourneyState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<GoalJourneyCubit>().clearError();
          }
        },
        builder: (context, state) {
          if (state.isLoading && !state.hasJourney) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasJourney) {
            return _buildActiveJourneyView(context, state);
          }

          return _buildEmptyState(context, state);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, GoalJourneyState state) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 100,
          floating: true,
          pinned: true,
          backgroundColor: theme.colorScheme.surface,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            title: Text(
              'Goals',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.1),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyGoalsContent(
            isGenerating: state.isGenerating,
            onStartJourney: () => _showGoalConfirmationDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveJourneyView(BuildContext context, GoalJourneyState state) {
    final theme = Theme.of(context);
    final journey = state.journey!;
    final eta = state.etaData;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160,
          floating: true,
          pinned: true,
          backgroundColor: theme.colorScheme.surface,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showJourneyOptions(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            title: Text(
              'Goal Journey',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.15),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildGoalCard(context, journey),
              const SizedBox(height: 16),
              _buildProgressCard(context, journey, eta),
              const SizedBox(height: 16),
              if (journey.currentStep != null)
                _buildCurrentStepCard(context, journey.currentStep!),
              const SizedBox(height: 16),
              _buildViewJourneyButton(context, journey),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalJourney journey) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: theme.goalCardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '🎯 Your Destination',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            journey.goalContent,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (journey.goalReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Because: ${journey.goalReason}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    GoalJourney journey,
    ETAData? eta,
  ) {
    final theme = Theme.of(context);
    final progress = journey.overallProgress;
    final progressPercent = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.outlineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Journey Progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$progressPercent%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.successColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.outlineColor,
              valueColor: AlwaysStoppedAnimation<Color>(theme.successColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.check_circle_outline,
                  label: 'Completed',
                  value:
                      '${journey.completedSteps.length}/${journey.mainPath.length}',
                  color: theme.successColor,
                ),
              ),
              Container(width: 1, height: 40, color: theme.outlineColor),
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: Icons.schedule,
                  label: 'ETA',
                  value: eta?.displayText ?? 'Calculating...',
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.mutedTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard(BuildContext context, GoalStep step) {
    final theme = Theme.of(context);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (step.status) {
      case StepStatus.inProgress:
        statusColor = theme.warningColor;
        statusIcon = Icons.play_circle_filled;
        statusText = 'In Progress';
        break;
      case StepStatus.available:
        statusColor = theme.primaryColor;
        statusIcon = Icons.radio_button_unchecked;
        statusText = 'Ready to Start';
        break;
      default:
        statusColor = theme.mutedTextColor;
        statusIcon = Icons.circle_outlined;
        statusText = 'Current Step';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Step',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.mutedTextColor,
                    ),
                  ),
                  Text(
                    statusText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '~${step.estimatedDays} days',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.mutedTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            step.displayTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (step.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              step.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.mutedTextColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (step.status == StepStatus.available)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        context.read<GoalJourneyCubit>().startCurrentStep(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Step'),
                  ),
                )
              else if (step.status == StepStatus.inProgress) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => GoalProgressDialog.show(context, step),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Log Progress'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<GoalJourneyCubit>().completeCurrentStep(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.successColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewJourneyButton(BuildContext context, GoalJourney journey) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<GoalJourneyCubit>(),
                child: const GoalJourneyScreen(),
              ),
            ),
          );
        },
        icon: const Icon(Icons.map_outlined),
        label: const Text('View Full Journey Map'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _showGoalConfirmationDialog(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? profileData;
    String? error;

    try {
      // Load the goal from the API (same as settings screen)
      profileData = await ApiService.instance.getNotificationProfile();

      // Handle potential nesting of profile data (like settings_screen.dart does)
      if (profileData.containsKey('profile') && profileData['profile'] is Map) {
        profileData = Map<String, dynamic>.from(profileData['profile'] as Map);
      }
    } catch (e) {
      error = e.toString();
    }

    if (!context.mounted) return;

    // Dismiss loading indicator
    Navigator.of(context).pop();

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load goal: $error')));
      return;
    }

    // Try both snake_case and camelCase (like settings screen does)
    final primaryGoal =
        (profileData?['primary_goal'] as String?) ??
        (profileData?['primaryGoal'] as String?);
    final why =
        (profileData?['why'] as String?) ?? (profileData?['reason'] as String?);

    // If no profile or goal exists, redirect to goal discovery
    if (primaryGoal == null || primaryGoal.trim().isEmpty) {
      final shouldGoToDiscovery = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Text('🎯 '), Text('Set Your Goal')]),
          content: const Text(
            'You haven\'t set a goal yet during onboarding. '
            'Would you like to go through the goal discovery process?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Set My Goal'),
            ),
          ],
        ),
      );

      if (shouldGoToDiscovery == true && context.mounted) {
        Navigator.of(context).pushNamed(AppRoutes.goalDiscovery);
      }
      return;
    }

    final theme = Theme.of(context);
    final goalContent = primaryGoal;
    final goalReason = why;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                '🎯 Your Main Goal',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Goal Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor.withValues(alpha: 0.1),
                      theme.colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // Goal text
                    Text(
                      goalContent,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Reason (if exists)
                    if (goalReason != null && goalReason.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Divider(color: theme.dividerColor),
                      const SizedBox(height: 12),
                      Text(
                        'Because $goalReason',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('change'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Change'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop('proceed'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Start Journey'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == 'change') {
      // Navigate to goal discovery to set a new goal
      Navigator.of(context).pushNamed(AppRoutes.goalDiscovery);
    } else if (result == 'proceed') {
      // Generate journey with the goal from onboarding
      context.read<GoalJourneyCubit>().generateJourney(
        goalContent: goalContent,
        goalReason: goalReason,
      );
    }
  }

  void _showJourneyOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Adjust Journey'),
              subtitle: const Text('Tell AI what you\'re working on'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                GoalAdjustmentSheet.show(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.errorColor),
              title: Text(
                'Delete Journey',
                style: TextStyle(color: theme.errorColor),
              ),
              subtitle: const Text('Start fresh with a new journey'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Journey?'),
                    content: const Text(
                      'This will permanently delete your current journey. '
                      'You can start a new one anytime.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.errorColor,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  context.read<GoalJourneyCubit>().deleteJourney();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for when no journey exists
class _EmptyGoalsContent extends StatelessWidget {
  const _EmptyGoalsContent({
    required this.isGenerating,
    required this.onStartJourney,
  });

  final bool isGenerating;
  final VoidCallback onStartJourney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration placeholder
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.terrain_rounded,
                  size: 80,
                  color: theme.primaryColor.withValues(alpha: 0.5),
                ),
                Positioned(
                  top: 50,
                  child: Icon(
                    Icons.flag_rounded,
                    size: 40,
                    color: theme.primaryColor,
                  ),
                ),
                Positioned(
                  bottom: 60,
                  left: 70,
                  child: Icon(
                    Icons.directions_walk_rounded,
                    size: 32,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Are you ready to commit\nto your dreams?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Start your journey toward your goal with\nAI-powered guidance every step of the way.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.mutedTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGenerating ? null : onStartJourney,
              icon: isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(
                isGenerating ? 'Creating Your Journey...' : 'Choose Your Goal',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '✨ Your journey will be personalized based on your goal',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.mutedTextColor,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
