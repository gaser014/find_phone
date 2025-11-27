package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Boot Completed Broadcast Receiver for Anti-Theft Protection
 * 
 * This receiver handles device boot events to:
 * - Start the app automatically after boot (Requirement 2.5)
 * - Restore Protected Mode state from encrypted storage (Requirement 2.5)
 * - Detect Safe Mode boot (Requirement 20.1)
 * - Start foreground service for persistent monitoring
 * 
 * Requirements: 2.5, 20.1
 */
class BootCompletedReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootCompletedReceiver"
        
        // Shared preferences keys
        const val PREFS_NAME = "boot_receiver_prefs"
        const val KEY_LAST_BOOT_TIME = "last_boot_time"
        const val KEY_BOOT_COUNT = "boot_count"
        const val KEY_LAST_SAFE_MODE_BOOT = "last_safe_mode_boot"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "Boot event received: $action")
        
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_REBOOT -> {
                handleBootCompleted(context)
            }
        }
    }

    /**
     * Handle boot completed event
     * Requirement 2.5: Start automatically via BOOT_COMPLETED receiver
     */
    private fun handleBootCompleted(context: Context) {
        Log.i(TAG, "Device boot completed - initializing anti-theft protection")
        
        // Record boot event
        recordBootEvent(context)
        
        // Check for Safe Mode boot (Requirement 20.1)
        val isSafeMode = detectSafeMode(context)
        if (isSafeMode) {
            handleSafeModeBoot(context)
        }
        
        // Check if Protected Mode was active before shutdown
        val shouldRestoreProtection = shouldRestoreProtectedMode(context)
        
        if (shouldRestoreProtection) {
            Log.i(TAG, "Restoring Protected Mode after boot")
            
            // Start the foreground service for persistent monitoring
            startProtectionService(context)
            
            // Notify Flutter about boot restoration
            notifyFlutter(context, "BOOT_COMPLETED", mapOf(
                "protected_mode_restored" to true,
                "safe_mode" to isSafeMode,
                "timestamp" to System.currentTimeMillis()
            ))
        } else {
            Log.i(TAG, "Protected Mode was not active - skipping restoration")
            
            // Still notify Flutter about boot
            notifyFlutter(context, "BOOT_COMPLETED", mapOf(
                "protected_mode_restored" to false,
                "safe_mode" to isSafeMode,
                "timestamp" to System.currentTimeMillis()
            ))
        }
        
        // Schedule auto-restart job for persistence
        scheduleAutoRestartJob(context)
    }

    /**
     * Record boot event for tracking
     */
    private fun recordBootEvent(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val bootCount = prefs.getInt(KEY_BOOT_COUNT, 0) + 1
        
        prefs.edit()
            .putLong(KEY_LAST_BOOT_TIME, System.currentTimeMillis())
            .putInt(KEY_BOOT_COUNT, bootCount)
            .apply()
        
        Log.i(TAG, "Boot event recorded - total boots: $bootCount")
    }

    /**
     * Detect if device booted in Safe Mode
     * Requirement 20.1: Detect Safe Mode boot and trigger alarm
     */
    private fun detectSafeMode(context: Context): Boolean {
        return try {
            // Check if device is in safe mode using system properties
            isSafeModeEnabled()
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting Safe Mode: ${e.message}")
            false
        }
    }

    /**
     * Check if Safe Mode is enabled using system properties
     */
    private fun isSafeModeEnabled(): Boolean {
        return try {
            val systemProperties = Class.forName("android.os.SystemProperties")
            val getMethod = systemProperties.getMethod("get", String::class.java, String::class.java)
            val safeMode = getMethod.invoke(null, "ro.sys.safemode", "0") as String
            safeMode == "1"
        } catch (e: Exception) {
            Log.e(TAG, "Error checking system properties for Safe Mode: ${e.message}")
            false
        }
    }

    /**
     * Handle Safe Mode boot
     * Requirement 20.1: Trigger alarm immediately upon Safe Mode boot
     */
    private fun handleSafeModeBoot(context: Context) {
        Log.w(TAG, "SAFE MODE DETECTED - Device may be compromised!")
        
        // Record Safe Mode boot
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_LAST_SAFE_MODE_BOOT, System.currentTimeMillis())
            .apply()
        
        // Log security event
        logSecurityEvent(context, "safe_mode_detected", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "severity" to "critical"
        ))
        
        // Notify Flutter to trigger alarm and send SMS alert
        notifyFlutter(context, "SAFE_MODE_DETECTED", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "trigger_alarm" to true,
            "send_sms_alert" to true
        ))
    }

    /**
     * Check if Protected Mode should be restored after boot
     * Requirement 2.5: Restore Protected Mode state from encrypted storage
     */
    private fun shouldRestoreProtectedMode(context: Context): Boolean {
        // Check Accessibility Service preferences
        val accessibilityPrefs = context.getSharedPreferences(
            AntiTheftAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val protectedModeActive = accessibilityPrefs.getBoolean(
            AntiTheftAccessibilityService.KEY_PROTECTED_MODE_ACTIVE,
            false
        )
        
        // Also check Device Admin preferences
        val deviceAdminPrefs = context.getSharedPreferences(
            DeviceAdminReceiver.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val deviceAdminProtected = deviceAdminPrefs.getBoolean(
            DeviceAdminReceiver.KEY_PROTECTED_MODE_ACTIVE,
            false
        )
        
        return protectedModeActive || deviceAdminProtected
    }

    /**
     * Start the Protection Foreground Service
     */
    private fun startProtectionService(context: Context) {
        try {
            val serviceIntent = Intent(context, ProtectionForegroundService::class.java)
            serviceIntent.action = ProtectionForegroundService.ACTION_START_PROTECTION
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.i(TAG, "Protection foreground service started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting protection service: ${e.message}")
        }
    }

    /**
     * Schedule auto-restart job for persistence
     * Requirement 2.4: Auto-restart using JobScheduler
     */
    private fun scheduleAutoRestartJob(context: Context) {
        try {
            AutoRestartJobService.scheduleJob(context)
            Log.i(TAG, "Auto-restart job scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling auto-restart job: ${e.message}")
        }
    }

    /**
     * Send notification to Flutter side via broadcast
     */
    private fun notifyFlutter(context: Context, action: String, extras: Map<String, Any>? = null) {
        val intent = Intent("com.example.find_phone.BOOT_EVENT")
        intent.putExtra("action", action)
        intent.putExtra("timestamp", System.currentTimeMillis())
        extras?.forEach { (key, value) ->
            when (value) {
                is String -> intent.putExtra(key, value)
                is Int -> intent.putExtra(key, value)
                is Long -> intent.putExtra(key, value)
                is Boolean -> intent.putExtra(key, value)
            }
        }
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }

    /**
     * Log security event for tracking
     */
    private fun logSecurityEvent(context: Context, eventType: String, metadata: Map<String, Any>) {
        val intent = Intent("com.example.find_phone.SECURITY_EVENT")
        intent.putExtra("event_type", eventType)
        intent.putExtra("timestamp", System.currentTimeMillis())
        metadata.forEach { (key, value) ->
            when (value) {
                is String -> intent.putExtra(key, value)
                is Int -> intent.putExtra(key, value)
                is Long -> intent.putExtra(key, value)
                is Boolean -> intent.putExtra(key, value)
            }
        }
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }
}
