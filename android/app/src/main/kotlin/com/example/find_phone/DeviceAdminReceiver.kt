package com.example.find_phone

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class DeviceAdminReceiver : DeviceAdminReceiver() {
    
    companion object {
        private const val TAG = "DeviceAdminReceiver"
        
        // SharedPreferences constants
        const val PREFS_NAME = "device_admin_prefs"
        const val KEY_DEACTIVATION_ALLOWED_UNTIL = "deactivation_allowed_until"
        const val KEY_PROTECTED_MODE_ACTIVE = "protected_mode_active"
        const val KEY_UNINSTALL_REQUESTED = "uninstall_requested"
        const val DEACTIVATION_WINDOW_MS = 30000L // 30 seconds
        
        /**
         * Mark that uninstall was requested from within the app
         */
        fun requestUninstall(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_UNINSTALL_REQUESTED, true).apply()
            Log.d(TAG, "Uninstall requested - will allow deactivation")
        }
        
        /**
         * Check if uninstall was requested
         */
        fun isUninstallRequested(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getBoolean(KEY_UNINSTALL_REQUESTED, false)
        }
        
        /**
         * Clear uninstall request
         */
        fun clearUninstallRequest(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove(KEY_UNINSTALL_REQUESTED).apply()
        }
    }
    
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device Admin Enabled")
        clearUninstallRequest(context)
    }
    
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device Admin Disabled")
        clearUninstallRequest(context)
    }
    
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence? {
        // Check if uninstall was requested from within the app
        if (isUninstallRequested(context)) {
            Log.d(TAG, "Uninstall requested from app - allowing deactivation")
            return null // Allow deactivation without warning
        }
        
        // Check if deactivation is allowed (30-second window)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val allowedUntil = prefs.getLong(KEY_DEACTIVATION_ALLOWED_UNTIL, 0)
        
        if (System.currentTimeMillis() < allowedUntil) {
            Log.d(TAG, "Deactivation allowed within window")
            return null // Allow deactivation
        }
        
        // Show warning message
        return "تحذير: إلغاء صلاحيات المسؤول سيعطل حماية الجهاز من السرقة!"
    }
    
    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.d(TAG, "Password Changed")
    }
    
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.d(TAG, "Password Failed")
    }
}
