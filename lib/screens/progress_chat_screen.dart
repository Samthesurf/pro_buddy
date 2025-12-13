import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/chat_cubit.dart';
import '../bloc/progress_summary_cubit.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/chat.dart';

/// A beautiful chat screen for daily progress tracking.
/// Features a prominent question prompt and conversational interface.
class ProgressChatScreen extends StatefulWidget {
  const ProgressChatScreen({super.key});

  @override
  State<ProgressChatScreen> createState() => _ProgressChatScreenState();
}

class _ProgressChatScreenState extends State<ProgressChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late AnimationController _promptAnimationController;
  late Animation<double> _promptFadeAnimation;
  late Animation<Offset> _promptSlideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().loadHistory();
    });
  }

  void _setupAnimations() {
    _promptAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _promptFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _promptAnimationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _promptSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _promptAnimationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _promptAnimationController.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _promptAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(BuildContext context, {String? presetText}) {
    final rawText = presetText ?? _textController.text;
    final text = rawText.trim();
    if (text.isEmpty) return;

    final chatCubit = context.read<ChatCubit>();
    if (chatCubit.state.isLoading) return;

    _textController.clear();
    _focusNode.requestFocus();
    chatCubit.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (previous, current) =>
          previous.messages.length != current.messages.length ||
          previous.isLoading != current.isLoading ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        _scrollToBottom();

        final latestMessage =
            state.messages.isNotEmpty ? state.messages.last : null;
        if (latestMessage?.role == MessageRole.assistant &&
            latestMessage?.encouragementType == EncouragementType.celebrate) {
          HapticFeedback.mediumImpact();
        }

        final error = state.errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<ChatCubit>().clearError();
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

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
                        AppColors.primary.withValues(alpha: 0.05),
                        AppColors.background,
                      ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: state.showInitialPrompt && state.messages.isEmpty
                        ? _buildInitialPrompt(context)
                        : _buildChatList(context, state),
                  ),
                  _buildInputArea(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
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
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Buddy',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your progress companion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.goalDiscovery),
            icon: const Icon(Icons.flag_rounded),
            tooltip: 'Goal Discovery',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showSummarySheet(context),
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'View Progress Summary',
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = _getTimeGreeting(now);

    return FadeTransition(
      opacity: _promptFadeAnimation,
      child: SlideTransition(
        position: _promptSlideAnimation,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated gradient icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                      AppColors.accent.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              
              // Greeting
              Text(
                greeting,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              
              // Main question
              Text(
                "What's today's\nprogress?",
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              
              // Subtitle
              Text(
                "Share what you've accomplished, what you're working on, or any challenges you're facing.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // Quick prompts
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickPrompt(context, "🎯 Made progress on my goals"),
                  _buildQuickPrompt(context, "💪 Stayed focused today"),
                  _buildQuickPrompt(context, "🤔 Facing a challenge"),
                  _buildQuickPrompt(context, "✨ Small win to share"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(BuildContext context, String text) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _handleSend(context, presetText: text),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, ChatState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length && state.isLoading) {
          return _buildTypingIndicator(context);
        }
        return _buildMessageBubble(context, state.messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message) {
    final theme = Theme.of(context);
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildAvatar(context, message.encouragementType),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppColors.primary : Colors.black)
                        .withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isUser
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                  if (message.detectedTopics != null &&
                      message.detectedTopics!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: message.detectedTopics!
                          .take(3)
                          .map((topic) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  topic,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.person,
                size: 18,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, EncouragementType? type) {
    IconData icon;
    List<Color> colors;

    switch (type) {
      case EncouragementType.celebrate:
        icon = Icons.celebration;
        colors = [AppColors.success, AppColors.successLight];
        break;
      case EncouragementType.support:
        icon = Icons.favorite;
        colors = [AppColors.accent, AppColors.accentLight];
        break;
      case EncouragementType.motivate:
        icon = Icons.local_fire_department;
        colors = [AppColors.warning, AppColors.warningLight];
        break;
      case EncouragementType.curious:
      default:
        icon = Icons.auto_awesome;
        colors = [AppColors.primary, AppColors.primaryLight];
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _buildAvatar(context, null),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3 + (0.7 * value)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context, ChatState state) {
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Share your progress...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onSubmitted: (_) => _handleSend(context),
                      ),
                    ),
                    // Voice input button (placeholder)
                    IconButton(
                      onPressed: () {
                        // TODO: Implement voice input
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Voice input coming soon!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.mic_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed:
                    state.isLoading ? null : () => _handleSend(context),
                icon: state.isLoading
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

  void _showSummarySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider(
        create: (_) => ProgressSummaryCubit()..loadSummary(),
        child: const _ProgressSummarySheet(),
      ),
    );
  }

  String _getTimeGreeting(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// Bottom sheet for progress summary
class _ProgressSummarySheet extends StatelessWidget {
  const _ProgressSummarySheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ProgressSummaryCubit, ProgressSummaryState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final error = state.errorMessage;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<ProgressSummaryCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Progress Summary',
                          style: theme.textTheme.titleLarge,
                        ),
                        const Spacer(),
                        // Period selector
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'today', label: Text('Today')),
                            ButtonSegment(value: 'week', label: Text('Week')),
                            ButtonSegment(value: 'month', label: Text('Month')),
                          ],
                          selected: {state.selectedPeriod},
                          onSelectionChanged: (selection) {
                            context
                                .read<ProgressSummaryCubit>()
                                .changePeriod(selection.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),

                  // Content
                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.summary == null
                            ? _buildEmptyState(context)
                            : _buildSummaryContent(
                                context,
                                scrollController,
                                state.summary!,
                              ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No progress data yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start sharing your progress to see insights!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(
    BuildContext context,
    ScrollController scrollController,
    ProgressSummary summary,
  ) {
    final theme = Theme.of(context);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // AI Insight card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.primaryLight.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI Insight',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.aiInsight,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.edit_note,
                label: 'Entries',
                value: summary.totalEntries.toString(),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.emoji_events,
                label: 'Achievements',
                value: summary.keyAchievements.length.toString(),
                color: AppColors.success,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Key achievements
        if (summary.keyAchievements.isNotEmpty) ...[
          Text(
            'Key Achievements',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...summary.keyAchievements.map((achievement) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        achievement,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],

        const SizedBox(height: 24),

        // Recurring challenges
        if (summary.recurringChallenges.isNotEmpty) ...[
          Text(
            'Areas to Focus On',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...summary.recurringChallenges.map((challenge) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.flag,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        challenge,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
