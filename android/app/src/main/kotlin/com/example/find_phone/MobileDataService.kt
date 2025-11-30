package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.Build
import android.telephony.TelephonyManager
import android.util.Log
import java.lang.reflect.Method

/**
 * Service for managing mobile data.
 * 
 * Provides functionality to:
 * - Enable/disable mobile data
 * - Check mobile data status
 * - Auto-enable data when Kiosk Mode activates
 * 
 * Note: Enabling mobile data programmatically requires
 * system-level permissions or Device Owner/Profile Owner status.
 */
class MobileDataService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "MobileDataService"
        
        @Volatile
        private var instance: MobileDataService? = null
        
        fun getInstance(context: Context): MobileDataService {
            return instance ?: synchronized(this) {
                instance ?: MobileDataService(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    private var commandReceiver: BroadcastReceiver? = null

    /**
     * Initialize the service and register receivers
     */
    fun initialize() {
        registerCommandReceiver()
    }

    /**
     * Dispose the service
     */
    fun dispose() {
        unregisterCommandReceiver()
    }

    /**
     * Register command receiver
     */
    private fun registerCommandReceiver() {
        if (commandReceiver != null) return
        
        commandReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.getStringExtra("command")) {
                    "ENABLE_MOBILE_DATA" -> enableMobileData()
                    "DISABLE_MOBILE_DATA" -> disableMobileData()
                    "CHECK_MOBILE_DATA" -> checkMobileDataStatus()
                }
            }
        }
        
        val filter = IntentFilter("com.example.find_phone.DATA_COMMAND")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(commandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(commandReceiver, filter)
        }
    }

    /**
     * Unregister command receiver
     */
    private fun unregisterCommandReceiver() {
        commandReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver: ${e.message}")
            }
            commandReceiver = null
        }
    }

    /**
     * Check if mobile data is enabled
     */
    fun isMobileDataEnabled(): Boolean {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = connectivityManager.activeNetwork
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) == true
            } else {
                @Suppress("DEPRECATION")
                val networkInfo = connectivityManager.activeNetworkInfo
                networkInfo?.type == ConnectivityManager.TYPE_MOBILE && networkInfo.isConnected
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking mobile data: ${e.message}")
            false
        }
    }

    /**
     * Enable mobile data
     * 
     * Note: This requires special permissions:
     * - MODIFY_PHONE_STATE (system apps only)
     * - Or Device Owner/Profile Owner status
     * 
     * For non-system apps, this will attempt to open settings
     */
    fun enableMobileData(): Boolean {
        Log.i(TAG, "Attempting to enable mobile data")
        
        // Method 1: Try using TelephonyManager (requires MODIFY_PHONE_STATE)
        if (tryEnableViaTelephonyManager(true)) {
            Log.i(TAG, "Mobile data enabled via TelephonyManager")
            notifyDataStateChanged(true)
            return true
        }
        
        // Method 2: Try using ConnectivityManager (deprecated but may work on some devices)
        if (tryEnableViaConnectivityManager(true)) {
            Log.i(TAG, "Mobile data enabled via ConnectivityManager")
            notifyDataStateChanged(true)
            return true
        }
        
        // Method 3: Try using Settings.Global (requires WRITE_SECURE_SETTINGS)
        if (tryEnableViaSettings(true)) {
            Log.i(TAG, "Mobile data enabled via Settings")
            notifyDataStateChanged(true)
            return true
        }
        
        // If all methods fail, notify user
        Log.w(TAG, "Could not enable mobile data programmatically")
        notifyDataEnableFailed()
        return false
    }

    /**
     * Disable mobile data
     */
    fun disableMobileData(): Boolean {
        Log.i(TAG, "Attempting to disable mobile data")
        
        if (tryEnableViaTelephonyManager(false)) {
            notifyDataStateChanged(false)
            return true
        }
        
        if (tryEnableViaConnectivityManager(false)) {
            notifyDataStateChanged(false)
            return true
        }
        
        if (tryEnableViaSettings(false)) {
            notifyDataStateChanged(false)
            return true
        }
        
        return false
    }

    /**
     * Try to enable/disable mobile data via TelephonyManager
     */
    private fun tryEnableViaTelephonyManager(enable: Boolean): Boolean {
        return try {
            val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            
            // Try setDataEnabled method (API 26+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val method: Method = telephonyManager.javaClass.getDeclaredMethod(
                    "setDataEnabled",
                    Boolean::class.javaPrimitiveType
                )
                method.invoke(telephonyManager, enable)
                true
            } else {
                // Try older method
                val method: Method = telephonyManager.javaClass.getDeclaredMethod(
                    "setDataEnabled",
                    Boolean::class.javaPrimitiveType
                )
                method.invoke(telephonyManager, enable)
                true
            }
        } catch (e: Exception) {
            Log.d(TAG, "TelephonyManager method failed: ${e.message}")
            false
        }
    }

    /**
     * Try to enable/disable mobile data via ConnectivityManager
     */
    private fun tryEnableViaConnectivityManager(enable: Boolean): Boolean {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            
            val method: Method = connectivityManager.javaClass.getDeclaredMethod(
                "setMobileDataEnabled",
                Boolean::class.javaPrimitiveType
            )
            method.invoke(connectivityManager, enable)
            true
        } catch (e: Exception) {
            Log.d(TAG, "ConnectivityManager method failed: ${e.message}")
            false
        }
    }

    /**
     * Try to enable/disable mobile data via Settings
     */
    private fun tryEnableViaSettings(enable: Boolean): Boolean {
        return try {
            android.provider.Settings.Global.putInt(
                context.contentResolver,
                "mobile_data",
                if (enable) 1 else 0
            )
            true
        } catch (e: Exception) {
            Log.d(TAG, "Settings method failed: ${e.message}")
            false
        }
    }

    /**
     * Check and report mobile data status
     */
    private fun checkMobileDataStatus() {
        val isEnabled = isMobileDataEnabled()
        notifyDataStateChanged(isEnabled)
    }

    /**
     * Notify about data state change
     */
    private fun notifyDataStateChanged(enabled: Boolean) {
        val intent = Intent("com.example.find_phone.DATA_EVENT")
        intent.putExtra("action", "DATA_STATE_CHANGED")
        intent.putExtra("enabled", enabled)
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }

    /**
     * Notify that data enable failed
     */
    private fun notifyDataEnableFailed() {
        val intent = Intent("com.example.find_phone.DATA_EVENT")
        intent.putExtra("action", "DATA_ENABLE_FAILED")
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.putExtra("message", "تعذر تفعيل بيانات الهاتف تلقائياً. يرجى تفعيلها يدوياً.")
        intent.setPackage(context.packageName)
        context.sendBroadcast(intent)
    }
}
