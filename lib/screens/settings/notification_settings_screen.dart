import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/notification_service.dart';
import '../../services/notification_content.dart';
import '../../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _areNotificationsEnabled = false;
  bool _isLoading = true;
  String? _checkInFrequency;
  String? _notificationStyle;

  // Available frequencies
  final List<String> _frequencies = ['Daily', 'Weekdays', 'Weekends', 'Never'];

  // Available styles
  final List<String> _styles = ['Direct', 'Gentle', 'Motivating', 'Strict'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    await _checkPermissionStatus();

    // Load local cache
    try {
      final freq = await NotificationCache.loadCheckInFrequency();
      final profile = await NotificationCache.loadNotificationProfile();

      if (mounted) {
        setState(() {
          _checkInFrequency = freq;
          if (profile != null) {
            _notificationStyle = profile.style;
          }
          _isLoading = false;
        });
      }

      // Attempt background refresh from API
      _refreshFromApi();
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshFromApi() async {
    try {
      final freshData = await ApiService.instance.getNotificationProfile();
      if (mounted && freshData.isNotEmpty) {
        // Parse dependent on structure - similar to SettingsScreen logic
        // If 'profile' key exists and is a Map
        Map<String, dynamic>? profileMap;
        if (freshData.containsKey('profile') && freshData['profile'] is Map) {
          profileMap = freshData['profile'] as Map<String, dynamic>;
        } else {
          profileMap = freshData;
        }

        if (profileMap.containsKey('style')) {
          setState(() {
            _notificationStyle = profileMap?['style'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing profile from API: $e');
    }
  }

  Future<void> _checkPermissionStatus() async {
    final enabled = await NotificationService.instance
        .areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _areNotificationsEnabled = enabled;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Request permissions
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        // If denied, tell user to open settings
        if (mounted) {
          _showSettingsDialog();
        }
      }
      // Re-check status regardless of result
      _checkPermissionStatus();
    } else {
      // We can't programmatically disable OS notifications
      _showSettingsDialog(isDisable: true);
    }
  }

  void _showSettingsDialog({bool isDisable = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isDisable ? 'Disable Notifications' : 'Enable Notifications',
        ),
        content: Text(
          isDisable
              ? 'To disable notifications, please turn them off in your device settings.'
              : 'Notifications are currently disabled. Please enable them in settings to receive updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFrequency(String? newValue) async {
    if (newValue == null) return;
    setState(() => _checkInFrequency = newValue);
    await NotificationCache.saveCheckInFrequency(newValue);
  }

  Future<void> _updateStyle(String? newValue) async {
    if (newValue == null) return;
    setState(() => _notificationStyle = newValue);
    // Note: This only updates local view. To persist style,
    // we'd need to update the full profile, which is complex here.
    // Ideally we call an API to patch the profile.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildPermissionSection(),
                const Divider(),
                _buildPreferenceSection(),
              ],
            ),
    );
  }

  Widget _buildPermissionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Permissions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Allow Notifications'),
          subtitle: Text(
            _areNotificationsEnabled
                ? 'You are receiving updates'
                : 'Enable to stay on track with your goals',
          ),
          value: _areNotificationsEnabled,
          onChanged: (val) => _toggleNotifications(val),
          secondary: Icon(
            _areNotificationsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off,
            color: _areNotificationsEnabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceSection() {
    final style =
        _notificationStyle != null && _styles.contains(_notificationStyle)
        ? _notificationStyle
        : _styles.first; // Default to 'Direct' if unknown/null

    return Opacity(
      opacity: _areNotificationsEnabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !_areNotificationsEnabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Preferences',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Check-in Frequency'),
              subtitle: const Text('How often should we ping you?'),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _checkInFrequency ?? 'Daily',
                  items: _frequencies
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: _updateFrequency,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.style),
              title: const Text('Notification Style'),
              subtitle: const Text('Tone of voice for messages'),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: style,
                  items: _styles
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: _updateStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
