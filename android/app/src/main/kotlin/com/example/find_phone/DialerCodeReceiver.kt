package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Broadcast Receiver for detecting dialer code entry
 * 
 * This receiver listens for outgoing calls and checks if the dialed number
 * matches the secret dialer code for accessing the app in stealth mode.
 * 
 * Requirement 18.4: Only accessible via dialer code when stealth mode enabled
 * Requirement 18.5: Open and request Master Password when dialer code entered
 */
class DialerCodeReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "DialerCodeReceiver"
        
        // Shared preferences
        const val PREFS_NAME = "protection_prefs"
        const val KEY_DIALER_CODE = "dialer_code"
        const val KEY_STEALTH_MODE_ACTIVE = "stealth_mode_active"
        
        // Default dialer code
        const val DEFAULT_DIALER_CODE = "*#123456#"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        // Check if this is an outgoing call intent
        if (intent.action != Intent.ACTION_NEW_OUTGOING_CALL) return
        
        val dialedNumber = resultData ?: intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER) ?: return
        
        Log.d(TAG, "Outgoing call detected: $dialedNumber")
        
        // Get the configured dialer code
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val dialerCode = prefs.getString(KEY_DIALER_CODE, DEFAULT_DIALER_CODE) ?: DEFAULT_DIALER_CODE
        
        // Check if the dialed number matches the dialer code
        if (dialedNumber == dialerCode || dialedNumber.replace(" ", "") == dialerCode) {
            Log.i(TAG, "Dialer code detected - opening app")
            
            // Cancel the outgoing call
            resultData = null
            
            // Open the app
            openApp(context)
            
            // Notify Flutter
            notifyDialerCodeEntered(context)
        }
    }

    /**
     * Open the main app activity
     * Requirement 18.5: Open and request Master Password
     */
    private fun openApp(context: Context) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("from_dialer_code", true)
            }
            context.startActivity(intent)
            
            Log.i(TAG, "App opened from dialer code")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app: ${e.message}")
        }
    }

    /**
     * Notify Flutter that dialer code was entered
     */
    private fun notifyDialerCodeEntered(context: Context) {
        val intent = Intent("com.example.find_phone.DIALER_CODE_ENTERED")
        intent.putExtra("action", "DIALER_CODE_ENTERED")
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
        
        Log.i(TAG, "Dialer code entry notification sent")
    }
}
