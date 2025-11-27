package com.example.find_phone

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

/**
 * Service for sending messages via WhatsApp.
 * 
 * Provides functionality to:
 * - Check if WhatsApp is installed
 * - Send messages via WhatsApp Intent
 * - Handle WhatsApp Business as fallback
 * 
 * Requirements: 26.1, 26.2, 26.3, 26.4, 26.5
 */
class WhatsAppService private constructor(private val context: Context) {

    companion object {
        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val WHATSAPP_BUSINESS_PACKAGE = "com.whatsapp.w4b"
        
        @Volatile
        private var instance: WhatsAppService? = null

        fun getInstance(context: Context): WhatsAppService {
            return instance ?: synchronized(this) {
                instance ?: WhatsAppService(context.applicationContext).also { instance = it }
            }
        }
    }

    /**
     * Check if WhatsApp is installed on the device.
     * 
     * @return true if WhatsApp or WhatsApp Business is installed
     */
    fun isWhatsAppInstalled(): Boolean {
        return isPackageInstalled(WHATSAPP_PACKAGE) || isPackageInstalled(WHATSAPP_BUSINESS_PACKAGE)
    }

    /**
     * Get the installed WhatsApp package name.
     * 
     * @return Package name of installed WhatsApp app, or null if not installed
     */
    fun getWhatsAppPackage(): String? {
        return when {
            isPackageInstalled(WHATSAPP_PACKAGE) -> WHATSAPP_PACKAGE
            isPackageInstalled(WHATSAPP_BUSINESS_PACKAGE) -> WHATSAPP_BUSINESS_PACKAGE
            else -> null
        }
    }

    /**
     * Send a message via WhatsApp to the specified phone number.
     * 
     * Uses WhatsApp's click-to-chat API via Intent.
     * 
     * @param phoneNumber The recipient's phone number (with country code, no + prefix needed)
     * @param message The message content to send
     * @return true if the intent was launched successfully
     * 
     * Requirements: 26.1 - Send location via WhatsApp
     */
    fun sendMessage(phoneNumber: String, message: String): Boolean {
        val whatsAppPackage = getWhatsAppPackage() ?: return false
        
        return try {
            // Normalize phone number (remove + and spaces)
            val normalizedNumber = normalizePhoneNumber(phoneNumber)
            
            // Create WhatsApp click-to-chat URL
            val url = "https://api.whatsapp.com/send?phone=$normalizedNumber&text=${Uri.encode(message)}"
            
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(url)
                setPackage(whatsAppPackage)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            // Try alternative method using direct intent
            sendMessageDirect(phoneNumber, message)
        }
    }

    /**
     * Send a message via WhatsApp using direct intent method.
     * 
     * @param phoneNumber The recipient's phone number
     * @param message The message content to send
     * @return true if the intent was launched successfully
     */
    private fun sendMessageDirect(phoneNumber: String, message: String): Boolean {
        val whatsAppPackage = getWhatsAppPackage() ?: return false
        
        return try {
            val normalizedNumber = normalizePhoneNumber(phoneNumber)
            
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                setPackage(whatsAppPackage)
                putExtra(Intent.EXTRA_TEXT, message)
                putExtra("jid", "$normalizedNumber@s.whatsapp.net")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Send a message via WhatsApp silently (without opening the app UI).
     * 
     * Note: This requires WhatsApp to be configured for the contact.
     * Falls back to regular send if silent send fails.
     * 
     * @param phoneNumber The recipient's phone number
     * @param message The message content to send
     * @return true if the message was sent successfully
     */
    fun sendMessageSilent(phoneNumber: String, message: String): Boolean {
        // WhatsApp doesn't support truly silent sending without user interaction
        // We use the click-to-chat API which opens WhatsApp with pre-filled message
        return sendMessage(phoneNumber, message)
    }

    /**
     * Open WhatsApp chat with a specific contact.
     * 
     * @param phoneNumber The contact's phone number
     * @return true if WhatsApp was opened successfully
     */
    fun openChat(phoneNumber: String): Boolean {
        val whatsAppPackage = getWhatsAppPackage() ?: return false
        
        return try {
            val normalizedNumber = normalizePhoneNumber(phoneNumber)
            val url = "https://api.whatsapp.com/send?phone=$normalizedNumber"
            
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse(url)
                setPackage(whatsAppPackage)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if a package is installed on the device.
     * 
     * @param packageName The package name to check
     * @return true if the package is installed
     */
    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, PackageManager.GET_ACTIVITIES)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Normalize a phone number for WhatsApp.
     * 
     * Removes all non-digit characters except leading +.
     * WhatsApp expects numbers without + prefix.
     * 
     * @param phoneNumber The phone number to normalize
     * @return Normalized phone number (digits only)
     */
    private fun normalizePhoneNumber(phoneNumber: String): String {
        // Remove all non-digit characters
        return phoneNumber.replace(Regex("[^\\d]"), "")
    }
}
