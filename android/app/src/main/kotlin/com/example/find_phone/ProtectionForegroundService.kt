package com.example.find_phone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground Service for Anti-Theft Protection
 * 
 * This service provides:
 * - Persistent background monitoring (Requirement 2.4, 5.5)
 * - Protected Mode state management
 * - Force-stop detection and auto-restart (Requirement 2.6)
 * - Location tracking coordination
 * 
 * Requirements: 2.4, 2.5, 2.6, 5.5, 10.4
 */
class ProtectionForegroundService : Service() {

    companion object {
        private const val TAG = "ProtectionService"
        
        // Notification constants
        const val NOTIFICATION_CHANNEL_ID = "anti_theft_protection_channel"
        const val NOTIFICATION_ID = 1001
        
        // Service actions
        const val ACTION_START_PROTECTION = "com.example.find_phone.START_PROTECTION"
        const val ACTION_STOP_PROTECTION = "com.example.find_phone.STOP_PROTECTION"
        const val ACTION_UPDATE_STATUS = "com.example.find_phone.UPDATE_STATUS"
        
        // Shared preferences
        const val PREFS_NAME = "protection_service_prefs"
        const val KEY_SERVICE_RUNNING = "service_running"
        const val KEY_LAST_HEARTBEAT = "last_heartbeat"
        const val KEY_START_COUNT = "start_count"
        
        // Heartbeat interval (30 seconds)
        const val HEARTBEAT_INTERVAL_MS = 30_000L
        
        @Volatile
        private var instance: ProtectionForegroundService? = null
        
        fun getInstance(): ProtectionForegroundService? = instance
        
        fun isServiceRunning(): Boolean = instance != null
    }

    private var isProtectedModeActive = false
    private val heartbeatRunnable = object : Runnable {
        override fun run() {
            recordHeartbeat()
            handler.postDelayed(this, HEARTBEAT_INTERVAL_MS)
        }
    }
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    
    // Broadcast receiver for commands
    private val commandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let { handleCommand(it) }
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "ProtectionForegroundService created")
        instance = this
        
        createNotificationChannel()
        registerCommandReceiver()
        loadState()
        
        // Record service start
        recordServiceStart()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "ProtectionForegroundService onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_PROTECTION -> {
                startProtection()
            }
            ACTION_STOP_PROTECTION -> {
                stopProtection()
            }
            ACTION_UPDATE_STATUS -> {
                updateNotification()
            }
            else -> {
                // Default: start protection if Protected Mode was active
                if (shouldRestoreProtection()) {
                    startProtection()
                }
            }
        }
        
        // Return START_STICKY to ensure service restarts if killed
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.w(TAG, "ProtectionForegroundService destroyed")
        instance = null
        
        // Stop heartbeat
        handler.removeCallbacks(heartbeatRunnable)
        
        // Unregister receiver
        try {
            unregisterReceiver(commandReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        
        // If Protected Mode is active, this is a force-stop - log and restart
        if (isProtectedModeActive) {
            Log.w(TAG, "Service destroyed while Protected Mode active - force-stop detected!")
            handleForceStop()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(TAG, "Task removed - app swiped from recent apps")
        
        if (isProtectedModeActive) {
            // Log as suspicious activity (Requirement 2.6)
            logSecurityEvent("app_task_removed", mapOf(
                "timestamp" to System.currentTimeMillis(),
                "protected_mode_active" to true
            ))
            
            // Schedule restart
            scheduleRestart()
        }
    }

    /**
     * Start protection monitoring
     */
    private fun startProtection() {
        Log.i(TAG, "Starting protection monitoring")
        isProtectedModeActive = true
        saveState()
        
        // Start foreground with notification
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Start heartbeat
        handler.post(heartbeatRunnable)
        
        // Notify Flutter
        notifyFlutter("PROTECTION_SERVICE_STARTED")
    }

    /**
     * Stop protection monitoring
     */
    private fun stopProtection() {
        Log.i(TAG, "Stopping protection monitoring")
        isProtectedModeActive = false
        saveState()
        
        // Stop heartbeat
        handler.removeCallbacks(heartbeatRunnable)
        
        // Stop foreground
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        
        // Notify Flutter
        notifyFlutter("PROTECTION_SERVICE_STOPPED")
    }

    /**
     * Handle force-stop detection
     * Requirement 2.6: Log force-stop as suspicious activity and restart
     */
    private fun handleForceStop() {
        Log.w(TAG, "Force-stop detected - logging and scheduling restart")
        
        // Log security event
        logSecurityEvent("app_force_stopped", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "severity" to "high"
        ))
        
        // Schedule restart using JobScheduler
        scheduleRestart()
        
        // Also try to send SMS alert if possible
        notifyFlutter("FORCE_STOP_DETECTED", mapOf(
            "trigger_alarm" to true,
            "send_sms_alert" to true
        ))
    }

    /**
     * Schedule service restart
     * Requirement 2.4: Auto-restart within 3 seconds
     */
    private fun scheduleRestart() {
        try {
            AutoRestartJobService.scheduleImmediateRestart(this)
            Log.i(TAG, "Restart scheduled via JobScheduler")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling restart: ${e.message}")
            
            // Fallback: use AlarmManager
            scheduleRestartViaAlarm()
        }
    }

    /**
     * Fallback restart using AlarmManager
     */
    private fun scheduleRestartViaAlarm() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, BootCompletedReceiver::class.java)
            intent.action = Intent.ACTION_BOOT_COMPLETED
            
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Schedule for 3 seconds from now
            val triggerTime = System.currentTimeMillis() + 3000
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }
            
            Log.i(TAG, "Restart scheduled via AlarmManager")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling restart via AlarmManager: ${e.message}")
        }
    }

    /**
     * Create notification channel for Android O+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "حماية الجهاز",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "خدمة حماية الجهاز من السرقة"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * Create notification for foreground service
     */
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("حماية الجهاز مفعلة")
            .setContentText("جهازك محمي من السرقة")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }

    /**
     * Update notification
     */
    private fun updateNotification() {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, createNotification())
    }

    /**
     * Register command receiver
     */
    private fun registerCommandReceiver() {
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.PROTECTION_SERVICE_COMMAND")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(commandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(commandReceiver, filter)
        }
    }

    /**
     * Handle commands from Flutter
     */
    private fun handleCommand(intent: Intent) {
        val command = intent.getStringExtra("command") ?: return
        Log.d(TAG, "Received command: $command")
        
        when (command) {
            "START_PROTECTION" -> startProtection()
            "STOP_PROTECTION" -> stopProtection()
            "UPDATE_STATUS" -> updateNotification()
        }
    }

    /**
     * Record heartbeat for monitoring
     */
    private fun recordHeartbeat() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_LAST_HEARTBEAT, System.currentTimeMillis())
            .apply()
    }

    /**
     * Record service start
     */
    private fun recordServiceStart() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val startCount = prefs.getInt(KEY_START_COUNT, 0) + 1
        
        prefs.edit()
            .putBoolean(KEY_SERVICE_RUNNING, true)
            .putInt(KEY_START_COUNT, startCount)
            .apply()
        
        Log.i(TAG, "Service start recorded - total starts: $startCount")
    }

    /**
     * Load state from preferences
     */
    private fun loadState() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isProtectedModeActive = prefs.getBoolean(KEY_SERVICE_RUNNING, false)
    }

    /**
     * Save state to preferences
     */
    private fun saveState() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_SERVICE_RUNNING, isProtectedModeActive)
            .apply()
    }

    /**
     * Check if protection should be restored
     */
    private fun shouldRestoreProtection(): Boolean {
        val accessibilityPrefs = getSharedPreferences(
            AntiTheftAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        return accessibilityPrefs.getBoolean(
            AntiTheftAccessibilityService.KEY_PROTECTED_MODE_ACTIVE,
            false
        )
    }

    /**
     * Notify Flutter via broadcast
     */
    private fun notifyFlutter(action: String, extras: Map<String, Any>? = null) {
        val intent = Intent("com.example.find_phone.PROTECTION_SERVICE_EVENT")
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
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Log security event
     */
    private fun logSecurityEvent(eventType: String, metadata: Map<String, Any>) {
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
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }
}
