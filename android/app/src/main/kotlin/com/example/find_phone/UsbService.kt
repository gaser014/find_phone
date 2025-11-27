package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.util.Log

/**
 * USB Service for detecting USB connections and managing trusted devices.
 *
 * Requirements:
 * - 28.1: Detect USB cable connection immediately
 * - 28.2: Check if connected computer is in trusted devices list
 * - 28.3: Block USB data transfer for untrusted computers
 * - 28.4: Add trusted computer with Master Password
 * - 28.5: Trigger alarm for USB debugging from untrusted computer
 * - 29.1: Store trusted device identifier in encrypted persistent storage
 * - 29.2: Restore trusted devices list after device power cycle
 */
class UsbService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "UsbService"
        
        @Volatile
        private var instance: UsbService? = null

        fun getInstance(context: Context): UsbService {
            return instance ?: synchronized(this) {
                instance ?: UsbService(context.applicationContext).also { instance = it }
            }
        }
    }

    private var usbReceiver: BroadcastReceiver? = null
    private var isMonitoring = false
    private var onUsbConnectionChanged: ((Boolean, String?, String?, String?) -> Unit)? = null
    private var onUsbModeChanged: ((String, String?) -> Unit)? = null

    /**
     * Check if USB cable is connected.
     */
    fun isUsbConnected(): Boolean {
        return try {
            val batteryIntent = context.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val plugged = batteryIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1
            plugged == BatteryManager.BATTERY_PLUGGED_USB
        } catch (e: Exception) {
            Log.e(TAG, "Error checking USB connection", e)
            false
        }
    }

    /**
     * Get current USB mode.
     */
    fun getCurrentUsbMode(): String {
        return try {
            // Check ADB status first
            if (isAdbEnabled()) {
                return "adb"
            }
            
            // Check USB configuration
            val usbConfig = Settings.Global.getString(
                context.contentResolver,
                "sys.usb.config"
            ) ?: Settings.Global.getString(
                context.contentResolver,
                "persist.sys.usb.config"
            )
            
            when {
                usbConfig?.contains("mtp") == true -> "mtp"
                usbConfig?.contains("ptp") == true -> "ptp"
                usbConfig?.contains("midi") == true -> "midi"
                usbConfig?.contains("adb") == true -> "adb"
                else -> "charging"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting USB mode", e)
            "unknown"
        }
    }

    /**
     * Get connected USB device ID (if available).
     */
    fun getConnectedDeviceId(): String? {
        return try {
            val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
            val deviceList = usbManager.deviceList
            
            if (deviceList.isNotEmpty()) {
                // Return the first connected device's ID
                val device = deviceList.values.first()
                generateDeviceFingerprint(device)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting connected device ID", e)
            null
        }
    }

    /**
     * Generate a unique fingerprint for a USB device.
     */
    private fun generateDeviceFingerprint(device: UsbDevice): String {
        return "${device.vendorId}:${device.productId}:${device.deviceName}"
    }


    /**
     * Start monitoring USB connections.
     */
    fun startUsbMonitoring(
        onConnectionChanged: ((Boolean, String?, String?, String?) -> Unit)? = null,
        onModeChanged: ((String, String?) -> Unit)? = null
    ) {
        if (isMonitoring) return

        this.onUsbConnectionChanged = onConnectionChanged
        this.onUsbModeChanged = onModeChanged

        usbReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        val deviceId = device?.let { generateDeviceFingerprint(it) }
                        val deviceName = device?.productName
                        val mode = getCurrentUsbMode()
                        onUsbConnectionChanged?.invoke(true, deviceId, deviceName, mode)
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        onUsbConnectionChanged?.invoke(false, null, null, null)
                    }
                    Intent.ACTION_POWER_CONNECTED -> {
                        if (isUsbConnected()) {
                            val deviceId = getConnectedDeviceId()
                            val mode = getCurrentUsbMode()
                            onUsbConnectionChanged?.invoke(true, deviceId, null, mode)
                        }
                    }
                    Intent.ACTION_POWER_DISCONNECTED -> {
                        onUsbConnectionChanged?.invoke(false, null, null, null)
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(usbReceiver, filter)
        }

        isMonitoring = true
        Log.d(TAG, "USB monitoring started")
    }

    /**
     * Stop monitoring USB connections.
     */
    fun stopUsbMonitoring() {
        if (!isMonitoring) return

        try {
            usbReceiver?.let { context.unregisterReceiver(it) }
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering USB receiver", e)
        }

        usbReceiver = null
        onUsbConnectionChanged = null
        onUsbModeChanged = null
        isMonitoring = false
        Log.d(TAG, "USB monitoring stopped")
    }

    /**
     * Block USB data transfer by setting USB mode to charging only.
     */
    fun blockUsbDataTransfer(): Boolean {
        return try {
            // This requires system-level permissions or root access
            // On non-rooted devices, we can only monitor and alert
            Log.d(TAG, "Attempting to block USB data transfer")
            
            // Try to set USB configuration to charging only
            // Note: This may not work on all devices without root
            Settings.Global.putString(
                context.contentResolver,
                "sys.usb.config",
                "charging"
            )
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot block USB data transfer - requires system permissions", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error blocking USB data transfer", e)
            false
        }
    }

    /**
     * Allow USB data transfer.
     */
    fun allowUsbDataTransfer(): Boolean {
        return try {
            Log.d(TAG, "Allowing USB data transfer")
            // Restore default USB configuration
            Settings.Global.putString(
                context.contentResolver,
                "sys.usb.config",
                "mtp,adb"
            )
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot allow USB data transfer - requires system permissions", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error allowing USB data transfer", e)
            false
        }
    }

    /**
     * Check if USB data transfer is blocked.
     */
    fun isUsbDataTransferBlocked(): Boolean {
        val mode = getCurrentUsbMode()
        return mode == "charging" || mode == "unknown"
    }

    /**
     * Check if ADB (USB debugging) is enabled.
     */
    fun isAdbEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.ADB_ENABLED,
                0
            ) == 1
        } catch (e: Exception) {
            Log.e(TAG, "Error checking ADB status", e)
            false
        }
    }

    /**
     * Block ADB connection (requires system permissions).
     */
    fun blockAdbConnection(): Boolean {
        return try {
            Settings.Global.putInt(
                context.contentResolver,
                Settings.Global.ADB_ENABLED,
                0
            )
            true
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot disable ADB - requires system permissions", e)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling ADB", e)
            false
        }
    }
}
