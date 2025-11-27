package com.example.find_phone

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Main Activity with Flutter Method Channels for Accessibility Service
 * 
 * Provides Flutter-Android communication for:
 * - Accessibility Service status and control
 * - Protected mode management
 * - App blocking configuration
 * 
 * Requirements: 1.3, 3.1
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val ACCESSIBILITY_CHANNEL = "com.example.find_phone/accessibility"
        private const val ACCESSIBILITY_EVENTS_CHANNEL = "com.example.find_phone/accessibility_events"
        private const val BOOT_CHANNEL = "com.example.find_phone/boot"
        private const val BOOT_EVENTS_CHANNEL = "com.example.find_phone/boot_events"
        private const val DEVICE_ADMIN_CHANNEL = "com.example.find_phone/device_admin"
        private const val DEVICE_ADMIN_EVENTS_CHANNEL = "com.example.find_phone/device_admin_events"
        private const val PROTECTION_CHANNEL = "com.example.find_phone/protection"
        private const val PROTECTION_EVENTS_CHANNEL = "com.example.find_phone/protection_events"
        private const val ALARM_CHANNEL = "com.example.find_phone/alarm"
        private const val KIOSK_CHANNEL = "com.example.find_phone/kiosk"
        private const val NOTIFICATION_CHANNEL = "com.example.find_phone/notifications"
        private const val USB_CHANNEL = "com.example.find_phone/usb"
        private const val WHATSAPP_CHANNEL = "com.example.find_phone/whatsapp"
        private const val REQUEST_CODE_ENABLE_ADMIN = 1001
    }

    private var eventSink: EventChannel.EventSink? = null
    private var bootEventSink: EventChannel.EventSink? = null
    private var deviceAdminEventSink: EventChannel.EventSink? = null
    private var protectionEventSink: EventChannel.EventSink? = null
    private var accessibilityEventReceiver: BroadcastReceiver? = null
    private var bootEventReceiver: BroadcastReceiver? = null
    private var deviceAdminEventReceiver: BroadcastReceiver? = null
    private var protectionEventReceiver: BroadcastReceiver? = null
    
    // Kiosk Mode state
    private var isKioskModeActive = false
    
    private val deviceAdminService: DeviceAdminService by lazy {
        DeviceAdminService.getInstance(this)
    }
    
    private val alarmService: AlarmService by lazy {
        AlarmService.getInstance(this)
    }
    
    private val notificationService: NotificationService by lazy {
        NotificationService.getInstance(this)
    }
    
    private val usbService: UsbService by lazy {
        UsbService.getInstance(this)
    }
    
    private val whatsAppService: WhatsAppService by lazy {
        WhatsAppService.getInstance(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup Method Channel for Accessibility Service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityServiceEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(true)
                    }
                    "isProtectedModeActive" -> {
                        result.success(getAccessibilityService()?.getProtectedModeActive() ?: false)
                    }
                    "enableProtectedMode" -> {
                        getAccessibilityService()?.enableProtectedMode()
                        result.success(true)
                    }
                    "disableProtectedMode" -> {
                        getAccessibilityService()?.disableProtectedMode()
                        result.success(true)
                    }
                    "setBlockingOptions" -> {
                        val blockSettings = call.argument<Boolean>("blockSettings") ?: true
                        val blockFileManagers = call.argument<Boolean>("blockFileManagers") ?: true
                        val blockPowerMenu = call.argument<Boolean>("blockPowerMenu") ?: true
                        val blockQuickSettings = call.argument<Boolean>("blockQuickSettings") ?: true
                        
                        getAccessibilityService()?.setBlockingOptions(
                            blockSettings,
                            blockFileManagers,
                            blockPowerMenu,
                            blockQuickSettings
                        )
                        result.success(true)
                    }
                    "getBlockingStatus" -> {
                        val status = getAccessibilityService()?.getBlockingStatus()
                        result.success(status ?: mapOf(
                            "protected_mode" to false,
                            "block_settings" to true,
                            "block_file_managers" to true,
                            "block_power_menu" to true,
                            "block_quick_settings" to true
                        ))
                    }
                    "showPasswordOverlay" -> {
                        val actionStr = call.argument<String>("action") ?: "DISABLE_PROTECTED_MODE"
                        val action = try {
                            AntiTheftAccessibilityService.PendingAction.valueOf(actionStr)
                        } catch (e: Exception) {
                            AntiTheftAccessibilityService.PendingAction.DISABLE_PROTECTED_MODE
                        }
                        getAccessibilityService()?.showPasswordOverlayForAction(action)
                        result.success(true)
                    }
                    "hidePasswordOverlay" -> {
                        getAccessibilityService()?.hidePasswordOverlay()
                        result.success(true)
                    }
                    "updatePassword" -> {
                        val hash = call.argument<String>("hash")
                        val salt = call.argument<String>("salt")
                        if (hash != null && salt != null) {
                            getAccessibilityService()?.updatePassword(hash, salt)
                            
                            // Also update via broadcast for when service is running
                            val intent = Intent("com.example.find_phone.ACCESSIBILITY_COMMAND")
                            intent.putExtra("command", "UPDATE_PASSWORD")
                            intent.putExtra("hash", hash)
                            intent.putExtra("salt", salt)
                            intent.setPackage(packageName)
                            sendBroadcast(intent)
                            
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Hash and salt are required", null)
                        }
                    }
                    "isPackageBlocked" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            result.success(getAccessibilityService()?.isPackageBlocked(packageName) ?: false)
                        } else {
                            result.error("INVALID_ARGS", "Package name is required", null)
                        }
                    }
                    "sendCommand" -> {
                        val command = call.argument<String>("command")
                        if (command != null) {
                            sendAccessibilityCommand(command, call.arguments as? Map<String, Any>)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Command is required", null)
                        }
                    }
                    "showLockScreenMessage" -> {
                        val message = call.argument<String>("message")
                        val ownerContact = call.argument<String>("ownerContact")
                        val instructions = call.argument<String>("instructions")
                        getAccessibilityService()?.showLockScreenMessage(message, ownerContact, instructions)
                        result.success(true)
                    }
                    "hideLockScreenMessage" -> {
                        getAccessibilityService()?.hideLockScreenMessage()
                        result.success(true)
                    }
                    "isLockScreenMessageShowing" -> {
                        result.success(getAccessibilityService()?.isLockScreenMessageShowing() ?: false)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Event Channel for Accessibility Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerAccessibilityEventReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterAccessibilityEventReceiver()
                }
            })

        // Setup Method Channel for Boot Service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BOOT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "wasStartedAfterBoot" -> {
                        result.success(wasStartedAfterBoot())
                    }
                    "shouldRestoreProtectedMode" -> {
                        result.success(shouldRestoreProtectedMode())
                    }
                    "restoreProtectedModeState" -> {
                        restoreProtectedModeState()
                        result.success(true)
                    }
                    "isInSafeMode" -> {
                        result.success(isInSafeMode())
                    }
                    "handleSafeModeBoot" -> {
                        handleSafeModeBoot()
                        result.success(true)
                    }
                    "scheduleAutoRestartJob" -> {
                        AutoRestartJobService.scheduleJob(this)
                        result.success(true)
                    }
                    "cancelAutoRestartJob" -> {
                        AutoRestartJobService.cancelAllJobs(this)
                        result.success(true)
                    }
                    "isAutoRestartJobScheduled" -> {
                        result.success(AutoRestartJobService.isJobScheduled(this))
                    }
                    "handleForceStopDetected" -> {
                        handleForceStopDetected()
                        result.success(true)
                    }
                    "getLastBootTime" -> {
                        result.success(getLastBootTime())
                    }
                    "getBootCount" -> {
                        result.success(getBootCount())
                    }
                    "getRestartCount" -> {
                        result.success(getRestartCount())
                    }
                    "getLastRestartTime" -> {
                        result.success(getLastRestartTime())
                    }
                    "startProtectionService" -> {
                        startProtectionService()
                        result.success(true)
                    }
                    "stopProtectionService" -> {
                        stopProtectionService()
                        result.success(true)
                    }
                    "isProtectionServiceRunning" -> {
                        result.success(ProtectionForegroundService.isServiceRunning())
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Event Channel for Boot Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BOOT_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bootEventSink = events
                    registerBootEventReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    bootEventSink = null
                    unregisterBootEventReceiver()
                }
            })

        // Setup Method Channel for Device Admin Service
        // Requirements: 1.3, 2.1, 2.2, 2.3, 8.1, 8.3
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_ADMIN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAdminActive" -> {
                        result.success(deviceAdminService.isAdminActive())
                    }
                    "requestAdminActivation" -> {
                        val intent = deviceAdminService.requestAdminActivation()
                        startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN)
                        result.success(true)
                    }
                    "lockDevice" -> {
                        result.success(deviceAdminService.lockDevice())
                    }
                    "lockDeviceWithMessage" -> {
                        val message = call.argument<String>("message") ?: ""
                        result.success(deviceAdminService.lockDeviceWithMessage(message))
                    }
                    "wipeDevice" -> {
                        val reason = call.argument<String>("reason") ?: "Remote wipe command"
                        result.success(deviceAdminService.wipeDevice(reason))
                    }
                    "setPasswordQuality" -> {
                        val quality = call.argument<Int>("quality") ?: 0
                        result.success(deviceAdminService.setPasswordQuality(quality))
                    }
                    "setMinimumPasswordLength" -> {
                        val length = call.argument<Int>("length") ?: 0
                        result.success(deviceAdminService.setMinimumPasswordLength(length))
                    }
                    "setCameraDisabled" -> {
                        val disable = call.argument<Boolean>("disable") ?: false
                        result.success(deviceAdminService.setCameraDisabled(disable))
                    }
                    "getFailedPasswordAttempts" -> {
                        result.success(deviceAdminService.getFailedPasswordAttempts())
                    }
                    "setMaximumFailedPasswordsForWipe" -> {
                        val maxAttempts = call.argument<Int>("maxAttempts") ?: 0
                        result.success(deviceAdminService.setMaximumFailedPasswordsForWipe(maxAttempts))
                    }
                    "setMaximumTimeToLock" -> {
                        val timeMs = call.argument<Long>("timeMs") ?: 0L
                        result.success(deviceAdminService.setMaximumTimeToLock(timeMs))
                    }
                    "allowDeactivation" -> {
                        result.success(deviceAdminService.allowDeactivation())
                    }
                    "revokeDeactivation" -> {
                        result.success(deviceAdminService.revokeDeactivation())
                    }
                    "isDeactivationAllowed" -> {
                        result.success(deviceAdminService.isDeactivationAllowed())
                    }
                    "getDeactivationWindowRemaining" -> {
                        result.success(deviceAdminService.getDeactivationWindowRemaining())
                    }
                    "setProtectedModeActive" -> {
                        val active = call.argument<Boolean>("active") ?: false
                        result.success(deviceAdminService.setProtectedModeActive(active))
                    }
                    "isProtectedModeActive" -> {
                        result.success(deviceAdminService.isProtectedModeActive())
                    }
                    "getAdminStatus" -> {
                        result.success(deviceAdminService.getAdminStatus())
                    }
                    "openDeviceAdminSettings" -> {
                        val intent = deviceAdminService.openDeviceAdminSettings()
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Event Channel for Device Admin Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_ADMIN_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deviceAdminEventSink = events
                    registerDeviceAdminEventReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    deviceAdminEventSink = null
                    unregisterDeviceAdminEventReceiver()
                }
            })

        // Setup Method Channel for Alarm Service
        // Requirements: 7.1, 7.2, 7.4, 7.5, 8.5
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "triggerAlarm" -> {
                        val duration = call.argument<Number>("duration")?.toLong() ?: 120000L
                        val maxVolume = call.argument<Boolean>("maxVolume") ?: true
                        val ignoreVolumeSettings = call.argument<Boolean>("ignoreVolumeSettings") ?: true
                        result.success(alarmService.triggerAlarm(duration, maxVolume, ignoreVolumeSettings))
                    }
                    "stopAlarm" -> {
                        result.success(alarmService.stopAlarm())
                    }
                    "isAlarmPlaying" -> {
                        result.success(alarmService.isAlarmPlaying())
                    }
                    "hasAudioPermission" -> {
                        result.success(alarmService.hasAudioPermission())
                    }
                    "setAlarmSound" -> {
                        val soundPath = call.argument<String>("soundPath") ?: ""
                        alarmService.setAlarmSound(soundPath)
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Method Channel for Notifications
        // Requirements: 7.3, 18.2
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createNotificationChannels" -> {
                        notificationService.createNotificationChannels()
                        result.success(true)
                    }
                    "showNotification" -> {
                        val id = call.argument<Int>("id")
                        val channelId = call.argument<String>("channelId") ?: NotificationService.CHANNEL_SECURITY_ALERTS
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val eventType = call.argument<String>("eventType")
                        val eventId = call.argument<String>("eventId")
                        val autoCancel = call.argument<Boolean>("autoCancel") ?: true
                        val ongoing = call.argument<Boolean>("ongoing") ?: false
                        val silent = call.argument<Boolean>("silent") ?: false
                        
                        if (ongoing && silent) {
                            // Hidden service notification
                            val notification = notificationService.showHiddenServiceNotification(title, body)
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                            notificationManager.notify(id ?: NotificationService.NOTIFICATION_ID_SERVICE, notification)
                            result.success(id ?: NotificationService.NOTIFICATION_ID_SERVICE)
                        } else {
                            // Security alert notification
                            val notificationId = notificationService.showSecurityNotification(
                                title = title,
                                body = body,
                                eventType = eventType,
                                eventId = eventId,
                                autoCancel = autoCancel
                            )
                            result.success(notificationId)
                        }
                    }
                    "cancelNotification" -> {
                        val id = call.argument<Int>("id")
                        if (id != null) {
                            notificationService.cancelNotification(id)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Notification ID is required", null)
                        }
                    }
                    "cancelAllNotifications" -> {
                        notificationService.cancelAllNotifications()
                        result.success(true)
                    }
                    "areNotificationsEnabled" -> {
                        result.success(notificationService.areNotificationsEnabled())
                    }
                    "requestNotificationPermission" -> {
                        // On Android 13+, we need to request POST_NOTIFICATIONS permission
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            // Permission request is handled by Flutter permission_handler
                            result.success(notificationService.areNotificationsEnabled())
                        } else {
                            result.success(true)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Method Channel for Kiosk Mode
        // Requirements: 3.1, 3.2, 3.4, 3.5
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KIOSK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableKioskMode" -> {
                        result.success(enableKioskMode())
                    }
                    "disableKioskMode" -> {
                        result.success(disableKioskMode())
                    }
                    "isKioskModeActive" -> {
                        result.success(isKioskModeActive)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Method Channel for USB Service
        // Requirements: 28.1, 28.2, 28.3, 28.4, 28.5, 29.1, 29.2
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USB_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isUsbConnected" -> {
                        result.success(usbService.isUsbConnected())
                    }
                    "getCurrentUsbMode" -> {
                        result.success(usbService.getCurrentUsbMode())
                    }
                    "getConnectedDeviceId" -> {
                        result.success(usbService.getConnectedDeviceId())
                    }
                    "startUsbMonitoring" -> {
                        usbService.startUsbMonitoring(
                            onConnectionChanged = { isConnected, deviceId, deviceName, mode ->
                                val eventData = mapOf(
                                    "isConnected" to isConnected,
                                    "deviceId" to deviceId,
                                    "deviceName" to deviceName,
                                    "mode" to mode
                                )
                                // Send event via broadcast
                                val intent = Intent("com.example.find_phone.USB_EVENT")
                                intent.putExtra("action", "USB_CONNECTION_CHANGED")
                                intent.putExtra("isConnected", isConnected)
                                intent.putExtra("deviceId", deviceId)
                                intent.putExtra("deviceName", deviceName)
                                intent.putExtra("mode", mode)
                                intent.setPackage(packageName)
                                sendBroadcast(intent)
                            },
                            onModeChanged = { mode, deviceId ->
                                val intent = Intent("com.example.find_phone.USB_EVENT")
                                intent.putExtra("action", "USB_MODE_CHANGED")
                                intent.putExtra("mode", mode)
                                intent.putExtra("deviceId", deviceId)
                                intent.setPackage(packageName)
                                sendBroadcast(intent)
                            }
                        )
                        result.success(true)
                    }
                    "stopUsbMonitoring" -> {
                        usbService.stopUsbMonitoring()
                        result.success(true)
                    }
                    "blockUsbDataTransfer" -> {
                        result.success(usbService.blockUsbDataTransfer())
                    }
                    "allowUsbDataTransfer" -> {
                        result.success(usbService.allowUsbDataTransfer())
                    }
                    "isUsbDataTransferBlocked" -> {
                        result.success(usbService.isUsbDataTransferBlocked())
                    }
                    "isAdbEnabled" -> {
                        result.success(usbService.isAdbEnabled())
                    }
                    "blockAdbConnection" -> {
                        result.success(usbService.blockAdbConnection())
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Method Channel for WhatsApp Service
        // Requirements: 26.1, 26.2, 26.3, 26.4, 26.5
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHATSAPP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isWhatsAppInstalled" -> {
                        result.success(whatsAppService.isWhatsAppInstalled())
                    }
                    "sendWhatsAppMessage" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")
                        if (phoneNumber != null && message != null) {
                            result.success(whatsAppService.sendMessage(phoneNumber, message))
                        } else {
                            result.error("INVALID_ARGS", "Phone number and message are required", null)
                        }
                    }
                    "getWhatsAppPackage" -> {
                        result.success(whatsAppService.getWhatsAppPackage())
                    }
                    "openWhatsAppChat" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber != null) {
                            result.success(whatsAppService.openChat(phoneNumber))
                        } else {
                            result.error("INVALID_ARGS", "Phone number is required", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Method Channel for Protection Service
        // Requirements: 1.3, 1.4, 3.1, 3.2, 18.1, 18.3, 18.4, 21.1, 21.2
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROTECTION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableKioskMode" -> {
                        result.success(enableKioskMode())
                    }
                    "disableKioskMode" -> {
                        result.success(disableKioskMode())
                    }
                    "isKioskModeActive" -> {
                        result.success(isKioskModeActive)
                    }
                    "showKioskLockScreen" -> {
                        val message = call.argument<String>("message")
                        showKioskLockScreen(message)
                        result.success(true)
                    }
                    "excludeFromRecentApps" -> {
                        val exclude = call.argument<Boolean>("exclude") ?: true
                        excludeFromRecentApps(exclude)
                        result.success(true)
                    }
                    "setAppIconVisibility" -> {
                        val hide = call.argument<Boolean>("hide") ?: false
                        setAppIconVisibility(hide)
                        result.success(true)
                    }
                    "registerVolumeButtonListener" -> {
                        registerVolumeButtonListener()
                        result.success(true)
                    }
                    "unregisterVolumeButtonListener" -> {
                        unregisterVolumeButtonListener()
                        result.success(true)
                    }
                    "registerDialerCodeListener" -> {
                        val code = call.argument<String>("code") ?: "*#123456#"
                        registerDialerCodeListener(code)
                        result.success(true)
                    }
                    "unregisterDialerCodeListener" -> {
                        unregisterDialerCodeListener()
                        result.success(true)
                    }
                    "openApp" -> {
                        openApp()
                        result.success(true)
                    }
                    "triggerPanicAlarm" -> {
                        triggerPanicAlarm()
                        result.success(true)
                    }
                    "stopPanicAlarm" -> {
                        stopPanicAlarm()
                        result.success(true)
                    }
                    "capturePanicPhoto" -> {
                        capturePanicPhoto()
                        result.success(true)
                    }
                    "sendPanicSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        if (phoneNumber != null) {
                            sendPanicSms(phoneNumber)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Phone number is required", null)
                        }
                    }
                    "enableHighFrequencyTracking" -> {
                        enableHighFrequencyTracking()
                        result.success(true)
                    }
                    "disableHighFrequencyTracking" -> {
                        disableHighFrequencyTracking()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Setup Event Channel for Protection Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROTECTION_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    protectionEventSink = events
                    registerProtectionEventReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    protectionEventSink = null
                    unregisterProtectionEventReceiver()
                }
            })
    }


    /**
     * Check if our Accessibility Service is enabled
     */
    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = accessibilityManager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_GENERIC
        )
        
        val serviceName = "$packageName/.AntiTheftAccessibilityService"
        
        for (service in enabledServices) {
            if (service.id.contains(packageName) || 
                service.resolveInfo.serviceInfo.name.contains("AntiTheftAccessibilityService")) {
                return true
            }
        }
        
        return false
    }

    /**
     * Open Accessibility Settings
     */
    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    /**
     * Get the Accessibility Service instance
     */
    private fun getAccessibilityService(): AntiTheftAccessibilityService? {
        return AntiTheftAccessibilityService.getInstance()
    }

    /**
     * Send command to Accessibility Service via broadcast
     */
    private fun sendAccessibilityCommand(command: String, extras: Map<String, Any>?) {
        val intent = Intent("com.example.find_phone.ACCESSIBILITY_COMMAND")
        intent.putExtra("command", command)
        extras?.forEach { (key, value) ->
            when (value) {
                is String -> intent.putExtra(key, value)
                is Int -> intent.putExtra(key, value)
                is Long -> intent.putExtra(key, value)
                is Boolean -> intent.putExtra(key, value)
                is Double -> intent.putExtra(key, value)
            }
        }
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Register broadcast receiver for Accessibility events
     */
    private fun registerAccessibilityEventReceiver() {
        if (accessibilityEventReceiver != null) return
        
        accessibilityEventReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let { handleAccessibilityEvent(it) }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.ACCESSIBILITY_EVENT")
            addAction("com.example.find_phone.SECURITY_EVENT")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(accessibilityEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(accessibilityEventReceiver, filter)
        }
    }

    /**
     * Unregister broadcast receiver
     */
    private fun unregisterAccessibilityEventReceiver() {
        accessibilityEventReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver not registered
            }
            accessibilityEventReceiver = null
        }
    }

    /**
     * Handle Accessibility events and forward to Flutter
     */
    private fun handleAccessibilityEvent(intent: Intent) {
        val eventData = mutableMapOf<String, Any?>()
        
        eventData["action"] = intent.getStringExtra("action")
        eventData["timestamp"] = intent.getLongExtra("timestamp", System.currentTimeMillis())
        
        // Add all extras
        intent.extras?.let { extras ->
            for (key in extras.keySet()) {
                if (key != "action" && key != "timestamp") {
                    eventData[key] = extras.get(key)
                }
            }
        }
        
        // Send to Flutter via EventChannel
        eventSink?.success(eventData)
    }

    // ==================== Boot Service Methods ====================

    /**
     * Check if app was started after boot
     */
    private fun wasStartedAfterBoot(): Boolean {
        val prefs = getSharedPreferences(BootCompletedReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        val lastBootTime = prefs.getLong(BootCompletedReceiver.KEY_LAST_BOOT_TIME, 0)
        val currentTime = System.currentTimeMillis()
        
        // Consider it a boot start if within 5 minutes of last boot
        return lastBootTime > 0 && (currentTime - lastBootTime) < 5 * 60 * 1000
    }

    /**
     * Check if Protected Mode should be restored
     */
    private fun shouldRestoreProtectedMode(): Boolean {
        val accessibilityPrefs = getSharedPreferences(
            AntiTheftAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        return accessibilityPrefs.getBoolean(
            AntiTheftAccessibilityService.KEY_PROTECTED_MODE_ACTIVE,
            false
        )
    }

    /**
     * Restore Protected Mode state
     */
    private fun restoreProtectedModeState() {
        if (shouldRestoreProtectedMode()) {
            startProtectionService()
            getAccessibilityService()?.enableProtectedMode()
        }
    }

    /**
     * Check if device is in Safe Mode
     */
    private fun isInSafeMode(): Boolean {
        return try {
            val systemProperties = Class.forName("android.os.SystemProperties")
            val getMethod = systemProperties.getMethod("get", String::class.java, String::class.java)
            val safeMode = getMethod.invoke(null, "ro.sys.safemode", "0") as String
            safeMode == "1"
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Handle Safe Mode boot
     */
    private fun handleSafeModeBoot() {
        // Log security event
        val intent = Intent("com.example.find_phone.SECURITY_EVENT")
        intent.putExtra("event_type", "safe_mode_detected")
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.putExtra("severity", "critical")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Handle force-stop detection
     */
    private fun handleForceStopDetected() {
        // Log security event
        val intent = Intent("com.example.find_phone.SECURITY_EVENT")
        intent.putExtra("event_type", "app_force_stopped")
        intent.putExtra("timestamp", System.currentTimeMillis())
        intent.putExtra("severity", "high")
        intent.setPackage(packageName)
        sendBroadcast(intent)
        
        // Schedule restart
        AutoRestartJobService.scheduleImmediateRestart(this)
    }

    /**
     * Get last boot time
     */
    private fun getLastBootTime(): Long {
        val prefs = getSharedPreferences(BootCompletedReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(BootCompletedReceiver.KEY_LAST_BOOT_TIME, 0)
    }

    /**
     * Get boot count
     */
    private fun getBootCount(): Int {
        val prefs = getSharedPreferences(BootCompletedReceiver.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(BootCompletedReceiver.KEY_BOOT_COUNT, 0)
    }

    /**
     * Get restart count
     */
    private fun getRestartCount(): Int {
        val prefs = getSharedPreferences(AutoRestartJobService.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getInt(AutoRestartJobService.KEY_RESTART_COUNT, 0)
    }

    /**
     * Get last restart time
     */
    private fun getLastRestartTime(): Long {
        val prefs = getSharedPreferences(AutoRestartJobService.PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(AutoRestartJobService.KEY_LAST_RESTART_TIME, 0)
    }

    /**
     * Start protection foreground service
     */
    private fun startProtectionService() {
        val serviceIntent = Intent(this, ProtectionForegroundService::class.java)
        serviceIntent.action = ProtectionForegroundService.ACTION_START_PROTECTION
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    /**
     * Stop protection foreground service
     */
    private fun stopProtectionService() {
        val serviceIntent = Intent(this, ProtectionForegroundService::class.java)
        serviceIntent.action = ProtectionForegroundService.ACTION_STOP_PROTECTION
        startService(serviceIntent)
    }

    /**
     * Register broadcast receiver for Boot events
     */
    private fun registerBootEventReceiver() {
        if (bootEventReceiver != null) return
        
        bootEventReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let { handleBootEvent(it) }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.BOOT_EVENT")
            addAction("com.example.find_phone.AUTO_RESTART_EVENT")
            addAction("com.example.find_phone.PROTECTION_SERVICE_EVENT")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(bootEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(bootEventReceiver, filter)
        }
    }

    /**
     * Unregister boot event receiver
     */
    private fun unregisterBootEventReceiver() {
        bootEventReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver not registered
            }
            bootEventReceiver = null
        }
    }

    /**
     * Handle Boot events and forward to Flutter
     */
    private fun handleBootEvent(intent: Intent) {
        val eventData = mutableMapOf<String, Any?>()
        
        eventData["action"] = intent.getStringExtra("action")
        eventData["timestamp"] = intent.getLongExtra("timestamp", System.currentTimeMillis())
        
        // Add all extras
        intent.extras?.let { extras ->
            for (key in extras.keySet()) {
                if (key != "action" && key != "timestamp") {
                    eventData[key] = extras.get(key)
                }
            }
        }
        
        // Send to Flutter via EventChannel
        bootEventSink?.success(eventData)
    }

    // ==================== Device Admin Event Receiver ====================

    /**
     * Register broadcast receiver for Device Admin events
     */
    private fun registerDeviceAdminEventReceiver() {
        if (deviceAdminEventReceiver != null) return
        
        deviceAdminEventReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let { handleDeviceAdminEvent(it) }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.DEVICE_ADMIN_EVENT")
            addAction("com.example.find_phone.SUSPICIOUS_ACTIVITY")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(deviceAdminEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(deviceAdminEventReceiver, filter)
        }
    }

    /**
     * Unregister Device Admin event receiver
     */
    private fun unregisterDeviceAdminEventReceiver() {
        deviceAdminEventReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver not registered
            }
            deviceAdminEventReceiver = null
        }
    }

    /**
     * Handle Device Admin events and forward to Flutter
     */
    private fun handleDeviceAdminEvent(intent: Intent) {
        val eventData = mutableMapOf<String, Any?>()
        
        eventData["action"] = intent.getStringExtra("action")
        eventData["timestamp"] = intent.getLongExtra("timestamp", System.currentTimeMillis())
        
        // Add all extras
        intent.extras?.let { extras ->
            for (key in extras.keySet()) {
                if (key != "action" && key != "timestamp") {
                    eventData[key] = extras.get(key)
                }
            }
        }
        
        // Send to Flutter via EventChannel
        deviceAdminEventSink?.success(eventData)
    }

    // ==================== Protection Service Methods ====================

    /**
     * Enable Kiosk Mode using Task Locking
     * Requirement 3.1: Lock device to show only Anti-Theft App
     * Requirement 3.2: Block home button, recent apps, notification panel
     */
    private fun enableKioskMode(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
                isKioskModeActive = true
                
                // Notify Flutter
                notifyProtectionEvent("KIOSK_MODE_ENABLED")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error enabling Kiosk Mode: ${e.message}")
            false
        }
    }

    /**
     * Disable Kiosk Mode
     * Requirement 3.4: Exit Kiosk Mode with correct password
     */
    private fun disableKioskMode(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
                isKioskModeActive = false
                
                // Notify Flutter
                notifyProtectionEvent("KIOSK_MODE_DISABLED")
                true
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error disabling Kiosk Mode: ${e.message}")
            false
        }
    }

    /**
     * Show custom lock screen in Kiosk Mode
     * Requirement 3.5: Show custom lock screen requiring Master Password
     */
    private fun showKioskLockScreen(message: String?) {
        // Send broadcast to show lock screen overlay
        val intent = Intent("com.example.find_phone.SHOW_KIOSK_LOCK_SCREEN")
        intent.putExtra("message", message ?: "Device Locked")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Exclude app from recent apps list
     * Requirement 18.1: Exclude from recent apps list (Overview screen)
     */
    private fun excludeFromRecentApps(exclude: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val tasks = am.appTasks
            if (tasks.isNotEmpty()) {
                tasks[0].setExcludeFromRecents(exclude)
            }
        }
    }

    /**
     * Set app icon visibility in launcher
     * Requirement 18.3: Optionally hide icon from launcher
     */
    private fun setAppIconVisibility(hide: Boolean) {
        val componentName = android.content.ComponentName(
            packageName,
            "$packageName.MainActivity"
        )
        val state = if (hide) {
            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        } else {
            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        }
        
        packageManager.setComponentEnabledSetting(
            componentName,
            state,
            android.content.pm.PackageManager.DONT_KILL_APP
        )
    }

    /**
     * Register volume button listener for panic mode
     * Requirement 21.1: Activate panic mode on 5 quick volume down presses
     */
    private fun registerVolumeButtonListener() {
        // Volume button monitoring is handled via Accessibility Service
        val intent = Intent("com.example.find_phone.ACCESSIBILITY_COMMAND")
        intent.putExtra("command", "REGISTER_VOLUME_LISTENER")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Unregister volume button listener
     */
    private fun unregisterVolumeButtonListener() {
        val intent = Intent("com.example.find_phone.ACCESSIBILITY_COMMAND")
        intent.putExtra("command", "UNREGISTER_VOLUME_LISTENER")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Register dialer code listener
     * Requirement 18.4: Accessible via dialer code
     */
    private fun registerDialerCodeListener(code: String) {
        // Store the dialer code
        val prefs = getSharedPreferences("protection_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("dialer_code", code).apply()
        
        // Register broadcast receiver for outgoing calls
        // Note: This requires PROCESS_OUTGOING_CALLS permission
    }

    /**
     * Unregister dialer code listener
     */
    private fun unregisterDialerCodeListener() {
        // Unregister the broadcast receiver
    }

    /**
     * Open the app
     * Requirement 18.5: Open and request Master Password
     */
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        startActivity(intent)
    }

    /**
     * Trigger panic alarm
     * Requirement 21.2: Trigger alarm
     */
    private fun triggerPanicAlarm() {
        val intent = Intent("com.example.find_phone.TRIGGER_ALARM")
        intent.putExtra("type", "panic")
        intent.putExtra("duration", 120000L) // 2 minutes
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Stop panic alarm
     */
    private fun stopPanicAlarm() {
        val intent = Intent("com.example.find_phone.STOP_ALARM")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Capture panic photo
     * Requirement 21.2: Capture photo
     */
    private fun capturePanicPhoto() {
        val intent = Intent("com.example.find_phone.CAPTURE_PHOTO")
        intent.putExtra("reason", "panic_mode")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Send panic SMS
     * Requirement 21.2: Send SMS to Emergency Contact
     */
    private fun sendPanicSms(phoneNumber: String) {
        val intent = Intent("com.example.find_phone.SEND_PANIC_SMS")
        intent.putExtra("phone_number", phoneNumber)
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Enable high-frequency location tracking
     * Requirement 21.4: Start continuous location tracking every 30 seconds
     */
    private fun enableHighFrequencyTracking() {
        val intent = Intent("com.example.find_phone.LOCATION_COMMAND")
        intent.putExtra("command", "ENABLE_HIGH_FREQUENCY")
        intent.putExtra("interval", 30000L) // 30 seconds
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Disable high-frequency location tracking
     */
    private fun disableHighFrequencyTracking() {
        val intent = Intent("com.example.find_phone.LOCATION_COMMAND")
        intent.putExtra("command", "DISABLE_HIGH_FREQUENCY")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Register protection event receiver
     */
    private fun registerProtectionEventReceiver() {
        if (protectionEventReceiver != null) return
        
        protectionEventReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let { handleProtectionEvent(it) }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.PROTECTION_EVENT")
            addAction("com.example.find_phone.VOLUME_BUTTON_SEQUENCE")
            addAction("com.example.find_phone.DIALER_CODE_ENTERED")
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(protectionEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(protectionEventReceiver, filter)
        }
    }

    /**
     * Unregister protection event receiver
     */
    private fun unregisterProtectionEventReceiver() {
        protectionEventReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver not registered
            }
            protectionEventReceiver = null
        }
    }

    /**
     * Handle protection events and forward to Flutter
     */
    private fun handleProtectionEvent(intent: Intent) {
        val eventData = mutableMapOf<String, Any?>()
        
        eventData["action"] = intent.getStringExtra("action") ?: intent.action
        eventData["timestamp"] = intent.getLongExtra("timestamp", System.currentTimeMillis())
        
        // Add all extras
        intent.extras?.let { extras ->
            for (key in extras.keySet()) {
                if (key != "action" && key != "timestamp") {
                    eventData[key] = extras.get(key)
                }
            }
        }
        
        // Send to Flutter via EventChannel
        protectionEventSink?.success(eventData)
    }

    /**
     * Notify Flutter of protection events
     */
    private fun notifyProtectionEvent(action: String, extras: Map<String, Any>? = null) {
        val intent = Intent("com.example.find_phone.PROTECTION_EVENT")
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
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterAccessibilityEventReceiver()
        unregisterBootEventReceiver()
        unregisterDeviceAdminEventReceiver()
        unregisterProtectionEventReceiver()
    }
}
