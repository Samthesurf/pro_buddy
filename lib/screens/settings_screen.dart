import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/chat_cubit.dart';
import '../bloc/progress_score_cubit.dart';
import '../core/logger.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/app_icon_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _goals;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _preferences;
  Map<String, dynamic>? _selectedApps;
  String? _error;

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _appsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _appsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        ApiService.instance.getGoals(),
        ApiService.instance.getNotificationProfile(),
        ApiService.instance.getOnboardingPreferences(),
        ApiService.instance.getAppSelections(),
      ]);

      if (!mounted) return;
      setState(() {
        _goals = futures[0];

        // Handle potential nesting of profile data
        var profileData = futures[1];
        appLogger.d('Profile data raw: $profileData');

        if (profileData.containsKey('profile') &&
            profileData['profile'] is Map) {
          try {
            profileData = Map<String, dynamic>.from(
              profileData['profile'] as Map,
            );
            appLogger.d('Unwrapped profile data: $profileData');
          } catch (e, st) {
            appLogger.w(
              'Error unwrapping profile data',
              error: e,
              stackTrace: st,
            );
            // Fallback to raw data if casting fails
          }
        }
        _profile = profileData;

        _preferences = futures[2];
        _selectedApps = futures[3];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Scrollbar(
                controller: _mainScrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _mainScrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Primary Goals Section
                    _buildSectionHeader(
                      icon: Icons.flag_rounded,
                      title: 'Primary Goals',
                      subtitle: 'Your main objectives',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildGoalsCard(),

                    const SizedBox(height: 24),

                    // Notification Profile Section
                    _buildSectionHeader(
                      icon: Icons.notifications_rounded,
                      title: 'Notification Profile',
                      subtitle: 'How we personalize your nudges',
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    _buildProfileCard(),

                    const SizedBox(height: 24),

                    // Onboarding Preferences Section
                    _buildSectionHeader(
                      icon: Icons.psychology_rounded,
                      title: 'Habits & Challenges',
                      subtitle: 'Your routines and focus areas',
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(height: 12),
                    _buildPreferencesCard(),

                    const SizedBox(height: 24),

                    // Selected Apps Section
                    _buildSectionHeader(
                      icon: Icons.apps_rounded,
                      title: 'Selected Apps',
                      subtitle: 'Apps that help you achieve your goals',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildSelectedAppsCard(),

                    const SizedBox(height: 24),

                    // Actions Section
                    _buildSectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'Actions',
                      subtitle: 'Manage your account',
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    _buildActionsCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsCard() {
    final goalsList = (_goals?['goals'] as List<dynamic>?) ?? [];
    final profile = _profile;

    // Try both snake_case (standard) and camelCase (potential mismatch)
    final primaryGoal =
        (profile?['primary_goal'] as String?) ??
        (profile?['primaryGoal'] as String?);

    // Check for 'why' or 'reason'
    final why = (profile?['why'] as String?) ?? (profile?['reason'] as String?);

    appLogger.d('Building Goals Card. Primary: "$primaryGoal", Why: "$why"');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary Goal from Notification Profile
            if (primaryGoal != null && primaryGoal.isNotEmpty) ...[
              _buildGoalItem(
                title: 'Primary Goal',
                content: primaryGoal,
                reason: why,
                isPrimary: true,
                onEdit: () => _showEditGoalDialog(
                  title: 'Edit Primary Goal',
                  currentContent: primaryGoal,
                  currentReason: why,
                  isPrimaryGoal: true,
                ),
              ),
              if (goalsList.isNotEmpty) const Divider(height: 24),
            ],

            // Additional Goals
            if (goalsList.isNotEmpty)
              ...goalsList.map((goal) {
                final goalMap = goal as Map<String, dynamic>;
                return Column(
                  children: [
                    _buildGoalItem(
                      title: 'Goal',
                      content: goalMap['content'] ?? '',
                      reason: goalMap['reason'],
                      timeline: goalMap['timeline'],
                      isPrimary: false,
                      onEdit: () => _showEditGoalDialog(
                        title: 'Edit Goal',
                        goalId: goalMap['id'],
                        currentContent: goalMap['content'],
                        currentReason: goalMap['reason'],
                        currentTimeline: goalMap['timeline'],
                        isPrimaryGoal: false,
                      ),
                      onDelete: () => _deleteGoal(goalMap['id']),
                    ),
                    if (goalsList.last != goal) const Divider(height: 16),
                  ],
                );
              }),

            // Empty state
            if ((primaryGoal == null || primaryGoal.isEmpty) &&
                goalsList.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No goals set yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.goalDiscovery,
                          arguments: {'fromOnboarding': false},
                        );
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Start Goal Discovery'),
                    ),
                  ],
                ),
              ),

            // Add Goal Button
            if ((primaryGoal != null && primaryGoal.isNotEmpty) ||
                goalsList.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.goalDiscovery,
                      arguments: {'fromOnboarding': false},
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refine Goals'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem({
    required String title,
    required String content,
    String? reason,
    String? timeline,
    required bool isPrimary,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPrimary
                    ? colorScheme.primary.withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isPrimary
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit',
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: colorScheme.error,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete',
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        if (reason != null && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.favorite_rounded,
                size: 16,
                color: colorScheme.secondary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (timeline != null && timeline.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                timeline,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildProfileCard() {
    final profile = _profile;
    if (profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No profile data available'),
        ),
      );
    }

    final identity = profile['identity'] as String?;
    final style = profile['style'] as String?;
    final motivators = (profile['motivators'] as List<dynamic>?) ?? [];
    final stakes = profile['stakes'] as String?;
    final importance = profile['importance_1_to_5'] as int?;
    final preferredName = profile['preferred_name_for_user'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (identity != null && identity.isNotEmpty)
              _buildProfileRow(
                icon: Icons.person_rounded,
                label: 'Identity',
                value: identity,
              ),
            if (style != null && style.isNotEmpty)
              _buildProfileRow(
                icon: Icons.chat_bubble_rounded,
                label: 'Notification Style',
                value: style.substring(0, 1).toUpperCase() + style.substring(1),
              ),
            if (importance != null)
              _buildProfileRow(
                icon: Icons.priority_high_rounded,
                label: 'Goal Importance',
                value: '$importance/5',
              ),
            if (motivators.isNotEmpty)
              _buildProfileRow(
                icon: Icons.bolt_rounded,
                label: 'Motivators',
                value: motivators.join(', '),
              ),
            if (stakes != null && stakes.isNotEmpty)
              _buildProfileRow(
                icon: Icons.warning_rounded,
                label: 'Stakes',
                value: stakes,
              ),
            if (preferredName != null && preferredName.isNotEmpty)
              _buildProfileRow(
                icon: Icons.badge_rounded,
                label: 'Preferred Name',
                value: preferredName,
              ),

            // Empty state
            if (identity == null && style == null && motivators.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Complete Goal Discovery to personalize your experience',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard() {
    final prefs = _preferences;
    if (prefs == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No preferences data available'),
        ),
      );
    }

    final challenges = (prefs['challenges'] as List<dynamic>?) ?? [];
    final habits = (prefs['habits'] as List<dynamic>?) ?? [];
    final productiveTime = prefs['productive_time'] as String?;
    final checkInFrequency = prefs['check_in_frequency'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (challenges.isNotEmpty) ...[
              Text(
                'Challenges to Overcome',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: challenges.map((c) {
                  return Chip(
                    label: Text(_formatChallenge(c.toString())),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.3),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (habits.isNotEmpty) ...[
              Text(
                'Habits to Build',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.success,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: habits.map((h) {
                  return Chip(
                    label: Text(_formatHabit(h.toString())),
                    backgroundColor: AppColors.success.withValues(alpha: 0.15),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (productiveTime != null && productiveTime.isNotEmpty)
              _buildProfileRow(
                icon: Icons.wb_sunny_rounded,
                label: 'Most Productive Time',
                value: productiveTime,
              ),

            if (checkInFrequency != null && checkInFrequency.isNotEmpty)
              _buildProfileRow(
                icon: Icons.notifications_active_rounded,
                label: 'Check-in Frequency',
                value: checkInFrequency,
              ),

            // Empty state
            if (challenges.isEmpty && habits.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No habits or challenges recorded',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatChallenge(String challenge) {
    return challenge
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
  }

  String _formatHabit(String habit) {
    return habit
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '',
        )
        .join(' ');
  }

  Widget _buildSelectedAppsCard() {
    final appsList = (_selectedApps?['selections'] as List<dynamic>?) ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (appsList.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Scrollbar(
                  controller: _appsScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _appsScrollController,
                    child: Column(
                      children: appsList.map((app) {
                        final appMap = app as Map<String, dynamic>;
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppIconWidget(
                                packageName: appMap['package_name'] ?? '',
                                size: 40,
                              ),
                              title: Text(
                                appMap['app_name'] ?? 'Unknown App',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              subtitle:
                                  appMap['reason'] != null &&
                                      appMap['reason'].toString().isNotEmpty
                                  ? Text(
                                      appMap['reason'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                            ),
                            if (appsList.last != app) const Divider(height: 8),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

            // Empty state
            if (appsList.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.apps_outlined,
                      size: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No apps selected yet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            // Add/Modify Apps Button
            if (appsList.isNotEmpty) const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.appSelection,
                    arguments: {'fromSettings': true},
                  );
                },
                icon: Icon(
                  appsList.isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                  size: 18,
                ),
                label: Text(
                  appsList.isEmpty ? 'Select Apps' : 'Modify Selection',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Switcher Section
            Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const ThemeSwitcher(),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Start New Goal Discovery'),
              subtitle: const Text('Redefine your primary goals'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.goalDiscovery,
                  arguments: {'fromOnboarding': false},
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                _showSignOutDialog();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.delete_forever_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Reset Account',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Clear all data and start fresh'),
              onTap: () {
                _showResetAccountDialog();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.no_accounts_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Account',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Permanently delete your account'),
              onTap: () {
                _showDeleteAccountDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Account?'),
          content: const Text(
            'This will delete all your data (goals, apps, history) so you can start fresh. This cannot be undone.\n\nYou will remain signed in but will need to go through onboarding again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Reset Account'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<AuthCubit>().resetAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reset account: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete Account?',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete your account?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This action is irreversible. All your data, goals, and history will be permanently erased.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<AuthCubit>().deleteAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditGoalDialog({
    required String title,
    String? goalId,
    String? currentContent,
    String? currentReason,
    String? currentTimeline,
    required bool isPrimaryGoal,
  }) async {
    final contentController = TextEditingController(text: currentContent ?? '');
    final reasonController = TextEditingController(text: currentReason ?? '');
    final timelineController = TextEditingController(
      text: currentTimeline ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    hintText: 'What do you want to achieve?',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Why (Optional)',
                    hintText: 'Why is this important to you?',
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (!isPrimaryGoal) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: timelineController,
                    decoration: const InputDecoration(
                      labelText: 'Timeline (Optional)',
                      hintText: 'e.g., 3 months',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      if (isPrimaryGoal) {
        // TODO: Add API to update primary goal in notification profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'To update your primary goal, please use Goal Discovery',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (goalId != null) {
        try {
          await ApiService.instance.updateGoal(
            goalId: goalId,
            content: contentController.text.trim().isNotEmpty
                ? contentController.text.trim()
                : null,
            reason: reasonController.text.trim().isNotEmpty
                ? reasonController.text.trim()
                : null,
            timeline: timelineController.text.trim().isNotEmpty
                ? timelineController.text.trim()
                : null,
          );
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Goal updated'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update goal: $e'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
    }

    contentController.dispose();
    reasonController.dispose();
    timelineController.dispose();
  }

  Future<void> _deleteGoal(String goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Goal?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ApiService.instance.deleteGoal(goalId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete goal: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign Out?'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reset cached data cubits to prevent data leakage between accounts
                context.read<ChatCubit>().reset();
                context.read<ProgressScoreCubit>().reset();
                context.read<AuthCubit>().signOut();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
