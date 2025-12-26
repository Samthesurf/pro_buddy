import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../bloc/chat_cubit.dart';
import '../bloc/progress_score_cubit.dart';
import '../bloc/progress_summary_cubit.dart';
import '../core/routes.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/notification_content.dart';

enum _ExitAction { saveAndExit, exit, cancel }

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
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;

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

    _promptSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
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
    _audioRecorder.dispose();
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

  Future<void> _handleVoiceInput(BuildContext context) async {
    if (_isRecording) {
      // Stop recording and send
      await _stopRecordingAndSend(context);
    } else {
      // Start recording
      await _startRecording(context);
    }
  }

  Future<void> _startRecording(BuildContext context) async {
    // Check and request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice input'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${tempDir.path}/recording_$timestamp.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
      });

      if (!mounted) return;
      HapticFeedback.mediumImpact();
    } catch (e) {
      print('Error starting recording: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start recording'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopRecordingAndSend(BuildContext context) async {
    try {
      // Stop recording
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      if (path == null || path.isEmpty) {
        throw Exception('Recording path is null');
      }

      // Read audio file
      final audioFile = File(path);
      if (!await audioFile.exists()) {
        throw Exception('Recording file does not exist');
      }

      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Send to chat cubit
      if (!mounted) return;
      final chatCubit = context.read<ChatCubit>();
      if (chatCubit.state.isLoading) return;

      // Show a loading indicator
      chatCubit.sendVoiceMessage(
        audioBase64: audioBase64,
        audioMimeType: 'audio/mp4',
      );
      _scrollToBottom();

      // Clean up the recording file
      try {
        await audioFile.delete();
      } catch (e) {
        print('Error deleting recording file: $e');
      }
    } catch (e) {
      print('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process voice recording'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleBackPressed(BuildContext context) async {
    final theme = Theme.of(context);

    final action = await showDialog<_ExitAction>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Save today’s log?'),
        content: const Text(
          'Saving will update your Goal Progress % and store today’s conversation as memory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.exit),
            child: Text(
              'Exit',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ExitAction.saveAndExit),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == null || action == _ExitAction.cancel) return;
    if (action == _ExitAction.exit) {
      Navigator.of(context).pop();
      return;
    }

    // Save & Exit: send today's messages only.
    final chatState = context.read<ChatCubit>().state;
    final now = DateTime.now();
    final todays = chatState.messages.where(
      (m) => _isSameLocalDay(m.timestamp, now),
    );

    final payload = todays
        .map(
          (m) => {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
            'timestamp': m.timestamp.toIso8601String(),
          },
        )
        .toList();

    // If there's nothing today, just exit.
    if (payload.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final raw = await ApiService.instance.finalizeTodayProgress(
        messages: payload,
      );
      final score = raw['score'] as Map<String, dynamic>?;
      if (score != null) {
        final scorePercent = (score['score_percent'] as num?)?.round() ?? 0;
        final reason = score['reason'] as String? ?? '';
        final dateUtc = score['date_utc'] as String? ?? '';
        context.read<ProgressScoreCubit>().setLatest(
          scorePercent: scorePercent,
          reason: reason,
          dateUtc: dateUtc,
        );
        NotificationCache.saveLastProgressScore(
          LastProgressScore(
            scorePercent: scorePercent,
            reason: reason,
            dateUtc: dateUtc,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save today’s log.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPressed(context);
      },
      child: BlocConsumer<ChatCubit, ChatState>(
        listenWhen: (previous, current) =>
            previous.messages.length != current.messages.length ||
            previous.isLoading != current.isLoading ||
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          _scrollToBottom();

          final latestMessage = state.messages.isNotEmpty
              ? state.messages.last
              : null;
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
                          theme.scaffoldBackgroundColor,
                          theme.colorScheme.surface,
                        ]
                      : [
                          theme.colorScheme.primary.withValues(alpha: 0.05),
                          theme.scaffoldBackgroundColor,
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
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _handleBackPressed(context),
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
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              //triple ai icon
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
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.goalDiscovery),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                              theme.colorScheme.secondary.withValues(
                                alpha: 0.6,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
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
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildQuickPrompt(
                            context,
                            "🎯 Made progress on my goals",
                          ),
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
          },
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(BuildContext context, String text) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _handleSend(context, presetText: text),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
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
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? theme.colorScheme.primary : Colors.black)
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
                          .map(
                            (topic) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                topic,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          )
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
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, EncouragementType? type) {
    final theme = Theme.of(context);
    IconData icon;
    List<Color> colors;

    switch (type) {
      case EncouragementType.celebrate:
        icon = Icons.celebration;
        colors = [
          theme.colorScheme.tertiary,
          theme.colorScheme.tertiary.withValues(alpha: 0.7),
        ];
        break;
      case EncouragementType.support:
        icon = Icons.favorite;
        colors = [
          theme.colorScheme.secondary,
          theme.colorScheme.secondary.withValues(alpha: 0.7),
        ];
        break;
      case EncouragementType.motivate:
        icon = Icons.local_fire_department;
        colors = [
          theme.colorScheme.secondary,
          theme.colorScheme.secondaryContainer,
        ];
        break;
      case EncouragementType.curious:
      default:
        icon = Icons.auto_awesome;
        colors = [
          theme.colorScheme.primary,
          theme.colorScheme.primaryContainer,
        ];
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
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 600 + (index * 200)),
          builder: (context, value, child) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.3 + (0.7 * value),
                ),
                shape: BoxShape.circle,
              ),
            );
          },
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
                    // Voice input button
                    IconButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _handleVoiceInput(context),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          key: ValueKey(_isRecording),
                          color: _isRecording
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
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
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: state.isLoading ? null : () => _handleSend(context),
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
            SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Icon(
                              Icons.insights_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Progress Summary',
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Period selector
                        Center(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'today',
                                label: Text('Today'),
                              ),
                              ButtonSegment(value: 'week', label: Text('Week')),
                              ButtonSegment(
                                value: 'month',
                                label: Text('Month'),
                              ),
                            ],
                            selected: {state.selectedPeriod},
                            onSelectionChanged: (selection) {
                              context.read<ProgressSummaryCubit>().changePeriod(
                                selection.first,
                              );
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
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
          Icon(Icons.auto_awesome, size: 48, color: theme.colorScheme.outline),
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
                theme.colorScheme.primary.withValues(alpha: 0.1),
                theme.colorScheme.primaryContainer.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI Insight',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.aiInsight,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
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
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.emoji_events,
                label: 'Achievements',
                value: summary.keyAchievements.length.toString(),
                color: theme.colorScheme.tertiary,
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
          ...summary.keyAchievements.map(
            (achievement) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      achievement,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          ...summary.recurringChallenges.map(
            (challenge) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.flag,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
