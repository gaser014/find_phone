package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbManager
import android.os.BatteryManager
import android.util.Log

/**
 * Receiver for USB connection events.
 * 
 * When USB is connected and Kiosk mode is active:
 * - Triggers alarm
 * - Captures photo
 * - Sends alert to emergency contacts
 */
class UsbConnectionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "UsbConnectionReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "USB event received: ${intent.action}")
        
        // Check if Kiosk on Lock is enabled
        val prefs = context.getSharedPreferences(ScreenLockReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val kioskOnLockEnabled = prefs.getBoolean(ScreenLockReceiver.KEY_KIOSK_ON_LOCK_ENABLED, false)
        val kioskPending = prefs.getBoolean("kiosk_pending", false)
        
        if (!kioskOnLockEnabled && !kioskPending) {
            return
        }

        when (intent.action) {
            Intent.ACTION_POWER_CONNECTED -> {
                // Check if it's USB (not wireless charging)
                if (isUsbConnected(context)) {
                    Log.w(TAG, "USB connected while Kiosk mode active!")
                    handleUsbConnected(context)
                }
            }
            UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                Log.w(TAG, "USB device attached while Kiosk mode active!")
                handleUsbConnected(context)
            }
            UsbManager.ACTION_USB_ACCESSORY_ATTACHED -> {
                Log.w(TAG, "USB accessory attached while Kiosk mode active!")
                handleUsbConnected(context)
            }
        }
    }

    private fun isUsbConnected(context: Context): Boolean {
        return try {
            val batteryIntent = context.registerReceiver(
                null,
                android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1
            plugged == BatteryManager.BATTERY_PLUGGED_USB
        } catch (e: Exception) {
            false
        }
    }

    private fun handleUsbConnected(context: Context) {
        // Trigger alarm
        triggerAlarm(context)
        
        // Capture photo
        capturePhoto(context)
        
        // Send alert
        sendAlert(context)
        
        // Log security event
        logSecurityEvent(context, "usb_connected_blocked", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "severity" to "high"
        ))
        
        // Show Kiosk Lock Screen
        showKioskLockScreen(context)
    }

    private fun triggerAlarm(context: Context) {
        val intent = Intent("com.example.find_phone.TRIGGER_ALARM")
        intent.putExtra("type", "usb_connected")
        intent.putExtra("duration", 60000L)
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }

    private fun capturePhoto(context: Context) {
        val intent = Intent("com.example.find_phone.CAPTURE_PHOTO")
        intent.putExtra("reason", "usb_connected")
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }

    private fun sendAlert(context: Context) {
        val intent = Intent("com.example.find_phone.SEND_EMERGENCY_ALERT")
        intent.putExtra("reason", "usb_connected")
        intent.putExtra("message", "⚠️ تنبيه! تم توصيل USB بالجهاز أثناء وضع الحماية!")
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }

    private fun showKioskLockScreen(context: Context) {
        val intent = Intent(context, KioskLockActivity::class.java)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        )
        context.startActivity(intent)
    }

    private fun logSecurityEvent(context: Context, eventType: String, metadata: Map<String, Any>) {
        val intent = Intent("com.example.find_phone.SECURITY_EVENT")
        intent.putExtra("event_type", eventType)
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
