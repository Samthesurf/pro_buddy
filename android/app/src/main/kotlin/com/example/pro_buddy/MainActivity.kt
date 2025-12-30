package com.example.pro_buddy

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pro_buddy/usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageStatsSettings" -> {
                    openUsageStatsSettings()
                    result.success(true)
                }
                "getUsageStats" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 60
                    val stats = getUsageStats(durationMinutes)
                    result.success(stats)
                }
                "getDailyUsageStats" -> {
                    val stats = getDailyUsageStats()
                    result.success(stats)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageStatsSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to app settings if usage access settings not available
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = android.net.Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun getUsageStats(durationMinutes: Int): List<Map<String, Any?>> {
        if (!hasUsageStatsPermission()) {
            return emptyList()
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - (durationMinutes * 60 * 1000L)

        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            startTime,
            endTime
        )

        return processUsageStats(usageStatsList)
    }

    private fun getDailyUsageStats(): List<Map<String, Any?>> {
        if (!hasUsageStatsPermission()) {
            return emptyList()
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Get start of today
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        return processUsageStats(usageStatsList)
    }

    private fun processUsageStats(usageStatsList: List<UsageStats>?): List<Map<String, Any?>> {
        if (usageStatsList.isNullOrEmpty()) {
            return emptyList()
        }

        val packageManager = packageManager
        val result = mutableListOf<Map<String, Any?>>()

        for (stats in usageStatsList) {
            // Skip apps with no usage time
            if (stats.totalTimeInForeground == 0L) {
                continue
            }

            // Skip system apps that users don't interact with directly
            val packageName = stats.packageName
            if (isSystemPackage(packageName)) {
                continue
            }

            // Get app name
            val appName = try {
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                packageName // Use package name if app name not found
            }

            result.add(mapOf(
                "packageName" to packageName,
                "appName" to appName,
                "usageTimeMs" to stats.totalTimeInForeground,
                "lastTimeUsed" to stats.lastTimeUsed
            ))
        }

        // Sort by usage time descending
        return result.sortedByDescending { it["usageTimeMs"] as Long }
    }

    private fun isSystemPackage(packageName: String): Boolean {
        // List of system packages to exclude
        val systemPackages = listOf(
            "com.android.",
            "com.google.android.apps.nexuslauncher",
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.google.android.providers",
            "com.google.android.ext",
            "com.google.android.inputmethod",
            "com.google.android.packageinstaller",
            "com.google.android.permissioncontroller",
            "com.google.android.setupwizard",
            "com.google.android.documentsui",
            "com.samsung.",
            "com.sec.",
            "com.huawei.",
            "com.oppo.",
            "com.vivo.",
            "com.xiaomi.",
            "com.miui.",
            "com.oneplus.",
            "com.coloros.",
            "android",
            "com.android"
        )

        for (prefix in systemPackages) {
            if (packageName.startsWith(prefix)) {
                return true
            }
        }

        // Also check if it's a system app via PackageManager
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
                    (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
