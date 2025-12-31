import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class AppIconWidget extends StatelessWidget {
  final String packageName;
  final double size;

  const AppIconWidget({super.key, required this.packageName, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInfo?>(
      future: InstalledApps.getAppInfo(packageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data?.icon != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.memory(
              snapshot.data!.icon!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }

        // Fallback icon
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Icon(
            Icons.apps_rounded,
            size: size * 0.6,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        );
      },
    );
  }
}
