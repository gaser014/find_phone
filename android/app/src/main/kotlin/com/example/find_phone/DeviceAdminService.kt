package com.example.find_phone

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Device Admin Service for Anti-Theft Protection
 * 
 * Provides device administration functionality including:
 * - Device locking (Requirement 8.1)
 * - Factory reset/wipe (Requirement 8.3)
 * - 30-second deactivation window management (Requirement 2.3)
 * - Device admin status checking
 * 
 * Requirements: 2.1, 2.2, 2.3, 8.1, 8.3
 */
class DeviceAdminService(private val context: Context) {

    companion object {
        private const val TAG = "DeviceAdminService"
        
        @Volatile
        private var instance: DeviceAdminService? = null
        
        fun getInstance(context: Context): DeviceAdminService {
            return instance ?: synchronized(this) {
                instance ?: DeviceAdminService(context.applicationContext).also { instance = it }
            }
        }
    }

    private val devicePolicyManager: DevicePolicyManager by lazy {
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }

    private val adminComponentName: ComponentName by lazy {
        ComponentName(context, DeviceAdminReceiver::class.java)
    }

    /**
     * Check if Device Administrator is active
     */
    fun isAdminActive(): Boolean {
        return devicePolicyManager.isAdminActive(adminComponentName)
    }

    /**
     * Request Device Administrator activation
     * Opens system dialog for user to grant admin permissions
     */
    fun requestAdminActivation(): Intent {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponentName)
        intent.putExtra(
            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
            "تطبيق الحماية من السرقة يحتاج صلاحيات المسؤول لحماية جهازك من السرقة والوصول غير المصرح به."
        )
        return intent
    }

    /**
     * Lock the device immediately
     * Requirement 8.1: LOCK command functionality
     * 
     * @return true if lock was successful, false otherwise
     */
    fun lockDevice(): Boolean {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.lockNow()
                Log.i(TAG, "Device locked successfully")
                
                // Notify Flutter about the lock
                notifyFlutter("DEVICE_LOCKED")
                true
            } else {
                Log.w(TAG, "Cannot lock device - admin not active")
                false
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception while locking device", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error locking device", e)
            false
        }
    }


    /**
     * Lock the device with a custom message displayed on lock screen
     * Requirement 8.2: Display custom message with owner contact info
     * 
     * @param message Custom message to display on lock screen
     * @return true if lock was successful, false otherwise
     */
    fun lockDeviceWithMessage(message: String): Boolean {
        return try {
            if (isAdminActive()) {
                // Set owner info message (displayed on lock screen)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    devicePolicyManager.setDeviceOwnerLockScreenInfo(adminComponentName, message)
                }
                
                devicePolicyManager.lockNow()
                Log.i(TAG, "Device locked with message: $message")
                
                notifyFlutter("DEVICE_LOCKED_WITH_MESSAGE")
                true
            } else {
                Log.w(TAG, "Cannot lock device with message - admin not active")
                false
            }
        } catch (e: SecurityException) {
            // setDeviceOwnerLockScreenInfo requires device owner, fall back to simple lock
            Log.w(TAG, "Cannot set lock screen message (not device owner), falling back to simple lock")
            return lockDevice()
        } catch (e: Exception) {
            Log.e(TAG, "Error locking device with message", e)
            false
        }
    }

    /**
     * Wipe all device data (factory reset)
     * Requirement 8.3: WIPE command functionality
     * 
     * WARNING: This will erase ALL user data on the device!
     * 
     * @param reason Reason for the wipe (for logging)
     * @return true if wipe was initiated, false otherwise
     */
    fun wipeDevice(reason: String = "Remote wipe command"): Boolean {
        return try {
            if (isAdminActive()) {
                Log.w(TAG, "Initiating device wipe. Reason: $reason")
                
                // Log the wipe event before executing
                logSecurityEvent("device_wipe_initiated", reason)
                
                // Notify Flutter before wipe (may not complete)
                notifyFlutter("DEVICE_WIPE_INITIATED")
                
                // Perform factory reset
                // WIPE_EXTERNAL_STORAGE flag wipes external storage as well
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    devicePolicyManager.wipeData(
                        DevicePolicyManager.WIPE_EXTERNAL_STORAGE or 
                        DevicePolicyManager.WIPE_SILENTLY,
                        reason
                    )
                } else {
                    devicePolicyManager.wipeData(DevicePolicyManager.WIPE_EXTERNAL_STORAGE)
                }
                
                true
            } else {
                Log.w(TAG, "Cannot wipe device - admin not active")
                false
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception while wiping device", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error wiping device", e)
            false
        }
    }

    /**
     * Set password quality requirements
     * 
     * @param quality Password quality level
     */
    fun setPasswordQuality(quality: Int): Boolean {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.setPasswordQuality(adminComponentName, quality)
                Log.i(TAG, "Password quality set to: $quality")
                true
            } else {
                Log.w(TAG, "Cannot set password quality - admin not active")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting password quality", e)
            false
        }
    }

    /**
     * Set minimum password length
     * 
     * @param length Minimum password length
     */
    fun setMinimumPasswordLength(length: Int): Boolean {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.setPasswordMinimumLength(adminComponentName, length)
                Log.i(TAG, "Minimum password length set to: $length")
                true
            } else {
                Log.w(TAG, "Cannot set minimum password length - admin not active")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting minimum password length", e)
            false
        }
    }

    /**
     * Disable or enable the camera system-wide
     * 
     * @param disable true to disable camera, false to enable
     */
    fun setCameraDisabled(disable: Boolean): Boolean {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.setCameraDisabled(adminComponentName, disable)
                Log.i(TAG, "Camera disabled: $disable")
                true
            } else {
                Log.w(TAG, "Cannot set camera state - admin not active")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting camera state", e)
            false
        }
    }


    /**
     * Get the number of failed password attempts since last successful unlock
     */
    fun getFailedPasswordAttempts(): Int {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.currentFailedPasswordAttempts
            } else {
                0
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting failed password attempts", e)
            0
        }
    }

    /**
     * Set maximum failed password attempts before device wipe
     * 
     * @param maxAttempts Maximum number of failed attempts (0 to disable)
     */
    fun setMaximumFailedPasswordsForWipe(maxAttempts: Int): Boolean {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.setMaximumFailedPasswordsForWipe(adminComponentName, maxAttempts)
                Log.i(TAG, "Maximum failed passwords for wipe set to: $maxAttempts")
                true
            } else {
                Log.w(TAG, "Cannot set max failed passwords - admin not active")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting max failed passwords", e)
            false
        }
    }

    /**
     * Set maximum time to lock after screen off
     * 
     * @param timeMs Time in milliseconds
     */
    fun setMaximumTimeToLock(timeMs: Long): Boolean {
        return try {
            if (isAdminActive()) {
                devicePolicyManager.setMaximumTimeToLock(adminComponentName, timeMs)
                Log.i(TAG, "Maximum time to lock set to: $timeMs ms")
                true
            } else {
                Log.w(TAG, "Cannot set max time to lock - admin not active")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting max time to lock", e)
            false
        }
    }

    // ==================== Deactivation Window Management ====================
    // Requirement 2.3: 30-second deactivation window after password entry

    /**
     * Allow deactivation for 30 seconds
     * Called after successful password verification
     * Requirement 2.3
     */
    fun allowDeactivation(): Boolean {
        return try {
            val prefs = context.getSharedPreferences(
                DeviceAdminReceiver.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            val allowedUntil = System.currentTimeMillis() + DeviceAdminReceiver.DEACTIVATION_WINDOW_MS
            prefs.edit().putLong(DeviceAdminReceiver.KEY_DEACTIVATION_ALLOWED_UNTIL, allowedUntil).apply()
            
            Log.i(TAG, "Deactivation allowed for 30 seconds until: $allowedUntil")
            notifyFlutter("DEACTIVATION_WINDOW_OPENED")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error allowing deactivation", e)
            false
        }
    }

    /**
     * Revoke deactivation permission
     * Called when deactivation window expires or is cancelled
     */
    fun revokeDeactivation(): Boolean {
        return try {
            val prefs = context.getSharedPreferences(
                DeviceAdminReceiver.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit().remove(DeviceAdminReceiver.KEY_DEACTIVATION_ALLOWED_UNTIL).apply()
            
            Log.i(TAG, "Deactivation permission revoked")
            notifyFlutter("DEACTIVATION_WINDOW_CLOSED")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error revoking deactivation", e)
            false
        }
    }

    /**
     * Check if deactivation is currently allowed
     */
    fun isDeactivationAllowed(): Boolean {
        val prefs = context.getSharedPreferences(
            DeviceAdminReceiver.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val allowedUntil = prefs.getLong(DeviceAdminReceiver.KEY_DEACTIVATION_ALLOWED_UNTIL, 0)
        return System.currentTimeMillis() < allowedUntil
    }

    /**
     * Get remaining time in deactivation window (milliseconds)
     */
    fun getDeactivationWindowRemaining(): Long {
        val prefs = context.getSharedPreferences(
            DeviceAdminReceiver.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val allowedUntil = prefs.getLong(DeviceAdminReceiver.KEY_DEACTIVATION_ALLOWED_UNTIL, 0)
        val remaining = allowedUntil - System.currentTimeMillis()
        return if (remaining > 0) remaining else 0
    }

    // ==================== Protected Mode Management ====================

    /**
     * Set protected mode state
     * This affects how deactivation requests are handled
     */
    fun setProtectedModeActive(active: Boolean): Boolean {
        return try {
            val prefs = context.getSharedPreferences(
                DeviceAdminReceiver.PREFS_NAME,
                Context.MODE_PRIVATE
            )
            prefs.edit().putBoolean(DeviceAdminReceiver.KEY_PROTECTED_MODE_ACTIVE, active).apply()
            
            Log.i(TAG, "Protected mode set to: $active")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting protected mode", e)
            false
        }
    }

    /**
     * Check if protected mode is active
     */
    fun isProtectedModeActive(): Boolean {
        val prefs = context.getSharedPreferences(
            DeviceAdminReceiver.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        return prefs.getBoolean(DeviceAdminReceiver.KEY_PROTECTED_MODE_ACTIVE, false)
    }


    // ==================== Utility Methods ====================

    /**
     * Get device admin status information
     */
    fun getAdminStatus(): Map<String, Any> {
        return mapOf(
            "isAdminActive" to isAdminActive(),
            "isProtectedModeActive" to isProtectedModeActive(),
            "isDeactivationAllowed" to isDeactivationAllowed(),
            "deactivationWindowRemaining" to getDeactivationWindowRemaining(),
            "failedPasswordAttempts" to getFailedPasswordAttempts()
        )
    }

    /**
     * Send notification to Flutter side via broadcast
     */
    private fun notifyFlutter(action: String, extras: Map<String, Any>? = null) {
        val intent = Intent("com.example.find_phone.DEVICE_ADMIN_EVENT")
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
     * Log security event
     */
    private fun logSecurityEvent(eventType: String, details: String) {
        val intent = Intent("com.example.find_phone.SECURITY_EVENT")
        intent.putExtra("event_type", eventType)
        intent.putExtra("details", details)
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }

    /**
     * Open device admin settings
     */
    fun openDeviceAdminSettings(): Intent {
        return Intent().apply {
            action = android.provider.Settings.ACTION_SECURITY_SETTINGS
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
    }

    /**
     * Request to remove device admin (for testing/development)
     * This will trigger onDisableRequested in DeviceAdminReceiver
     */
    fun requestRemoveAdmin(): Intent {
        return Intent().apply {
            action = DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponentName)
        }
    }
}
