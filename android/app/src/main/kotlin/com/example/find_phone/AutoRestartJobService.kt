package com.example.find_phone

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Job Service for Auto-Restart functionality
 * 
 * This service provides:
 * - Automatic restart of protection service within 3 seconds (Requirement 2.4)
 * - Periodic health checks for service persistence
 * - Force-stop detection and recovery (Requirement 2.6)
 * 
 * Requirements: 2.4, 2.6
 */
class AutoRestartJobService : JobService() {

    companion object {
        private const val TAG = "AutoRestartJobService"
        
        // Job IDs
        const val JOB_ID_PERIODIC_CHECK = 1001
        const val JOB_ID_IMMEDIATE_RESTART = 1002
        
        // Shared preferences
        const val PREFS_NAME = "auto_restart_prefs"
        const val KEY_LAST_CHECK_TIME = "last_check_time"
        const val KEY_RESTART_COUNT = "restart_count"
        const val KEY_LAST_RESTART_TIME = "last_restart_time"
        
        // Timing constants
        const val PERIODIC_CHECK_INTERVAL_MS = 15 * 60 * 1000L // 15 minutes
        const val IMMEDIATE_RESTART_DELAY_MS = 1000L // 1 second (within 3 second requirement)
        const val MAX_RESTART_DELAY_MS = 3000L // 3 seconds max
        
        /**
         * Schedule periodic health check job
         */
        fun scheduleJob(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            
            val componentName = ComponentName(context, AutoRestartJobService::class.java)
            
            val jobInfo = JobInfo.Builder(JOB_ID_PERIODIC_CHECK, componentName)
                .setPeriodic(PERIODIC_CHECK_INTERVAL_MS)
                .setPersisted(true) // Survive reboots
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_NONE)
                .build()
            
            val result = jobScheduler.schedule(jobInfo)
            
            if (result == JobScheduler.RESULT_SUCCESS) {
                Log.i(TAG, "Periodic health check job scheduled successfully")
            } else {
                Log.e(TAG, "Failed to schedule periodic health check job")
            }
        }
        
        /**
         * Schedule immediate restart job (within 3 seconds)
         * Requirement 2.4: Auto-restart within 3 seconds
         */
        fun scheduleImmediateRestart(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            
            val componentName = ComponentName(context, AutoRestartJobService::class.java)
            
            val jobInfoBuilder = JobInfo.Builder(JOB_ID_IMMEDIATE_RESTART, componentName)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_NONE)
                .setPersisted(true)
            
            // Set minimum latency for immediate execution
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                jobInfoBuilder.setMinimumLatency(IMMEDIATE_RESTART_DELAY_MS)
                jobInfoBuilder.setOverrideDeadline(MAX_RESTART_DELAY_MS)
            } else {
                jobInfoBuilder.setOverrideDeadline(MAX_RESTART_DELAY_MS)
            }
            
            val result = jobScheduler.schedule(jobInfoBuilder.build())
            
            if (result == JobScheduler.RESULT_SUCCESS) {
                Log.i(TAG, "Immediate restart job scheduled successfully")
            } else {
                Log.e(TAG, "Failed to schedule immediate restart job")
            }
        }
        
        /**
         * Cancel all scheduled jobs
         */
        fun cancelAllJobs(context: Context) {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            jobScheduler.cancelAll()
            Log.i(TAG, "All jobs cancelled")
        }
        
        /**
         * Check if periodic job is scheduled
         */
        fun isJobScheduled(context: Context): Boolean {
            val jobScheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            
            for (jobInfo in jobScheduler.allPendingJobs) {
                if (jobInfo.id == JOB_ID_PERIODIC_CHECK) {
                    return true
                }
            }
            return false
        }
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        Log.i(TAG, "Job started: ${params?.jobId}")
        
        when (params?.jobId) {
            JOB_ID_PERIODIC_CHECK -> {
                performHealthCheck(params)
            }
            JOB_ID_IMMEDIATE_RESTART -> {
                performImmediateRestart(params)
            }
        }
        
        return false // Job is complete
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        Log.w(TAG, "Job stopped: ${params?.jobId}")
        return true // Reschedule if stopped
    }

    /**
     * Perform periodic health check
     */
    private fun performHealthCheck(params: JobParameters) {
        Log.i(TAG, "Performing periodic health check")
        
        // Record check time
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putLong(KEY_LAST_CHECK_TIME, System.currentTimeMillis())
            .apply()
        
        // Check if Protected Mode should be active
        val shouldBeProtected = shouldProtectionBeActive()
        
        // Check if Protection Service is running
        val isServiceRunning = ProtectionForegroundService.isServiceRunning()
        
        Log.i(TAG, "Health check - Should be protected: $shouldBeProtected, Service running: $isServiceRunning")
        
        if (shouldBeProtected && !isServiceRunning) {
            Log.w(TAG, "Protection service not running but should be - restarting")
            restartProtectionService()
            
            // Log as force-stop recovery
            logSecurityEvent("protection_service_recovered", mapOf(
                "timestamp" to System.currentTimeMillis(),
                "reason" to "health_check"
            ))
        }
        
        // Check Accessibility Service
        val isAccessibilityRunning = AntiTheftAccessibilityService.isServiceRunning()
        if (shouldBeProtected && !isAccessibilityRunning) {
            Log.w(TAG, "Accessibility service not running - notifying user")
            notifyFlutter("ACCESSIBILITY_SERVICE_STOPPED", mapOf(
                "timestamp" to System.currentTimeMillis()
            ))
        }
        
        jobFinished(params, false)
    }

    /**
     * Perform immediate restart after force-stop
     * Requirement 2.4: Restart within 3 seconds
     */
    private fun performImmediateRestart(params: JobParameters) {
        Log.i(TAG, "Performing immediate restart")
        
        // Record restart
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val restartCount = prefs.getInt(KEY_RESTART_COUNT, 0) + 1
        
        prefs.edit()
            .putInt(KEY_RESTART_COUNT, restartCount)
            .putLong(KEY_LAST_RESTART_TIME, System.currentTimeMillis())
            .apply()
        
        Log.i(TAG, "Restart count: $restartCount")
        
        // Restart protection service
        restartProtectionService()
        
        // Log the restart event (Requirement 2.6)
        logSecurityEvent("app_restarted_after_force_stop", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "restart_count" to restartCount,
            "trigger_alarm" to true
        ))
        
        // Notify Flutter to trigger alarm
        notifyFlutter("APP_RESTARTED_AFTER_FORCE_STOP", mapOf(
            "restart_count" to restartCount,
            "trigger_alarm" to true
        ))
        
        jobFinished(params, false)
    }

    /**
     * Check if protection should be active
     */
    private fun shouldProtectionBeActive(): Boolean {
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
     * Restart the Protection Foreground Service
     */
    private fun restartProtectionService() {
        try {
            val serviceIntent = Intent(this, ProtectionForegroundService::class.java)
            serviceIntent.action = ProtectionForegroundService.ACTION_START_PROTECTION
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            
            Log.i(TAG, "Protection service restart initiated")
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting protection service: ${e.message}")
        }
    }

    /**
     * Notify Flutter via broadcast
     */
    private fun notifyFlutter(action: String, extras: Map<String, Any>? = null) {
        val intent = Intent("com.example.find_phone.AUTO_RESTART_EVENT")
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
