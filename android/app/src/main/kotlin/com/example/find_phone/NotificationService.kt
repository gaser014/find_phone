package com.example.find_phone

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Notification Service for Anti-Theft Protection
 * 
 * Provides notification functionality for:
 * - Security alert notifications (Requirement 7.3)
 * - Hidden service notifications (Requirement 18.2)
 * - SMS alert notifications
 * 
 * Requirements: 7.3, 18.2
 */
class NotificationService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "NotificationService"
        
        // Notification Channel IDs
        const val CHANNEL_SECURITY_ALERTS = "security_alerts"
        const val CHANNEL_BACKGROUND_SERVICE = "background_service"
        const val CHANNEL_SMS_ALERTS = "sms_alerts"
        
        // Notification IDs
        const val NOTIFICATION_ID_SERVICE = 1
        const val NOTIFICATION_ID_SECURITY_BASE = 100
        
        @Volatile
        private var instance: NotificationService? = null
        
        fun getInstance(context: Context): NotificationService {
            return instance ?: synchronized(this) {
                instance ?: NotificationService(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }

    private val notificationManager: NotificationManager by lazy {
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }
    
    private var notificationIdCounter = NOTIFICATION_ID_SECURITY_BASE

    init {
        createNotificationChannels()
    }

    /**
     * Create all notification channels
     */
    fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Security Alerts Channel - High priority
            val securityChannel = NotificationChannel(
                CHANNEL_SECURITY_ALERTS,
                "تنبيهات الأمان",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "تنبيهات الأنشطة المشبوهة والأحداث الأمنية"
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            // Background Service Channel - Low priority, hidden
            val serviceChannel = NotificationChannel(
                CHANNEL_BACKGROUND_SERVICE,
                "خدمة النظام",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "خدمة حماية الجهاز"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
                setSound(null, null)
                enableVibration(false)
            }
            
            // SMS Alerts Channel - Default priority
            val smsChannel = NotificationChannel(
                CHANNEL_SMS_ALERTS,
                "تنبيهات SMS",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "تنبيهات إرسال واستقبال الرسائل"
                setShowBadge(true)
            }
            
            notificationManager.createNotificationChannels(listOf(
                securityChannel,
                serviceChannel,
                smsChannel
            ))
        }
    }

    /**
     * Show a security alert notification
     * 
     * Requirement 7.3: Send notification with event details
     */
    fun showSecurityNotification(
        title: String,
        body: String,
        eventType: String? = null,
        eventId: String? = null,
        autoCancel: Boolean = true
    ): Int {
        val notificationId = getNextNotificationId()
        
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_type", "security_alert")
            putExtra("event_type", eventType)
            putExtra("event_id", eventId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_SECURITY_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setAutoCancel(autoCancel)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        notificationManager.notify(notificationId, notification)
        return notificationId
    }

    /**
     * Show hidden service notification
     * 
     * Requirement 18.2: Hide notification or show as system service
     */
    fun showHiddenServiceNotification(
        title: String = "System Service",
        body: String = "Running"
    ): Notification {
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(context, CHANNEL_BACKGROUND_SERVICE)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setSilent(true)
            .build()
    }

    /**
     * Update hidden service notification
     */
    fun updateHiddenServiceNotification(
        notificationId: Int,
        title: String? = null,
        body: String? = null
    ) {
        val notification = showHiddenServiceNotification(
            title ?: "System Service",
            body ?: "Running"
        )
        notificationManager.notify(notificationId, notification)
    }

    /**
     * Show SMS alert notification
     */
    fun showSmsAlertNotification(
        title: String,
        body: String,
        phoneNumber: String? = null
    ): Int {
        val notificationId = getNextNotificationId()
        
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_type", "sms_alert")
            putExtra("phone_number", phoneNumber)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(context, CHANNEL_SMS_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .build()
        
        notificationManager.notify(notificationId, notification)
        return notificationId
    }

    /**
     * Cancel a notification by ID
     */
    fun cancelNotification(notificationId: Int) {
        notificationManager.cancel(notificationId)
    }

    /**
     * Cancel all notifications
     */
    fun cancelAllNotifications() {
        notificationManager.cancelAll()
    }

    /**
     * Check if notifications are enabled
     */
    fun areNotificationsEnabled(): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    /**
     * Get next notification ID
     */
    private fun getNextNotificationId(): Int {
        return notificationIdCounter++
    }
}
