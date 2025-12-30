import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_cubit.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/use_case_chips_dialog.dart';

class AppSelectionScreen extends StatefulWidget {
  final bool fromSettings;

  const AppSelectionScreen({super.key, this.fromSettings = false});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<AppInfo> _installedApps = [];
  final Set<String> _selectedPackageNames = {};
  final Map<String, String> _appReasons = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // App use cases from AI
  Map<String, List<String>> _appUseCases = {};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) {
      return _installedApps;
    }
    return _installedApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchApps();
    if (widget.fromSettings) {
      _loadExistingSelections();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

      // Trigger background fetch of use cases
      _fetchUseCases();
    } catch (e) {
      debugPrint('Error fetching apps: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Background fetch of AI-generated use cases for all installed apps
  Future<void> _fetchUseCases() async {
    if (_installedApps.isEmpty) return;

    try {
      // Prepare app list for API call
      final appsList = _installedApps
          .map((app) => {'package_name': app.packageName, 'app_name': app.name})
          .toList();

      // Call API (will return cached or generate new)
      final useCases = await ApiService.instance.getAppUseCases(appsList);

      if (mounted) {
        setState(() {
          _appUseCases = useCases;
        });
      }
    } catch (e) {
      debugPrint('Error fetching use cases: $e');
    }
  }

  Future<void> _loadExistingSelections() async {
    try {
      final result = await ApiService.instance.getAppSelections();
      final selections = (result['selections'] as List<dynamic>?) ?? [];

      if (mounted) {
        setState(() {
          for (final selection in selections) {
            final selectionMap = selection as Map<String, dynamic>;
            final packageName = selectionMap['package_name'] as String?;
            final reason = selectionMap['reason'] as String?;

            if (packageName != null) {
              _selectedPackageNames.add(packageName);
              if (reason != null && reason.isNotEmpty) {
                _appReasons[packageName] = reason;
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading existing selections: $e');
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
    // Get AI-generated use cases for this app (if loaded)
    final aiUseCases = _appUseCases[app.packageName];

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UseCaseChipsDialog(
        appName: app.name,
        packageName: app.packageName,
        aiSuggestedUseCases: aiUseCases,
        initialReason: _appReasons[app.packageName],
      ),
    );

    if (reason == null || reason.isEmpty) {
      // User cancelled dialog - remove selection
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
          .map(
            (app) => {
              'package_name': app.packageName,
              'app_name': app.name,
              'reason': _appReasons[app.packageName] ?? '',
              //TODO: Think about this value later and what to do with it
              'importance_rating': 5, // Default for now
            },
          )
          .toList();

      // 2. Save apps
      await ApiService.instance.saveAppSelections(apps: selectedAppsData);

      if (widget.fromSettings) {
        // Coming from settings - just go back
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App selections updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Coming from onboarding - complete onboarding and navigate to dashboard
        // 3. Complete Onboarding
        await ApiService.instance.completeOnboarding();

        if (!mounted) return;
        // Notify AuthCubit that onboarding is done so it updates local state/storage
        context.read<AuthCubit>().completeOnboarding();

        if (!mounted) return;

        // 4. Navigate to Dashboard
        // The AuthWrapper should pick up the change on next app launch,
        // but for immediate transition we push replacement.
        // Ideally update AuthCubit state here too.
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
      }
    } catch (e) {
      debugPrint('Error completing onboarding: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.fromSettings
                ? 'Failed to update selections. Please try again.'
                : 'Failed to complete setup. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _skipOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.completeOnboarding();

      if (mounted) {
        context.read<AuthCubit>().completeOnboarding();
      }
    } catch (e) {
      debugPrint('Error skipping onboarding: $e');
      // Still allow the user to continue; they explicitly chose to skip.
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fromSettings ? 'Manage Apps' : 'Select Helper Apps'),
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
          if (!widget.fromSettings)
            TextButton(
              onPressed: _isSaving ? null : _skipOnboarding,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Which apps help you make progress on your goals? We'll track when you're using these vs. getting distracted.",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // App count indicator
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    _searchQuery.isNotEmpty
                        ? '${_filteredApps.length} of ${_installedApps.length} apps'
                        : '${_installedApps.length} apps',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No apps found for "$_searchQuery"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredApps.length,
                    padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final isSelected = _selectedPackageNames.contains(
                        app.packageName,
                      );

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
                            ? [
                                AppColors.primary.withValues(alpha: 0.6),
                                AppColors.primaryLight.withValues(alpha: 0.6),
                              ]
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
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
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          const SizedBox(width: 12),
                          Text(
                            _isSaving
                                ? (widget.fromSettings
                                      ? 'Saving...'
                                      : 'Setting up...')
                                : (widget.fromSettings
                                      ? 'Save Changes'
                                      : 'Complete Setup'),
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
