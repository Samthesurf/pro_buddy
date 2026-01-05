import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_cubit.dart';
import '../bloc/goal_journey_cubit.dart';
import '../models/chat.dart';

/// Listens to [ChatCubit] for successful progress reports and updates the [GoalJourneyCubit].
class DailyProgressListener extends StatelessWidget {
  final Widget child;

  const DailyProgressListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (previous, current) {
        // Trigger when loading finishes successfully
        return previous.isLoading &&
            !current.isLoading &&
            current.errorMessage == null &&
            current.messages.isNotEmpty &&
            current.messages.last.role == MessageRole.assistant;
      },
      listener: (context, state) {
        // Find the user's last message (the one that triggered this response)
        // It should be the second to last message
        if (state.messages.length < 2) return;

        final userMessage = state.messages[state.messages.length - 2];
        if (userMessage.role != MessageRole.user) return;

        // Update the journey
        final journeyCubit = context.read<GoalJourneyCubit>();
        final currentJourney = journeyCubit.state.journey;

        if (currentJourney != null && currentJourney.currentStep != null) {
          // Add the user's progress log as a note to the current step
          journeyCubit.addStepNote(
            stepId: currentJourney.currentStep!.id,
            note: "Daily Log: ${userMessage.content}",
          );

          // We could also show a snackbar or trigger an animation here
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Journey updated with your daily progress!'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: child,
    );
  }
}
