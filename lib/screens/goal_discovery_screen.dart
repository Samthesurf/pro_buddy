import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/goal_discovery_cubit.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/chat.dart';
import '../services/notification_content.dart';

class GoalDiscoveryScreen extends StatefulWidget {
  const GoalDiscoveryScreen({super.key});

  @override
  State<GoalDiscoveryScreen> createState() => _GoalDiscoveryScreenState();
}

class _GoalDiscoveryScreenState extends State<GoalDiscoveryScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _didAutoNavigate = false;
  bool _didCacheProfile = false;
  bool _didCacheCheckIn = false;

  Map<String, dynamic>? get _routeArgs {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) return args;
    if (args is Map) return args.cast<String, dynamic>();
    return null;
  }

  bool get _fromOnboarding {
    final args = _routeArgs;
    if (args != null) return args['fromOnboarding'] == true;
    // If not explicitly passed, assume true if we are in an initial discovery flow?
    // Actually, checking history or just defaulting to false is safer.
    // But since we just finished auth and pushed here, we passed 'fromOnboarding': true in AuthScreen.
    // So this should be fine.
    return false;
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(BuildContext context) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<GoalDiscoveryCubit>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GoalDiscoveryCubit, GoalDiscoveryState>(
      listenWhen: (prev, curr) =>
          prev.messages.length != curr.messages.length ||
          prev.isLoading != curr.isLoading ||
          prev.done != curr.done ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        _scrollToBottom();
        final error = state.errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
          );
          context.read<GoalDiscoveryCubit>().clearError();
        }

        // Cache check-in frequency + profile locally so notifications can be generated without API calls.
        if (!_didCacheCheckIn) {
          final args = _routeArgs;
          final onboarding = args?['onboarding_data'];
          if (onboarding is Map) {
            final data = onboarding.cast<String, dynamic>();
            final freq = (data['check_in_frequency'] ?? 'Daily').toString();
            NotificationCache.saveCheckInFrequency(freq);
            _didCacheCheckIn = true;
          }
        }

        if (state.done && !_didCacheProfile && state.profile != null) {
          NotificationCache.saveNotificationProfile(state.profile!);
          _didCacheProfile = true;
        }

        if (_fromOnboarding &&
            state.done &&
            !state.isLoading &&
            !_didAutoNavigate) {
          _didAutoNavigate = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushNamed(AppRoutes.appSelection);
          });
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final title = state.done ? 'Goal Profile Saved' : 'Goal Discovery';

        return Scaffold(
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
                        AppColors.accent.withValues(alpha: 0.06),
                        AppColors.background,
                      ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _Header(
                    title: title,
                    showSkipToApps: _fromOnboarding,
                    showSkipOnboarding: _fromOnboarding,
                    onSkipOnboarding: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.dashboard,
                      (route) => false,
                    ),
                    onSkipToApps: () => Navigator.of(context).pushNamed(
                      AppRoutes.appSelection,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.messages.length && state.isLoading) {
                          return _TypingBubble();
                        }
                        return _MessageBubble(message: state.messages[index]);
                      },
                    ),
                  ),
                  _InputBar(
                    controller: _textController,
                    isLoading: state.isLoading,
                    onSend: () => _send(context),
                    hintText: state.done
                        ? 'You can keep refining…'
                        : 'Answer honestly…',
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: state.done
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.appSelection,
                  ),
                  label: const Text('Next: Select Apps'),
                  icon: const Icon(Icons.apps_rounded),
                )
              : null,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.showSkipToApps = false,
    this.showSkipOnboarding = false,
    this.onSkipOnboarding,
    this.onSkipToApps,
  });

  final String title;
  final bool showSkipToApps;
  final bool showSkipOnboarding;
  final VoidCallback? onSkipOnboarding;
  final VoidCallback? onSkipToApps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accent, AppColors.accentLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'So notifications actually “get” your goals',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (showSkipOnboarding) ...[
            IconButton(
              tooltip: 'Skip onboarding',
              onPressed: onSkipOnboarding,
              icon: const Icon(Icons.skip_next_rounded),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (showSkipToApps) ...[
            IconButton(
              tooltip: 'Skip to app selection',
              onPressed: onSkipToApps,
              icon: const Icon(Icons.fast_forward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            tooltip: 'Restart',
            onPressed: () => context.read<GoalDiscoveryCubit>().start(reset: true),
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : theme.colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppColors.primary : Colors.black)
                        .withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isUser ? Colors.white : theme.colorScheme.onSurface,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Dot(delayMs: 0),
              const SizedBox(width: 4),
              _Dot(delayMs: 200),
              const SizedBox(width: 4),
              _Dot(delayMs: 400),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.delayMs});

  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delayMs),
      builder: (context, value, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.25 + (0.7 * value)),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.hintText,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accentLight],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: isLoading ? null : onSend,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}