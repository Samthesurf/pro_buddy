import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/routes.dart';
import '../core/cozy_theme.dart';
import '../bloc/progress_score_cubit.dart';
import '../bloc/progress_streak_cubit.dart';
import '../bloc/onboarding_preferences_cubit.dart';
import '../bloc/daily_usage_summary_cubit.dart';
import '../bloc/usage_history_cubit.dart';
import '../models/usage_feedback.dart';

class CozyDashboardScreen extends StatelessWidget {
  const CozyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style for a cleaner look
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    return Scaffold(
      extendBody:
          true, // Allow body to extend behind FAB/BottomBar if we had one
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<ProgressScoreCubit>().loadLatest(),
            context.read<ProgressStreakCubit>().loadStreak(),
            context.read<OnboardingPreferencesCubit>().loadPreferences(),
            context.read<DailyUsageSummaryCubit>().loadSummary(),
            context.read<UsageHistoryCubit>().loadHistory(limit: 20),
          ]);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGoalAlignmentScore(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Your Progress'),
                    const SizedBox(height: 16),
                    _buildStreakSection(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader(context, 'Time Spent'),
                    const SizedBox(height: 16),
                    _buildTimeAllocation(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  'Recent Activity',
                  action: 'View All',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.usageHistory);
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                100,
              ), // Extra bottom padding for FAB
              sliver: _buildRecentActivity(context),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildModernFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (action != null && onTap != null)
          TextButton(
            onPressed: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(
        context,
      ).scaffoldBackgroundColor.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        expandedTitleScale: 1.3,
        title: Text(
          'Cozy Dashboard',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.notifications),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalAlignmentScore(BuildContext context) {
    final state = context.watch<ProgressScoreCubit>().state;
    final score = state.scorePercent ?? 0;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CozyColors.primary, CozyColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: CozyColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Score',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.dateUtc == null ? 'Today' : 'Today (UTC)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            state.isLoading
                                ? Icons.refresh
                                : Icons.auto_awesome,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            state.isLoading ? 'Updating...' : 'Live',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: GoogleFonts.nunito(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, left: 4),
                      child: Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  (state.reason ?? 'Keep logging to see your score!').trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<ProgressStreakCubit, ProgressStreakState>(
            builder: (context, state) {
              return _buildModernCard(
                context,
                icon: Icons.local_fire_department_rounded,
                value: state.isLoading ? '...' : '${state.streak}',
                label: 'Streak',
                iconColor: CozyColors.primary, // Warm amber for fire
                valueColor: Theme.of(context).colorScheme.onSurface,
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              BlocBuilder<
                OnboardingPreferencesCubit,
                OnboardingPreferencesState
              >(
                builder: (context, state) {
                  IconData icon;
                  Color color;
                  String time = state.productiveTime;

                  switch (time.toLowerCase()) {
                    case 'morning':
                      icon = Icons.wb_sunny_rounded;
                      color = CozyColors.warning; // Soft gold for sun
                      break;
                    case 'afternoon':
                      icon = Icons.wb_twilight_rounded;
                      color = CozyColors.primary; // Warm amber
                      break;
                    case 'evening':
                    case 'night':
                      icon = Icons.nightlight_round;
                      color = CozyColors.accent; // Deep navy for night
                      break;
                    default:
                      icon = Icons.schedule_rounded;
                      color = CozyColors.success;
                  }

                  return _buildModernCard(
                    context,
                    icon: icon,
                    value: state.isLoading ? '...' : time,
                    label: 'Peak Time',
                    iconColor: color,
                    valueColor: Theme.of(context).colorScheme.onSurface,
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildModernCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAllocation(BuildContext context) {
    return BlocBuilder<DailyUsageSummaryCubit, DailyUsageSummaryState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = state.summary;
        if (summary == null || summary.totalCount == 0) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.transparent,
              ), // Placeholder for consistent layout
            ),
            child: const Center(
              child: Text("No time logged yet. Start a session!"),
            ),
          );
        }

        final alignedPct = (summary.alignedCount / summary.totalCount * 100)
            .round();
        final neutralPct = (summary.neutralCount / summary.totalCount * 100)
            .round();
        final misalignedPct = 100 - alignedPct - neutralPct;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 32, // Thicker bar
                  child: Row(
                    children: [
                      if (alignedPct > 0)
                        Expanded(
                          flex: alignedPct,
                          child: Container(color: CozyColors.success),
                        ),
                      if (neutralPct > 0)
                        Expanded(
                          flex: neutralPct,
                          child: Container(color: CozyColors.warning),
                        ),
                      if (misalignedPct > 0)
                        Expanded(
                          flex: misalignedPct,
                          child: Container(color: CozyColors.error),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendItem(
                    context,
                    'Aligned',
                    '$alignedPct%',
                    CozyColors.success,
                  ),
                  _buildLegendItem(
                    context,
                    'Neutral',
                    '$neutralPct%',
                    CozyColors.warning,
                  ),
                  _buildLegendItem(
                    context,
                    'Misaligned',
                    '$misalignedPct%',
                    CozyColors.error,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return BlocBuilder<UsageHistoryCubit, UsageHistoryState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }
        if (state.items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No recent activity found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= 3) return null; // Only show top 3
            final item = state.items[index];
            Color alignmentColor;
            IconData icon;

            switch (item.alignment) {
              case AlignmentStatus.aligned:
                alignmentColor = CozyColors.success;
                icon = Icons.check_circle_outline_rounded;
                break;
              case AlignmentStatus.neutral:
                alignmentColor = CozyColors.warning;
                icon = Icons.remove_circle_outline_rounded;
                break;
              case AlignmentStatus.misaligned:
                alignmentColor = CozyColors.error;
                icon = Icons.warning_amber_rounded;
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                // No border or distinct shadow for a cleaner "list" look, or a very subtle card look
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: alignmentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: alignmentColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.appName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }, childCount: state.items.length > 3 ? 3 : state.items.length),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Widget _buildModernFAB(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.progressChat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [CozyColors.primary, CozyColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: CozyColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_comment_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Log Activity',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
