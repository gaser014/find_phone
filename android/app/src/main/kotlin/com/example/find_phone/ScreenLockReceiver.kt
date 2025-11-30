package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Receiver for screen lock/unlock events.
 * 
 * Automatically enables Kiosk Mode when screen is locked
 * and shows password entry screen when unlocked.
 * 
 * Requirements:
 * - Enable Kiosk Mode on screen lock
 * - Show password entry on screen unlock
 * - Enable mobile data when Kiosk Mode activates
 * - Block USB connections
 */
class ScreenLockReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ScreenLockReceiver"
        const val PREFS_NAME = "screen_lock_prefs"
        const val KEY_KIOSK_ON_LOCK_ENABLED = "kiosk_on_lock_enabled"
        const val KEY_AUTO_ENABLE_DATA = "auto_enable_data"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "ScreenLockReceiver received: ${intent.action}")
        
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val kioskOnLockEnabled = prefs.getBoolean(KEY_KIOSK_ON_LOCK_ENABLED, false)
        
        Log.i(TAG, "Kiosk on Lock enabled: $kioskOnLockEnabled")
        
        // Only check if Kiosk on Lock is enabled (no need for Protected Mode)
        if (!kioskOnLockEnabled) {
            Log.i(TAG, "Kiosk on Lock is disabled, ignoring event")
            return
        }

        when (intent.action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.i(TAG, "Screen OFF - Enabling Kiosk Mode")
                handleScreenOff(context)
            }
            Intent.ACTION_SCREEN_ON -> {
                Log.i(TAG, "Screen ON - Showing Kiosk Lock Screen")
                handleScreenOn(context)
            }
            Intent.ACTION_USER_PRESENT -> {
                Log.i(TAG, "User Present - Device unlocked, showing password entry")
                handleUserPresent(context)
            }
        }
    }

    /**
     * Handle screen off - prepare Kiosk Mode
     */
    private fun handleScreenOff(context: Context) {
        Log.i(TAG, "Screen OFF - preparing Kiosk Mode")
        
        // Save state that Kiosk should be active
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean("kiosk_pending", true).apply()
        
        // Log security event
        logSecurityEvent(context, "screen_locked", mapOf(
            "kiosk_pending" to true
        ))
    }

    /**
     * Handle screen on - show Kiosk Lock Screen
     */
    private fun handleScreenOn(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val kioskPending = prefs.getBoolean("kiosk_pending", false)
        
        if (kioskPending) {
            // Enable mobile data
            val autoEnableData = prefs.getBoolean(KEY_AUTO_ENABLE_DATA, true)
            if (autoEnableData) {
                enableMobileData(context)
            }
            
            // Show Kiosk Lock Screen Activity
            showKioskLockScreen(context)
        }
    }

    /**
     * Handle user present (device unlocked with system lock)
     */
    private fun handleUserPresent(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val kioskPending = prefs.getBoolean("kiosk_pending", false)
        
        if (kioskPending) {
            // Show our Kiosk Lock Screen on top
            showKioskLockScreen(context)
        }
    }

    /**
     * Show Kiosk Lock Screen Activity
     */
    private fun showKioskLockScreen(context: Context) {
        val intent = Intent(context, KioskLockActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
            Intent.FLAG_ACTIVITY_SINGLE_TOP or
            Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
        )
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        
        context.startActivity(intent)
        
        // Notify Flutter
        val notifyIntent = Intent("com.example.find_phone.KIOSK_EVENT")
        notifyIntent.putExtra("action", "KIOSK_LOCK_SCREEN_SHOWN")
        notifyIntent.putExtra("timestamp", System.currentTimeMillis())
        notifyIntent.setPackage(context.packageName)
        context.sendBroadcast(notifyIntent)
    }

    /**
     * Enable mobile data
     */
    private fun enableMobileData(context: Context) {
        try {
            // Send command to enable mobile data
            val intent = Intent("com.example.find_phone.DATA_COMMAND")
            intent.putExtra("command", "ENABLE_MOBILE_DATA")
            intent.setPackage(context.packageName)
            context.sendBroadcast(intent)
            
            Log.i(TAG, "Mobile data enable command sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling mobile data: ${e.message}")
        }
    }

    /**
     * Block USB connections
     */
    private fun blockUsb(context: Context) {
        try {
            val intent = Intent("com.example.find_phone.USB_COMMAND")
            intent.putExtra("command", "BLOCK_USB")
            intent.setPackage(context.packageName)
            context.sendBroadcast(intent)
            
            Log.i(TAG, "USB block command sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error blocking USB: ${e.message}")
        }
    }

    /**
     * Log security event
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
