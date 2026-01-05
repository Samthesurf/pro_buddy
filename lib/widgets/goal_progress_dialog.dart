import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/goal_journey_cubit.dart';
import '../models/goal_journey.dart';

class GoalProgressDialog extends StatefulWidget {
  final GoalStep step;

  const GoalProgressDialog({
    super.key,
    required this.step,
  });

  static Future<void> show(BuildContext context, GoalStep step) {
    return showDialog(
      context: context,
      builder: (context) => GoalProgressDialog(step: step),
    );
  }

  @override
  State<GoalProgressDialog> createState() => _GoalProgressDialogState();
}

class _GoalProgressDialogState extends State<GoalProgressDialog> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: theme.primaryColor),
          const SizedBox(width: 8),
          const Text('Log Progress'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 ${widget.step.displayTitle}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'What did you work on today?',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_noteController.text.trim().isNotEmpty) {
              context.read<GoalJourneyCubit>().addStepNote(
                stepId: widget.step.id,
                note: _noteController.text.trim(),
              );
            }
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
