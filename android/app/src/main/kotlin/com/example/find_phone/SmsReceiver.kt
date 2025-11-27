package com.example.find_phone

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage

/**
 * BroadcastReceiver for incoming SMS messages.
 * 
 * Intercepts SMS messages and forwards them to Flutter for processing.
 * Used for remote command handling (LOCK#, WIPE#, LOCATE#, ALARM#).
 * 
 * Requirements: 8.1 - Receive and process SMS commands
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
        const val SMS_EVENT_ACTION = "com.example.find_phone.SMS_RECEIVED"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val messages = extractMessages(intent)
            
            for ((sender, message) in messages) {
                // Forward to Flutter via broadcast
                val smsIntent = Intent(SMS_EVENT_ACTION).apply {
                    putExtra("sender", sender)
                    putExtra("message", message)
                    putExtra("timestamp", System.currentTimeMillis())
                    setPackage(context.packageName)
                }
                context.sendBroadcast(smsIntent)
                
                // Also notify the accessibility service if running
                notifyAccessibilityService(context, sender, message)
            }
        } catch (e: Exception) {
            // Log error but don't crash
            e.printStackTrace()
        }
    }

    /**
     * Extract SMS messages from the intent.
     * 
     * Returns a list of pairs (sender, message).
     */
    private fun extractMessages(intent: Intent): List<Pair<String, String>> {
        val messages = mutableListOf<Pair<String, String>>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val smsMessages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            // Group messages by sender (for multi-part SMS)
            val messagesBySender = mutableMapOf<String, StringBuilder>()
            
            for (smsMessage in smsMessages) {
                val sender = smsMessage.displayOriginatingAddress ?: continue
                val body = smsMessage.messageBody ?: continue
                
                messagesBySender.getOrPut(sender) { StringBuilder() }.append(body)
            }
            
            for ((sender, body) in messagesBySender) {
                messages.add(Pair(sender, body.toString()))
            }
        } else {
            // Legacy method for older Android versions
            @Suppress("DEPRECATION")
            val pdus = intent.extras?.get("pdus") as? Array<*>
            val format = intent.extras?.getString("format")
            
            if (pdus != null) {
                val messagesBySender = mutableMapOf<String, StringBuilder>()
                
                for (pdu in pdus) {
                    val smsMessage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        SmsMessage.createFromPdu(pdu as ByteArray, format)
                    } else {
                        @Suppress("DEPRECATION")
                        SmsMessage.createFromPdu(pdu as ByteArray)
                    }
                    
                    val sender = smsMessage.displayOriginatingAddress ?: continue
                    val body = smsMessage.messageBody ?: continue
                    
                    messagesBySender.getOrPut(sender) { StringBuilder() }.append(body)
                }
                
                for ((sender, body) in messagesBySender) {
                    messages.add(Pair(sender, body.toString()))
                }
            }
        }
        
        return messages
    }

    /**
     * Notify the accessibility service about incoming SMS.
     * 
     * This allows the service to handle commands even when the app is not in foreground.
     */
    private fun notifyAccessibilityService(context: Context, sender: String, message: String) {
        val serviceIntent = Intent("com.example.find_phone.ACCESSIBILITY_COMMAND").apply {
            putExtra("command", "SMS_RECEIVED")
            putExtra("sender", sender)
            putExtra("message", message)
            putExtra("timestamp", System.currentTimeMillis())
            setPackage(context.packageName)
        }
        context.sendBroadcast(serviceIntent)
    }
}
