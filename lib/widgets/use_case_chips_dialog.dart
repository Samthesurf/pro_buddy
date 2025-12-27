import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

/// Dialog for selecting use cases for an app.
/// Shows AI-suggested chips (if available), universal fallback chips,
/// and an option for custom text input.
class UseCaseChipsDialog extends StatefulWidget {
  final String appName;
  final String packageName;
  final List<String>? aiSuggestedUseCases;
  final String? initialReason;

  const UseCaseChipsDialog({
    super.key,
    required this.appName,
    required this.packageName,
    this.aiSuggestedUseCases,
    this.initialReason,
  });

  @override
  State<UseCaseChipsDialog> createState() => _UseCaseChipsDialogState();
}

class _UseCaseChipsDialogState extends State<UseCaseChipsDialog> {
  final Set<String> _selectedUseCases = {};
  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    // Pre-select if there's an initial reason
    if (widget.initialReason != null && widget.initialReason!.isNotEmpty) {
      _selectedUseCases.add(widget.initialReason!);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggleUseCase(String useCase) {
    setState(() {
      if (_selectedUseCases.contains(useCase)) {
        _selectedUseCases.remove(useCase);
      } else {
        _selectedUseCases.add(useCase);
      }
    });
  }

  void _addCustomUseCase() {
    final custom = _customController.text.trim();
    if (custom.isNotEmpty) {
      setState(() {
        _selectedUseCases.add(custom);
        _customController.clear();
        _showCustomInput = false;
      });
    }
  }

  String get _combinedReason {
    return _selectedUseCases.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiCases = widget.aiSuggestedUseCases ?? [];
    final universalCases = ApiService.universalUseCases;

    return AlertDialog(
      title: Text('Why use ${widget.appName}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select how this app helps you achieve your goals:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // AI-suggested use cases
            if (aiCases.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Suggested for this app',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: aiCases.map((useCase) {
                  final isSelected = _selectedUseCases.contains(useCase);
                  return FilterChip(
                    label: Text(useCase),
                    selected: isSelected,
                    onSelected: (_) => _toggleUseCase(useCase),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Loading indicator for AI suggestions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Loading app-specific suggestions...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Universal categories
            Text(
              'General categories',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: universalCases.map((useCase) {
                final isSelected = _selectedUseCases.contains(useCase);
                return FilterChip(
                  label: Text(useCase),
                  selected: isSelected,
                  onSelected: (_) => _toggleUseCase(useCase),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom input toggle
            if (!_showCustomInput)
              TextButton.icon(
                onPressed: () => setState(() => _showCustomInput = true),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Write custom reason'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _customController,
                    decoration: InputDecoration(
                      hintText: 'e.g., For learning tutorials',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _addCustomUseCase,
                      ),
                    ),
                    onSubmitted: (_) => _addCustomUseCase(),
                    autofocus: true,
                  ),
                ],
              ),

            // Selected summary
            if (_selectedUseCases.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _combinedReason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedUseCases.isEmpty
              ? null
              : () => Navigator.of(context).pop(_combinedReason),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
