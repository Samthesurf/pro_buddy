import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../services/api_service.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<AppInfo> _installedApps = [];
  final Set<String> _selectedPackageNames = {};
  final Map<String, String> _appReasons = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );
      
      // Filter out our own app if needed
      // apps.removeWhere((app) => app.packageName == 'com.example.pro_buddy');

      setState(() {
        _installedApps = apps..sort((a, b) => a.name.compareTo(b.name));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching apps: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleAppSelection(AppInfo app) {
    setState(() {
      if (_selectedPackageNames.contains(app.packageName)) {
        _selectedPackageNames.remove(app.packageName);
        _appReasons.remove(app.packageName);
      } else {
        _selectedPackageNames.add(app.packageName);
        _showReasonDialog(app);
      }
    });
  }

  Future<void> _showReasonDialog(AppInfo app) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Why use ${app.name}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How does this app help you achieve your goals?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. For coding, research, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Cancel selection if no reason provided? Or allow empty?
              // Let's remove selection if cancelled
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (reason == null) {
      // User cancelled dialog
      setState(() {
        _selectedPackageNames.remove(app.packageName);
      });
    } else {
      setState(() {
        _appReasons[app.packageName] = reason;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Prepare selected apps data
      final selectedAppsData = _installedApps
          .where((app) => _selectedPackageNames.contains(app.packageName))
          .map((app) => {
                'package_name': app.packageName,
                'app_name': app.name,
                'reason': _appReasons[app.packageName] ?? '',
                'importance_rating': 5, // Default for now
              })
          .toList();

      // 2. Save apps
      await ApiService.instance.saveAppSelections(apps: selectedAppsData);

      // 3. Complete Onboarding
      await ApiService.instance.completeOnboarding();

      if (!mounted) return;

      // 4. Navigate to Dashboard
      // The AuthWrapper should pick up the change on next app launch, 
      // but for immediate transition we push replacement.
      // Ideally update AuthCubit state here too.
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.dashboard,
        (route) => false,
      );
      
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to complete setup. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Helper Apps'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_selectedPackageNames.length} selected',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Choose the apps that help you stay productive and achieve your goals.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _installedApps.length,
                    padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                    itemBuilder: (context, index) {
                      final app = _installedApps[index];
                      final isSelected = _selectedPackageNames.contains(app.packageName);
                      
                      return ListTile(
                        leading: app.icon != null
                            ? Image.memory(app.icon!, width: 40, height: 40)
                            : const Icon(Icons.android),
                        title: Text(app.name),
                        subtitle: isSelected
                            ? Text(
                                _appReasons[app.packageName] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.primary),
                              )
                            : null,
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleAppSelection(app),
                          activeColor: AppColors.primary,
                        ),
                        onTap: () => _toggleAppSelection(app),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedPackageNames.isNotEmpty
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : _completeOnboarding,
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isSaving 
                            ? [AppColors.primary.withValues(alpha: 0.6), AppColors.primaryLight.withValues(alpha: 0.6)]
                            : [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSaving)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          else
                            const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          Text(
                            _isSaving ? 'Setting up...' : 'Complete Setup',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
