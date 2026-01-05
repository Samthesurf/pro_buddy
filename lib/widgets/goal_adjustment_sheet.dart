import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/goal_journey_cubit.dart';

class GoalAdjustmentSheet extends StatefulWidget {
  const GoalAdjustmentSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const GoalAdjustmentSheet(),
    );
  }

  @override
  State<GoalAdjustmentSheet> createState() => _GoalAdjustmentSheetState();
}

class _GoalAdjustmentSheetState extends State<GoalAdjustmentSheet> {
  final _activityController = TextEditingController();

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔄 Adjust Your Journey',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell me what you\'re actually working on right now:',
            style: TextStyle(color: theme.hintColor), // Using hintColor instead of mutedTextColor for broader compatibility if theme extension not available
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _activityController,
            decoration: const InputDecoration(
              hintText: 'e.g., I\'m learning algorithms and data structures...', 
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_activityController.text.trim().isNotEmpty) {
                  context.read<GoalJourneyCubit>().adjustJourney(
                    currentActivity: _activityController.text.trim(),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Let AI Adjust'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
