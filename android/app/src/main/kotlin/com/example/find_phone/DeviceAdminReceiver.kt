package com.example.find_phone

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

/**
 * Device Administrator Receiver for Anti-Theft Protection
 * 
 * This receiver handles Device Administrator events including:
 * - Admin enabled/disabled notifications
 * - Intercepting deactivation attempts (Requirement 2.2)
 * - Password failure monitoring
 * 
 * Requirements: 2.1, 2.2
 */
class DeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        private const val TAG = "DeviceAdminReceiver"
        
        // Shared preferences key for deactivation window
        const val PREFS_NAME = "device_admin_prefs"
        const val KEY_DEACTIVATION_ALLOWED_UNTIL = "deactivation_allowed_until"
        const val KEY_PROTECTED_MODE_ACTIVE = "protected_mode_active"
        
        // Deactivation window duration in milliseconds (30 seconds)
        const val DEACTIVATION_WINDOW_MS = 30_000L
    }

    /**
     * Called when the Device Administrator is enabled
     */
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.i(TAG, "Device Administrator enabled")
        Toast.makeText(context, "تم تفعيل صلاحيات المسؤول", Toast.LENGTH_SHORT).show()
        
        // Notify Flutter side via broadcast
        notifyFlutter(context, "DEVICE_ADMIN_ENABLED")
    }

    /**
     * Called when the user attempts to disable Device Administrator
     * Returns a warning message that will be displayed to the user
     * 
     * Requirement 2.2: Intercept deactivation attempts and display password prompt
     */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        Log.w(TAG, "Device Administrator disable requested")
        
        // Check if protected mode is active
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val protectedModeActive = prefs.getBoolean(KEY_PROTECTED_MODE_ACTIVE, false)
        
        if (protectedModeActive) {
            // Check if we're within the allowed deactivation window
            val allowedUntil = prefs.getLong(KEY_DEACTIVATION_ALLOWED_UNTIL, 0)
            val currentTime = System.currentTimeMillis()
            
            if (currentTime < allowedUntil) {
                // Within deactivation window - allow deactivation
                Log.i(TAG, "Deactivation allowed - within 30-second window")
                return "سيتم إلغاء تفعيل صلاحيات المسؤول. هل أنت متأكد؟"
            } else {
                // Not within window - show warning and trigger password prompt
                Log.w(TAG, "Deactivation blocked - protected mode active, no valid window")
                
                // Notify Flutter to show password overlay
                notifyFlutter(context, "DEVICE_ADMIN_DISABLE_REQUESTED")
                
                // Log this as suspicious activity
                logSuspiciousActivity(context, "device_admin_disable_attempt")
                
                return "⚠️ تحذير: وضع الحماية مفعل!\n\n" +
                       "لإلغاء تفعيل صلاحيات المسؤول، يجب إدخال كلمة المرور الرئيسية أولاً.\n\n" +
                       "إذا لم تكن المالك الشرعي للجهاز، سيتم تسجيل هذه المحاولة وإرسال تنبيه."
            }
        }
        
        return "هل تريد إلغاء تفعيل صلاحيات المسؤول؟"
    }

    /**
     * Called when the Device Administrator is disabled
     */
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.i(TAG, "Device Administrator disabled")
        Toast.makeText(context, "تم إلغاء تفعيل صلاحيات المسؤول", Toast.LENGTH_SHORT).show()
        
        // Clear deactivation window
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_DEACTIVATION_ALLOWED_UNTIL).apply()
        
        // Notify Flutter side
        notifyFlutter(context, "DEVICE_ADMIN_DISABLED")
    }

    /**
     * Called when the user enters an incorrect password on the lock screen
     * Used for monitoring failed unlock attempts (Requirement 17.1)
     */
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.w(TAG, "Password failed on lock screen")
        
        // Notify Flutter to handle failed attempt
        notifyFlutter(context, "PASSWORD_FAILED")
    }

    /**
     * Called when the user successfully enters the password on the lock screen
     */
    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        Log.i(TAG, "Password succeeded on lock screen")
        
        // Notify Flutter
        notifyFlutter(context, "PASSWORD_SUCCEEDED")
    }

    /**
     * Called when the password is changed
     */
    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.i(TAG, "Device password changed")
        
        // Notify Flutter - this might be suspicious if protected mode is active
        notifyFlutter(context, "PASSWORD_CHANGED")
    }

    /**
     * Send notification to Flutter side via broadcast
     */
    private fun notifyFlutter(context: Context, action: String) {
        val broadcastIntent = Intent("com.example.find_phone.DEVICE_ADMIN_EVENT")
        broadcastIntent.putExtra("action", action)
        broadcastIntent.putExtra("timestamp", System.currentTimeMillis())
        broadcastIntent.setPackage(context.packageName)
        context.sendBroadcast(broadcastIntent)
    }

    /**
     * Log suspicious activity for security tracking
     */
    private fun logSuspiciousActivity(context: Context, eventType: String) {
        val broadcastIntent = Intent("com.example.find_phone.SUSPICIOUS_ACTIVITY")
        broadcastIntent.putExtra("event_type", eventType)
        broadcastIntent.putExtra("timestamp", System.currentTimeMillis())
        broadcastIntent.setPackage(context.packageName)
        context.sendBroadcast(broadcastIntent)
    }
}
