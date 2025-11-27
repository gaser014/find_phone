package com.example.find_phone

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import java.security.MessageDigest

/**
 * Accessibility Service for Anti-Theft Protection
 * 
 * This service provides:
 * - App launch detection and blocking (Settings, file managers) - Requirements 12.2, 23.2
 * - Power menu detection and blocking - Requirement 11.2
 * - Password overlay display - Requirements 2.2, 11.2
 * - Quick Settings panel blocking - Requirements 12.3, 27.3
 * 
 * Requirements: 1.3, 2.2, 3.1, 11.2, 12.2, 12.3, 23.2, 27.3
 */
class AntiTheftAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AntiTheftAccessibility"
        
        // Shared preferences
        const val PREFS_NAME = "accessibility_service_prefs"
        const val KEY_PROTECTED_MODE_ACTIVE = "protected_mode_active"
        const val KEY_BLOCK_SETTINGS = "block_settings"
        const val KEY_BLOCK_FILE_MANAGERS = "block_file_managers"
        const val KEY_BLOCK_POWER_MENU = "block_power_menu"
        const val KEY_BLOCK_QUICK_SETTINGS = "block_quick_settings"
        const val KEY_FILE_MANAGER_ACCESS_UNTIL = "file_manager_access_until"
        const val KEY_PASSWORD_HASH = "password_hash"
        const val KEY_PASSWORD_SALT = "password_salt"
        
        // Additional blocking keys (Requirements 30, 31, 32, 33, 28)
        const val KEY_BLOCK_SCREEN_LOCK_CHANGE = "block_screen_lock_change"
        const val KEY_BLOCK_ACCOUNT_ADDITION = "block_account_addition"
        const val KEY_BLOCK_APP_INSTALLATION = "block_app_installation"
        const val KEY_BLOCK_FACTORY_RESET = "block_factory_reset"
        const val KEY_BLOCK_USB_DATA_TRANSFER = "block_usb_data_transfer"
        
        // File manager access timeout (1 minute)
        const val FILE_MANAGER_ACCESS_TIMEOUT_MS = 60_000L
        
        // Package names to block
        val SETTINGS_PACKAGES = setOf(
            "com.android.settings",
            "com.android.systemui",
            "com.samsung.android.app.settings",
            "com.miui.securitycenter",
            "com.coloros.safecenter",
            "com.oppo.settings",
            "com.oneplus.settings",
            "com.huawei.systemmanager"
        )
        
        val FILE_MANAGER_PACKAGES = setOf(
            "com.android.documentsui",
            "com.google.android.documentsui",
            "com.android.fileexplorer",
            "com.sec.android.app.myfiles",
            "com.mi.android.globalFileexplorer",
            "com.coloros.filemanager",
            "com.oneplus.filemanager",
            "com.huawei.hidisk",
            "com.asus.filemanager",
            "com.lenovo.FileBrowser2",
            "com.rhmsoft.fm",
            "com.estrongs.android.pop",
            "com.ghisler.android.TotalCommander",
            "com.speedsoftware.rootexplorer",
            "com.mixplorer",
            "com.lonelycatgames.Xplore"
        )
        
        // Screen lock settings packages (Requirement 30)
        val SCREEN_LOCK_PACKAGES = setOf(
            "com.android.settings",
            "com.samsung.android.settings.lockscreen",
            "com.miui.securitycenter"
        )
        
        // Account settings packages (Requirement 31)
        val ACCOUNT_PACKAGES = setOf(
            "com.android.settings",
            "com.google.android.gms",
            "com.google.android.gsf.login"
        )
        
        // App installer packages (Requirement 32)
        val INSTALLER_PACKAGES = setOf(
            "com.android.packageinstaller",
            "com.google.android.packageinstaller",
            "com.android.vending",
            "com.samsung.android.packageinstaller",
            "com.miui.packageinstaller",
            "com.oppo.market",
            "com.huawei.appmarket"
        )
        
        // Factory reset related activities (Requirement 33)
        val FACTORY_RESET_ACTIVITIES = setOf(
            "MasterClear",
            "FactoryReset",
            "ResetPhone",
            "ResetSettings"
        )
        
        // Singleton instance for Flutter communication
        @Volatile
        private var instance: AntiTheftAccessibilityService? = null
        
        fun getInstance(): AntiTheftAccessibilityService? = instance
        
        fun isServiceRunning(): Boolean = instance != null
    }


    // Service state
    private var isProtectedModeActive = false
    private var blockSettings = true
    private var blockFileManagers = true
    private var blockPowerMenu = true
    private var blockQuickSettings = true
    
    // Additional blocking states (Requirements 30, 31, 32, 33, 28)
    private var blockScreenLockChange = true
    private var blockAccountAddition = true
    private var blockAppInstallation = true
    private var blockFactoryReset = true
    private var blockUsbDataTransfer = true
    
    // Password overlay
    private var windowManager: WindowManager? = null
    private var passwordOverlayView: View? = null
    private var isOverlayShowing = false
    private var pendingAction: PendingAction? = null
    
    // Volume button tracking for panic mode (Requirement 21.1)
    private var volumeButtonPresses = mutableListOf<Long>()
    private var isVolumeListenerRegistered = false
    private val PANIC_VOLUME_BUTTON_COUNT = 5
    private val PANIC_VOLUME_BUTTON_WINDOW_MS = 3000L // 3 seconds
    
    // Handler for main thread operations
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Broadcast receiver for Flutter commands
    private val commandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let { handleFlutterCommand(it) }
        }
    }
    
    // Broadcast receiver for Device Admin events
    private val deviceAdminEventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let { handleDeviceAdminEvent(it) }
        }
    }

    /**
     * Enum for pending actions after password verification
     */
    enum class PendingAction {
        DISABLE_PROTECTED_MODE,
        ACCESS_SETTINGS,
        ACCESS_FILE_MANAGER,
        DISABLE_DEVICE_ADMIN,
        EXIT_KIOSK_MODE
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "AntiTheftAccessibilityService created")
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Register broadcast receiver for Flutter commands
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.ACCESSIBILITY_COMMAND")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(commandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(commandReceiver, filter)
        }
        
        // Register broadcast receiver for Device Admin events (Requirement 2.2)
        val deviceAdminFilter = IntentFilter().apply {
            addAction("com.example.find_phone.DEVICE_ADMIN_EVENT")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(deviceAdminEventReceiver, deviceAdminFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(deviceAdminEventReceiver, deviceAdminFilter)
        }
        
        loadSettings()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "AntiTheftAccessibilityService connected")
        
        // Configure the service
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                        AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED or
                        AccessibilityEvent.TYPE_VIEW_CLICKED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            // FLAG_REQUEST_FILTER_KEY_EVENTS is required for volume button detection (Requirement 21.1)
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                   AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            notificationTimeout = 100
        }
        serviceInfo = info
        
        // Register volume button listener by default if protected mode is active
        if (isProtectedModeActive) {
            registerVolumeButtonListener()
        }
        
        // Notify Flutter that service is connected
        notifyFlutter("SERVICE_CONNECTED")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "AntiTheftAccessibilityService destroyed")
        instance = null
        
        try {
            unregisterReceiver(commandReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering command receiver: ${e.message}")
        }
        
        try {
            unregisterReceiver(deviceAdminEventReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering device admin event receiver: ${e.message}")
        }
        
        hidePasswordOverlay()
        
        // Notify Flutter that service is disconnected
        notifyFlutter("SERVICE_DISCONNECTED")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !isProtectedModeActive) return
        
        val packageName = event.packageName?.toString() ?: return
        val eventType = event.eventType
        
        when (eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                handleWindowStateChanged(packageName, event)
            }
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> {
                handleNotificationStateChanged(packageName, event)
            }
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AntiTheftAccessibilityService interrupted")
    }

    /**
     * Handle window state changes - detect app launches
     * Requirements: 12.2, 23.2, 30.1, 30.2, 31.1, 31.2, 32.1, 32.2, 32.3, 33.1
     */
    private fun handleWindowStateChanged(packageName: String, event: AccessibilityEvent) {
        Log.d(TAG, "Window state changed: $packageName")
        
        val className = event.className?.toString() ?: ""
        
        // Check for Settings app (Requirement 12.1, 27.1)
        if (blockSettings && isSettingsPackage(packageName)) {
            Log.w(TAG, "Settings app detected - blocking")
            blockApp(packageName, "settings_access")
            return
        }
        
        // Check for file manager apps (Requirement 23.1, 23.2)
        if (blockFileManagers && isFileManagerPackage(packageName)) {
            // Check if we have temporary access
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val accessUntil = prefs.getLong(KEY_FILE_MANAGER_ACCESS_UNTIL, 0)
            
            if (System.currentTimeMillis() < accessUntil) {
                Log.i(TAG, "File manager access allowed - within timeout window")
                return
            }
            
            Log.w(TAG, "File manager detected - showing password overlay")
            showPasswordOverlayForAction(PendingAction.ACCESS_FILE_MANAGER)
            return
        }
        
        // Check for screen lock change attempts (Requirement 30.1, 30.2)
        if (blockScreenLockChange && isScreenLockChangeActivity(packageName, className)) {
            Log.w(TAG, "Screen lock change detected - blocking")
            blockScreenLockChange(packageName)
            return
        }
        
        // Check for account addition attempts (Requirement 31.1, 31.2)
        if (blockAccountAddition && isAccountAdditionActivity(packageName, className)) {
            Log.w(TAG, "Account addition detected - blocking")
            blockAccountAddition(packageName)
            return
        }
        
        // Check for app installation attempts (Requirement 32.1, 32.2, 32.3)
        if (blockAppInstallation && isAppInstallationActivity(packageName, className)) {
            Log.w(TAG, "App installation detected - blocking")
            blockAppInstallation(packageName, className)
            return
        }
        
        // Check for factory reset attempts (Requirement 33.1)
        if (blockFactoryReset && isFactoryResetActivity(packageName, className)) {
            Log.w(TAG, "Factory reset detected - blocking")
            blockFactoryReset(packageName)
            return
        }
        
        // Check for power menu (SystemUI with specific window)
        if (blockPowerMenu && isPowerMenuWindow(packageName, event)) {
            Log.w(TAG, "Power menu detected - blocking")
            blockPowerMenu()
            return
        }
        
        // Check for Quick Settings panel
        if (blockQuickSettings && isQuickSettingsPanel(packageName, event)) {
            Log.w(TAG, "Quick Settings panel detected - blocking")
            blockQuickSettingsPanel()
            return
        }
    }

    /**
     * Handle notification state changes
     */
    private fun handleNotificationStateChanged(packageName: String, event: AccessibilityEvent) {
        // Check for Quick Settings notifications
        if (blockQuickSettings && packageName == "com.android.systemui") {
            val className = event.className?.toString() ?: ""
            if (className.contains("QuickSettings") || className.contains("QS")) {
                Log.w(TAG, "Quick Settings notification detected")
                blockQuickSettingsPanel()
            }
        }
    }


    /**
     * Check if package is a Settings app
     */
    private fun isSettingsPackage(packageName: String): Boolean {
        return SETTINGS_PACKAGES.contains(packageName) ||
               packageName.contains("settings", ignoreCase = true)
    }

    /**
     * Check if package is a file manager app
     */
    private fun isFileManagerPackage(packageName: String): Boolean {
        return FILE_MANAGER_PACKAGES.contains(packageName) ||
               packageName.contains("filemanager", ignoreCase = true) ||
               packageName.contains("fileexplorer", ignoreCase = true) ||
               packageName.contains("filebrowser", ignoreCase = true)
    }

    /**
     * Check if activity is for screen lock change
     * Requirement 30.1: Monitor attempts to change screen lock
     */
    private fun isScreenLockChangeActivity(packageName: String, className: String): Boolean {
        if (!SCREEN_LOCK_PACKAGES.contains(packageName) && 
            !packageName.contains("settings", ignoreCase = true)) {
            return false
        }
        
        return className.contains("ChooseLockGeneric", ignoreCase = true) ||
               className.contains("ChooseLockPassword", ignoreCase = true) ||
               className.contains("ChooseLockPattern", ignoreCase = true) ||
               className.contains("SetupChooseLock", ignoreCase = true) ||
               className.contains("ScreenLock", ignoreCase = true) ||
               className.contains("LockScreen", ignoreCase = true) ||
               className.contains("SecuritySettings", ignoreCase = true)
    }

    /**
     * Check if activity is for account addition
     * Requirement 31.1: Monitor attempts to add new accounts
     */
    private fun isAccountAdditionActivity(packageName: String, className: String): Boolean {
        if (!ACCOUNT_PACKAGES.contains(packageName)) {
            return false
        }
        
        return className.contains("AddAccount", ignoreCase = true) ||
               className.contains("AccountSetup", ignoreCase = true) ||
               className.contains("LoginActivity", ignoreCase = true) ||
               className.contains("SignIn", ignoreCase = true) ||
               className.contains("AccountsSettings", ignoreCase = true)
    }

    /**
     * Check if activity is for app installation
     * Requirement 32.1: Monitor app installation attempts
     */
    private fun isAppInstallationActivity(packageName: String, className: String): Boolean {
        if (INSTALLER_PACKAGES.contains(packageName)) {
            return true
        }
        
        return className.contains("PackageInstaller", ignoreCase = true) ||
               className.contains("InstallAppProgress", ignoreCase = true) ||
               className.contains("UninstallAppProgress", ignoreCase = true) ||
               className.contains("DeleteStagedInstall", ignoreCase = true)
    }

    /**
     * Check if activity is for factory reset
     * Requirement 33.1: Block factory reset from Settings
     */
    private fun isFactoryResetActivity(packageName: String, className: String): Boolean {
        if (!packageName.contains("settings", ignoreCase = true)) {
            return false
        }
        
        return FACTORY_RESET_ACTIVITIES.any { className.contains(it, ignoreCase = true) } ||
               className.contains("BackupReset", ignoreCase = true) ||
               className.contains("ResetNetwork", ignoreCase = true)
    }

    /**
     * Check if the current window is the power menu
     * Requirement: 11.2
     */
    private fun isPowerMenuWindow(packageName: String, event: AccessibilityEvent): Boolean {
        if (packageName != "com.android.systemui") return false
        
        val className = event.className?.toString() ?: ""
        val text = event.text?.joinToString(" ") ?: ""
        
        // Check for power menu indicators
        return className.contains("GlobalActions", ignoreCase = true) ||
               className.contains("PowerMenu", ignoreCase = true) ||
               className.contains("ShutdownThread", ignoreCase = true) ||
               text.contains("Power off", ignoreCase = true) ||
               text.contains("Restart", ignoreCase = true) ||
               text.contains("إيقاف التشغيل", ignoreCase = true) ||
               text.contains("إعادة التشغيل", ignoreCase = true)
    }

    /**
     * Check if the current window is Quick Settings panel
     * Requirements: 12.3, 27.3
     */
    private fun isQuickSettingsPanel(packageName: String, event: AccessibilityEvent): Boolean {
        if (packageName != "com.android.systemui") return false
        
        val className = event.className?.toString() ?: ""
        
        return className.contains("QuickSettings", ignoreCase = true) ||
               className.contains("QSPanel", ignoreCase = true) ||
               className.contains("StatusBar", ignoreCase = true) ||
               className.contains("NotificationShade", ignoreCase = true)
    }

    /**
     * Block an app by going back to home screen
     * Requirements: 12.2, 27.2
     */
    private fun blockApp(packageName: String, reason: String) {
        Log.i(TAG, "Blocking app: $packageName, reason: $reason")
        
        // Perform global action to go home
        performGlobalAction(GLOBAL_ACTION_HOME)
        
        // Log the event
        logSecurityEvent(reason, mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Capture photo for security
        notifyFlutter("CAPTURE_PHOTO", mapOf("reason" to reason))
        
        // Show toast message
        mainHandler.post {
            Toast.makeText(
                this,
                "⚠️ الوصول محظور - وضع الحماية مفعل",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /**
     * Block power menu
     * Requirement: 11.2
     */
    private fun blockPowerMenu() {
        Log.i(TAG, "Blocking power menu")
        
        // Press back to dismiss power menu
        performGlobalAction(GLOBAL_ACTION_BACK)
        
        // Show password overlay
        showPasswordOverlayForAction(PendingAction.DISABLE_PROTECTED_MODE)
        
        // Log the event
        logSecurityEvent("power_menu_blocked", mapOf(
            "timestamp" to System.currentTimeMillis()
        ))
    }

    /**
     * Block Quick Settings panel
     * Requirements: 12.3, 27.3
     */
    private fun blockQuickSettingsPanel() {
        Log.i(TAG, "Blocking Quick Settings panel")
        
        // Collapse the notification shade
        performGlobalAction(GLOBAL_ACTION_BACK)
        
        // Alternative: go home
        mainHandler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 100)
        
        // Log the event
        logSecurityEvent("quick_settings_blocked", mapOf(
            "timestamp" to System.currentTimeMillis()
        ))
    }

    /**
     * Block screen lock change attempt
     * Requirement 30.2: Block the change and display warning
     */
    private fun blockScreenLockChange(packageName: String) {
        Log.i(TAG, "Blocking screen lock change: $packageName")
        
        // Go back to home
        performGlobalAction(GLOBAL_ACTION_BACK)
        mainHandler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 100)
        
        // Log the event
        logSecurityEvent("screen_lock_change_blocked", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Capture photo for security (Requirement 30.4)
        notifyFlutter("CAPTURE_PHOTO", mapOf("reason" to "screen_lock_change_blocked"))
        
        // Notify Flutter about the blocking event
        notifyFlutter("SCREEN_LOCK_CHANGE_BLOCKED", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Show warning toast
        mainHandler.post {
            Toast.makeText(
                this,
                "⚠️ تغيير قفل الشاشة محظور - وضع الحماية مفعل",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /**
     * Block account addition attempt
     * Requirement 31.2: Block the addition and close the account setup
     */
    private fun blockAccountAddition(packageName: String) {
        Log.i(TAG, "Blocking account addition: $packageName")
        
        // Go back to home
        performGlobalAction(GLOBAL_ACTION_BACK)
        mainHandler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 100)
        
        // Log the event
        logSecurityEvent("account_addition_blocked", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Notify Flutter about the blocking event
        notifyFlutter("ACCOUNT_ADDITION_BLOCKED", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Show warning toast
        mainHandler.post {
            Toast.makeText(
                this,
                "⚠️ إضافة حساب محظورة - وضع الحماية مفعل",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /**
     * Block app installation/uninstallation attempt
     * Requirements 32.2, 32.3: Block installation and uninstallation
     */
    private fun blockAppInstallation(packageName: String, className: String) {
        Log.i(TAG, "Blocking app installation: $packageName, $className")
        
        val isUninstall = className.contains("Uninstall", ignoreCase = true)
        
        // Go back to home
        performGlobalAction(GLOBAL_ACTION_BACK)
        mainHandler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 100)
        
        // Log the event
        val eventType = if (isUninstall) "app_uninstallation_blocked" else "app_installation_blocked"
        logSecurityEvent(eventType, mapOf(
            "package_name" to packageName,
            "class_name" to className,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Capture photo for security (Requirement 32.5)
        notifyFlutter("CAPTURE_PHOTO", mapOf("reason" to eventType))
        
        // Notify Flutter about the blocking event
        notifyFlutter(if (isUninstall) "APP_UNINSTALLATION_BLOCKED" else "APP_INSTALLATION_BLOCKED", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Show warning toast
        val message = if (isUninstall) {
            "⚠️ إزالة التطبيقات محظورة - وضع الحماية مفعل"
        } else {
            "⚠️ تثبيت التطبيقات محظور - وضع الحماية مفعل"
        }
        mainHandler.post {
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        }
    }

    /**
     * Block factory reset attempt
     * Requirement 33.1: Block factory reset completely
     */
    private fun blockFactoryReset(packageName: String) {
        Log.i(TAG, "Blocking factory reset: $packageName")
        
        // Go back to home immediately
        performGlobalAction(GLOBAL_ACTION_BACK)
        mainHandler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 100)
        
        // Log the event
        logSecurityEvent("factory_reset_blocked", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Trigger alarm (Requirement 33.5)
        notifyFlutter("TRIGGER_ALARM", mapOf("reason" to "factory_reset_blocked"))
        
        // Send SMS to emergency contact (Requirement 33.5)
        notifyFlutter("SEND_EMERGENCY_SMS", mapOf(
            "reason" to "factory_reset_blocked",
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Notify Flutter about the blocking event
        notifyFlutter("FACTORY_RESET_BLOCKED", mapOf(
            "package_name" to packageName,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // Show warning toast
        mainHandler.post {
            Toast.makeText(
                this,
                "⚠️ إعادة ضبط المصنع محظورة - وضع الحماية مفعل",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /**
     * Show password overlay for a specific action
     * Requirements: 2.2, 11.2
     */
    fun showPasswordOverlayForAction(action: PendingAction) {
        if (isOverlayShowing) {
            Log.d(TAG, "Overlay already showing")
            return
        }
        
        pendingAction = action
        mainHandler.post { showPasswordOverlay() }
    }

    /**
     * Show password overlay
     */
    private fun showPasswordOverlay() {
        if (isOverlayShowing || windowManager == null) return
        
        try {
            val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            passwordOverlayView = inflater.inflate(R.layout.password_overlay, null)
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.CENTER
            
            // Make it focusable for input
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
            
            setupPasswordOverlayListeners()
            
            windowManager?.addView(passwordOverlayView, params)
            isOverlayShowing = true
            
            Log.i(TAG, "Password overlay shown")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing password overlay: ${e.message}")
        }
    }

    /**
     * Setup listeners for password overlay
     */
    private fun setupPasswordOverlayListeners() {
        passwordOverlayView?.let { view ->
            val passwordInput = view.findViewById<EditText>(R.id.password_input)
            val submitButton = view.findViewById<Button>(R.id.submit_button)
            val cancelButton = view.findViewById<Button>(R.id.cancel_button)
            val titleText = view.findViewById<TextView>(R.id.title_text)
            
            // Set title based on pending action
            titleText?.text = when (pendingAction) {
                PendingAction.ACCESS_FILE_MANAGER -> "أدخل كلمة المرور للوصول لمدير الملفات"
                PendingAction.ACCESS_SETTINGS -> "أدخل كلمة المرور للوصول للإعدادات"
                PendingAction.DISABLE_PROTECTED_MODE -> "أدخل كلمة المرور لإيقاف وضع الحماية"
                PendingAction.DISABLE_DEVICE_ADMIN -> "أدخل كلمة المرور لإلغاء صلاحيات المسؤول"
                PendingAction.EXIT_KIOSK_MODE -> "أدخل كلمة المرور للخروج من وضع القفل"
                null -> "أدخل كلمة المرور"
            }
            
            submitButton?.setOnClickListener {
                val password = passwordInput?.text?.toString() ?: ""
                verifyPassword(password)
            }
            
            cancelButton?.setOnClickListener {
                hidePasswordOverlay()
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }


    /**
     * Verify password and execute pending action
     */
    private fun verifyPassword(password: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val storedHash = prefs.getString(KEY_PASSWORD_HASH, null)
        val storedSalt = prefs.getString(KEY_PASSWORD_SALT, null)
        
        if (storedHash == null || storedSalt == null) {
            Log.e(TAG, "No password stored - allowing action")
            executeAction()
            return
        }
        
        val inputHash = hashPassword(password, storedSalt)
        
        if (inputHash == storedHash) {
            Log.i(TAG, "Password verified successfully")
            executeAction()
        } else {
            Log.w(TAG, "Password verification failed")
            
            // Log failed attempt
            logSecurityEvent("failed_password_attempt", mapOf(
                "action" to (pendingAction?.name ?: "unknown"),
                "timestamp" to System.currentTimeMillis()
            ))
            
            // Notify Flutter about failed attempt
            notifyFlutter("PASSWORD_FAILED", mapOf(
                "action" to (pendingAction?.name ?: "unknown")
            ))
            
            // Show error message
            mainHandler.post {
                Toast.makeText(
                    this,
                    "❌ كلمة المرور غير صحيحة",
                    Toast.LENGTH_SHORT
                ).show()
            }
            
            // Clear input
            passwordOverlayView?.findViewById<EditText>(R.id.password_input)?.setText("")
        }
    }

    /**
     * Execute the pending action after successful password verification
     */
    private fun executeAction() {
        hidePasswordOverlay()
        
        when (pendingAction) {
            PendingAction.ACCESS_FILE_MANAGER -> {
                // Grant temporary file manager access (1 minute)
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().putLong(
                    KEY_FILE_MANAGER_ACCESS_UNTIL,
                    System.currentTimeMillis() + FILE_MANAGER_ACCESS_TIMEOUT_MS
                ).apply()
                
                Log.i(TAG, "File manager access granted for 1 minute")
                mainHandler.post {
                    Toast.makeText(
                        this,
                        "✓ تم منح الوصول لمدير الملفات لمدة دقيقة واحدة",
                        Toast.LENGTH_LONG
                    ).show()
                }
                
                // Schedule access revocation
                mainHandler.postDelayed({
                    revokeFileManagerAccess()
                }, FILE_MANAGER_ACCESS_TIMEOUT_MS)
            }
            
            PendingAction.ACCESS_SETTINGS -> {
                // Temporarily allow settings access
                blockSettings = false
                mainHandler.postDelayed({
                    blockSettings = true
                }, 30_000) // 30 seconds
                
                Log.i(TAG, "Settings access granted for 30 seconds")
            }
            
            PendingAction.DISABLE_PROTECTED_MODE -> {
                // Notify Flutter to disable protected mode
                notifyFlutter("DISABLE_PROTECTED_MODE_REQUESTED")
            }
            
            PendingAction.DISABLE_DEVICE_ADMIN -> {
                // Set deactivation window
                val adminPrefs = getSharedPreferences(
                    DeviceAdminReceiver.PREFS_NAME,
                    Context.MODE_PRIVATE
                )
                adminPrefs.edit().putLong(
                    DeviceAdminReceiver.KEY_DEACTIVATION_ALLOWED_UNTIL,
                    System.currentTimeMillis() + DeviceAdminReceiver.DEACTIVATION_WINDOW_MS
                ).apply()
                
                Log.i(TAG, "Device admin deactivation window opened for 30 seconds")
                mainHandler.post {
                    Toast.makeText(
                        this,
                        "✓ يمكنك الآن إلغاء صلاحيات المسؤول خلال 30 ثانية",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
            
            PendingAction.EXIT_KIOSK_MODE -> {
                // Notify Flutter to exit kiosk mode
                notifyFlutter("EXIT_KIOSK_MODE_REQUESTED")
            }
            
            null -> {
                Log.w(TAG, "No pending action")
            }
        }
        
        pendingAction = null
    }

    /**
     * Revoke file manager access after timeout
     * Requirement: 23.4
     */
    private fun revokeFileManagerAccess() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_FILE_MANAGER_ACCESS_UNTIL).apply()
        
        Log.i(TAG, "File manager access revoked")
        
        // Close any open file manager
        performGlobalAction(GLOBAL_ACTION_HOME)
        
        mainHandler.post {
            Toast.makeText(
                this,
                "⏱️ انتهت مدة الوصول لمدير الملفات",
                Toast.LENGTH_SHORT
            ).show()
        }
    }

    /**
     * Hide password overlay
     */
    fun hidePasswordOverlay() {
        if (!isOverlayShowing || passwordOverlayView == null) return
        
        try {
            windowManager?.removeView(passwordOverlayView)
            passwordOverlayView = null
            isOverlayShowing = false
            pendingAction = null
            Log.i(TAG, "Password overlay hidden")
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding password overlay: ${e.message}")
        }
    }

    /**
     * Hash password with salt using SHA-256
     */
    private fun hashPassword(password: String, salt: String): String {
        val combined = password + salt
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(combined.toByteArray(Charsets.UTF_8))
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Handle commands from Flutter
     */
    private fun handleFlutterCommand(intent: Intent) {
        val command = intent.getStringExtra("command") ?: return
        Log.d(TAG, "Received Flutter command: $command")
        
        when (command) {
            "ENABLE_PROTECTED_MODE" -> {
                isProtectedModeActive = true
                saveSettings()
                Log.i(TAG, "Protected mode enabled")
            }
            "DISABLE_PROTECTED_MODE" -> {
                isProtectedModeActive = false
                saveSettings()
                Log.i(TAG, "Protected mode disabled")
            }
            "SET_BLOCK_SETTINGS" -> {
                blockSettings = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_FILE_MANAGERS" -> {
                blockFileManagers = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_POWER_MENU" -> {
                blockPowerMenu = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_QUICK_SETTINGS" -> {
                blockQuickSettings = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SHOW_PASSWORD_OVERLAY" -> {
                val actionStr = intent.getStringExtra("action") ?: "DISABLE_PROTECTED_MODE"
                val action = try {
                    PendingAction.valueOf(actionStr)
                } catch (e: Exception) {
                    PendingAction.DISABLE_PROTECTED_MODE
                }
                showPasswordOverlayForAction(action)
            }
            "HIDE_PASSWORD_OVERLAY" -> {
                hidePasswordOverlay()
            }
            "UPDATE_PASSWORD" -> {
                val hash = intent.getStringExtra("hash")
                val salt = intent.getStringExtra("salt")
                if (hash != null && salt != null) {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putString(KEY_PASSWORD_HASH, hash)
                        .putString(KEY_PASSWORD_SALT, salt)
                        .apply()
                    Log.i(TAG, "Password updated")
                }
            }
            "REGISTER_VOLUME_LISTENER" -> {
                registerVolumeButtonListener()
            }
            "UNREGISTER_VOLUME_LISTENER" -> {
                unregisterVolumeButtonListener()
            }
            "SHOW_LOCK_SCREEN_MESSAGE" -> {
                val message = intent.getStringExtra("message")
                val ownerContact = intent.getStringExtra("owner_contact")
                val instructions = intent.getStringExtra("instructions")
                showLockScreenMessage(message, ownerContact, instructions)
            }
            "HIDE_LOCK_SCREEN_MESSAGE" -> {
                hideLockScreenMessage()
            }
            "UPDATE_LOCK_SCREEN_MESSAGE" -> {
                val message = intent.getStringExtra("message")
                val ownerContact = intent.getStringExtra("owner_contact")
                val instructions = intent.getStringExtra("instructions")
                updateLockScreenContent(message, ownerContact, instructions)
            }
            // Additional blocking commands (Requirements 30, 31, 32, 33, 28)
            "SET_BLOCK_SCREEN_LOCK_CHANGE" -> {
                blockScreenLockChange = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_ACCOUNT_ADDITION" -> {
                blockAccountAddition = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_APP_INSTALLATION" -> {
                blockAppInstallation = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_FACTORY_RESET" -> {
                blockFactoryReset = intent.getBooleanExtra("value", true)
                saveSettings()
            }
            "SET_BLOCK_USB_DATA_TRANSFER" -> {
                blockUsbDataTransfer = intent.getBooleanExtra("value", true)
                saveSettings()
            }
        }
    }

    /**
     * Register volume button listener for panic mode
     * Requirement 21.1: Activate panic mode on 5 quick volume down presses
     */
    private fun registerVolumeButtonListener() {
        isVolumeListenerRegistered = true
        volumeButtonPresses.clear()
        Log.i(TAG, "Volume button listener registered for panic mode")
    }

    /**
     * Unregister volume button listener
     */
    private fun unregisterVolumeButtonListener() {
        isVolumeListenerRegistered = false
        volumeButtonPresses.clear()
        Log.i(TAG, "Volume button listener unregistered")
    }

    /**
     * Handle volume button press for panic mode detection
     * Requirement 21.1: Activate panic mode on 5 quick volume down presses
     */
    private fun handleVolumeButtonPress() {
        if (!isVolumeListenerRegistered || !isProtectedModeActive) return
        
        val now = System.currentTimeMillis()
        
        // Remove old presses outside the window
        volumeButtonPresses.removeAll { now - it > PANIC_VOLUME_BUTTON_WINDOW_MS }
        
        // Add current press
        volumeButtonPresses.add(now)
        
        Log.d(TAG, "Volume button press detected - count: ${volumeButtonPresses.size}")
        
        // Check if we have enough presses for panic mode
        if (volumeButtonPresses.size >= PANIC_VOLUME_BUTTON_COUNT) {
            volumeButtonPresses.clear()
            triggerPanicMode()
        }
    }

    /**
     * Trigger panic mode
     * Requirement 21.2: Enable Kiosk Mode, trigger alarm, capture photo, send SMS
     */
    private fun triggerPanicMode() {
        Log.w(TAG, "PANIC MODE TRIGGERED!")
        
        // Notify Flutter to activate panic mode
        notifyFlutter("VOLUME_BUTTON_SEQUENCE_DETECTED", mapOf(
            "timestamp" to System.currentTimeMillis(),
            "trigger_panic" to true
        ))
        
        // Also send a separate broadcast for the protection service
        val panicIntent = Intent("com.example.find_phone.VOLUME_BUTTON_SEQUENCE")
        panicIntent.putExtra("action", "PANIC_MODE_TRIGGERED")
        panicIntent.putExtra("timestamp", System.currentTimeMillis())
        panicIntent.setPackage(packageName)
        sendBroadcast(panicIntent)
        
        // Log security event
        logSecurityEvent("panic_mode_triggered", mapOf(
            "trigger" to "volume_button_sequence",
            "timestamp" to System.currentTimeMillis()
        ))
    }

    /**
     * Override onKeyEvent to detect volume button presses
     * Requirement 21.1: Detect volume down button presses
     */
    override fun onKeyEvent(event: android.view.KeyEvent?): Boolean {
        if (event == null) return super.onKeyEvent(event)
        
        // Only handle volume down key presses
        if (event.keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.action == android.view.KeyEvent.ACTION_DOWN) {
            handleVolumeButtonPress()
        }
        
        return super.onKeyEvent(event)
    }

    /**
     * Handle Device Admin events
     * Requirement 2.2: Intercept deactivation attempts and display full-screen password prompt
     */
    private fun handleDeviceAdminEvent(intent: Intent) {
        val action = intent.getStringExtra("action") ?: return
        Log.d(TAG, "Received Device Admin event: $action")
        
        when (action) {
            "DEVICE_ADMIN_DISABLE_REQUESTED" -> {
                // Check if protected mode is active
                if (isProtectedModeActive) {
                    Log.w(TAG, "Device Admin disable requested while protected mode is active")
                    
                    // Show full-screen password overlay for device admin deactivation
                    showPasswordOverlayForAction(PendingAction.DISABLE_DEVICE_ADMIN)
                    
                    // Log the security event
                    logSecurityEvent("device_admin_disable_requested", mapOf(
                        "timestamp" to System.currentTimeMillis(),
                        "protected_mode_active" to true
                    ))
                    
                    // Notify Flutter about the attempt
                    notifyFlutter("DEVICE_ADMIN_DISABLE_REQUESTED", mapOf(
                        "timestamp" to System.currentTimeMillis()
                    ))
                } else {
                    Log.i(TAG, "Device Admin disable requested - protected mode not active, allowing")
                }
            }
            "DEVICE_ADMIN_ENABLED" -> {
                Log.i(TAG, "Device Admin enabled")
                notifyFlutter("DEVICE_ADMIN_ENABLED")
            }
            "DEVICE_ADMIN_DISABLED" -> {
                Log.i(TAG, "Device Admin disabled")
                notifyFlutter("DEVICE_ADMIN_DISABLED")
            }
            "PASSWORD_FAILED" -> {
                Log.w(TAG, "Device password failed")
                notifyFlutter("DEVICE_PASSWORD_FAILED")
            }
            "PASSWORD_SUCCEEDED" -> {
                Log.i(TAG, "Device password succeeded")
                notifyFlutter("DEVICE_PASSWORD_SUCCEEDED")
            }
            "PASSWORD_CHANGED" -> {
                Log.w(TAG, "Device password changed")
                if (isProtectedModeActive) {
                    // Log as suspicious activity if protected mode is active
                    logSecurityEvent("device_password_changed", mapOf(
                        "timestamp" to System.currentTimeMillis(),
                        "protected_mode_active" to true
                    ))
                }
                notifyFlutter("DEVICE_PASSWORD_CHANGED")
            }
        }
    }

    /**
     * Load settings from SharedPreferences
     */
    private fun loadSettings() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        isProtectedModeActive = prefs.getBoolean(KEY_PROTECTED_MODE_ACTIVE, false)
        blockSettings = prefs.getBoolean(KEY_BLOCK_SETTINGS, true)
        blockFileManagers = prefs.getBoolean(KEY_BLOCK_FILE_MANAGERS, true)
        blockPowerMenu = prefs.getBoolean(KEY_BLOCK_POWER_MENU, true)
        blockQuickSettings = prefs.getBoolean(KEY_BLOCK_QUICK_SETTINGS, true)
        
        // Load additional blocking settings (Requirements 30, 31, 32, 33, 28)
        blockScreenLockChange = prefs.getBoolean(KEY_BLOCK_SCREEN_LOCK_CHANGE, true)
        blockAccountAddition = prefs.getBoolean(KEY_BLOCK_ACCOUNT_ADDITION, true)
        blockAppInstallation = prefs.getBoolean(KEY_BLOCK_APP_INSTALLATION, true)
        blockFactoryReset = prefs.getBoolean(KEY_BLOCK_FACTORY_RESET, true)
        blockUsbDataTransfer = prefs.getBoolean(KEY_BLOCK_USB_DATA_TRANSFER, true)
        
        Log.i(TAG, "Settings loaded - Protected mode: $isProtectedModeActive")
    }

    /**
     * Save settings to SharedPreferences
     */
    private fun saveSettings() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_PROTECTED_MODE_ACTIVE, isProtectedModeActive)
            .putBoolean(KEY_BLOCK_SETTINGS, blockSettings)
            .putBoolean(KEY_BLOCK_FILE_MANAGERS, blockFileManagers)
            .putBoolean(KEY_BLOCK_POWER_MENU, blockPowerMenu)
            .putBoolean(KEY_BLOCK_QUICK_SETTINGS, blockQuickSettings)
            // Save additional blocking settings (Requirements 30, 31, 32, 33, 28)
            .putBoolean(KEY_BLOCK_SCREEN_LOCK_CHANGE, blockScreenLockChange)
            .putBoolean(KEY_BLOCK_ACCOUNT_ADDITION, blockAccountAddition)
            .putBoolean(KEY_BLOCK_APP_INSTALLATION, blockAppInstallation)
            .putBoolean(KEY_BLOCK_FACTORY_RESET, blockFactoryReset)
            .putBoolean(KEY_BLOCK_USB_DATA_TRANSFER, blockUsbDataTransfer)
            .apply()
        
        Log.i(TAG, "Settings saved")
    }

    /**
     * Notify Flutter side via broadcast
     */
    private fun notifyFlutter(action: String, extras: Map<String, Any>? = null) {
        val intent = Intent("com.example.find_phone.ACCESSIBILITY_EVENT")
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

    /**
     * Log security event
     */
    private fun logSecurityEvent(eventType: String, metadata: Map<String, Any>) {
        val intent = Intent("com.example.find_phone.SECURITY_EVENT")
        intent.putExtra("event_type", eventType)
        intent.putExtra("timestamp", System.currentTimeMillis())
        metadata.forEach { (key, value) ->
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

    // ==================== Public API for Flutter ====================

    /**
     * Check if protected mode is active
     */
    fun getProtectedModeActive(): Boolean = isProtectedModeActive

    /**
     * Enable protected mode
     */
    fun enableProtectedMode() {
        isProtectedModeActive = true
        saveSettings()
        notifyFlutter("PROTECTED_MODE_ENABLED")
    }

    /**
     * Disable protected mode
     */
    fun disableProtectedMode() {
        isProtectedModeActive = false
        saveSettings()
        notifyFlutter("PROTECTED_MODE_DISABLED")
    }

    /**
     * Set blocking options
     */
    fun setBlockingOptions(
        settings: Boolean = true,
        fileManagers: Boolean = true,
        powerMenu: Boolean = true,
        quickSettings: Boolean = true
    ) {
        blockSettings = settings
        blockFileManagers = fileManagers
        blockPowerMenu = powerMenu
        blockQuickSettings = quickSettings
        saveSettings()
    }

    /**
     * Update password hash and salt
     */
    fun updatePassword(hash: String, salt: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_PASSWORD_HASH, hash)
            .putString(KEY_PASSWORD_SALT, salt)
            .apply()
    }

    /**
     * Check if a specific package is blocked
     */
    fun isPackageBlocked(packageName: String): Boolean {
        if (!isProtectedModeActive) return false
        
        if (blockSettings && isSettingsPackage(packageName)) return true
        if (blockFileManagers && isFileManagerPackage(packageName)) return true
        
        return false
    }

    /**
     * Get current blocking status
     */
    fun getBlockingStatus(): Map<String, Boolean> {
        return mapOf(
            "protected_mode" to isProtectedModeActive,
            "block_settings" to blockSettings,
            "block_file_managers" to blockFileManagers,
            "block_power_menu" to blockPowerMenu,
            "block_quick_settings" to blockQuickSettings,
            // Additional blocking status (Requirements 30, 31, 32, 33, 28)
            "block_screen_lock_change" to blockScreenLockChange,
            "block_account_addition" to blockAccountAddition,
            "block_app_installation" to blockAppInstallation,
            "block_factory_reset" to blockFactoryReset,
            "block_usb_data_transfer" to blockUsbDataTransfer
        )
    }
    
    /**
     * Set additional blocking options
     * Requirements: 30, 31, 32, 33, 28
     */
    fun setAdditionalBlockingOptions(
        screenLockChange: Boolean = true,
        accountAddition: Boolean = true,
        appInstallation: Boolean = true,
        factoryReset: Boolean = true,
        usbDataTransfer: Boolean = true
    ) {
        blockScreenLockChange = screenLockChange
        blockAccountAddition = accountAddition
        blockAppInstallation = appInstallation
        blockFactoryReset = factoryReset
        blockUsbDataTransfer = usbDataTransfer
        saveSettings()
    }

    // ==================== Lock Screen Message Overlay ====================
    // Requirement 8.2: Display custom full-screen message with owner contact information

    private var lockScreenOverlayView: View? = null
    private var isLockScreenOverlayShowing = false
    private var currentLockScreenMessage: String? = null
    private var currentOwnerContact: String? = null

    /**
     * Show custom lock screen message overlay
     * Requirement 8.2: Display custom full-screen message with owner contact information
     * 
     * @param message Custom message to display
     * @param ownerContact Owner's contact information (phone number or email)
     * @param instructions Additional instructions for finder
     */
    fun showLockScreenMessage(
        message: String? = null,
        ownerContact: String? = null,
        instructions: String? = null
    ) {
        if (isLockScreenOverlayShowing) {
            Log.d(TAG, "Lock screen overlay already showing, updating content")
            updateLockScreenContent(message, ownerContact, instructions)
            return
        }

        currentLockScreenMessage = message
        currentOwnerContact = ownerContact
        mainHandler.post { showLockScreenOverlay(message, ownerContact, instructions) }
    }

    /**
     * Show the lock screen overlay
     */
    private fun showLockScreenOverlay(
        message: String?,
        ownerContact: String?,
        instructions: String?
    ) {
        if (isLockScreenOverlayShowing || windowManager == null) return

        try {
            val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            lockScreenOverlayView = inflater.inflate(R.layout.lock_screen_message_overlay, null)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_FULLSCREEN or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.CENTER

            // Make it focusable for password input
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()

            setupLockScreenOverlayContent(message, ownerContact, instructions)
            setupLockScreenOverlayListeners()

            windowManager?.addView(lockScreenOverlayView, params)
            isLockScreenOverlayShowing = true

            Log.i(TAG, "Lock screen message overlay shown")
            notifyFlutter("LOCK_SCREEN_MESSAGE_SHOWN", mapOf(
                "message" to (message ?: ""),
                "owner_contact" to (ownerContact ?: "")
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Error showing lock screen overlay: ${e.message}")
        }
    }

    /**
     * Setup lock screen overlay content
     */
    private fun setupLockScreenOverlayContent(
        message: String?,
        ownerContact: String?,
        instructions: String?
    ) {
        lockScreenOverlayView?.let { view ->
            val messageText = view.findViewById<TextView>(R.id.lock_message)
            val ownerContactText = view.findViewById<TextView>(R.id.owner_contact)
            val instructionsText = view.findViewById<TextView>(R.id.lock_instructions)
            val contactContainer = view.findViewById<View>(R.id.contact_info_container)

            // Set custom message
            if (!message.isNullOrEmpty()) {
                messageText?.text = message
            }

            // Set owner contact info
            if (!ownerContact.isNullOrEmpty()) {
                ownerContactText?.text = ownerContact
                contactContainer?.visibility = View.VISIBLE
            } else {
                contactContainer?.visibility = View.GONE
            }

            // Set instructions
            if (!instructions.isNullOrEmpty()) {
                instructionsText?.text = instructions
            }
        }
    }

    /**
     * Update lock screen content without recreating the overlay
     */
    private fun updateLockScreenContent(
        message: String?,
        ownerContact: String?,
        instructions: String?
    ) {
        currentLockScreenMessage = message ?: currentLockScreenMessage
        currentOwnerContact = ownerContact ?: currentOwnerContact
        
        mainHandler.post {
            setupLockScreenOverlayContent(
                currentLockScreenMessage,
                currentOwnerContact,
                instructions
            )
        }
    }

    /**
     * Setup listeners for lock screen overlay
     */
    private fun setupLockScreenOverlayListeners() {
        lockScreenOverlayView?.let { view ->
            val passwordInput = view.findViewById<EditText>(R.id.unlock_password_input)
            val unlockButton = view.findViewById<Button>(R.id.unlock_button)

            unlockButton?.setOnClickListener {
                val password = passwordInput?.text?.toString() ?: ""
                verifyLockScreenPassword(password)
            }
        }
    }

    /**
     * Verify password for lock screen unlock
     */
    private fun verifyLockScreenPassword(password: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val storedHash = prefs.getString(KEY_PASSWORD_HASH, null)
        val storedSalt = prefs.getString(KEY_PASSWORD_SALT, null)

        if (storedHash == null || storedSalt == null) {
            Log.e(TAG, "No password stored - hiding lock screen")
            hideLockScreenMessage()
            return
        }

        val inputHash = hashPassword(password, storedSalt)

        if (inputHash == storedHash) {
            Log.i(TAG, "Lock screen password verified successfully")
            hideLockScreenMessage()
            
            // Notify Flutter about successful unlock
            notifyFlutter("LOCK_SCREEN_UNLOCKED", mapOf(
                "timestamp" to System.currentTimeMillis()
            ))
        } else {
            Log.w(TAG, "Lock screen password verification failed")

            // Log failed attempt
            logSecurityEvent("lock_screen_password_failed", mapOf(
                "timestamp" to System.currentTimeMillis()
            ))

            // Notify Flutter about failed attempt (for photo capture)
            notifyFlutter("LOCK_SCREEN_PASSWORD_FAILED", mapOf(
                "timestamp" to System.currentTimeMillis()
            ))

            // Show error message
            mainHandler.post {
                Toast.makeText(
                    this,
                    "❌ كلمة المرور غير صحيحة",
                    Toast.LENGTH_SHORT
                ).show()
            }

            // Clear input
            lockScreenOverlayView?.findViewById<EditText>(R.id.unlock_password_input)?.setText("")
        }
    }

    /**
     * Hide lock screen message overlay
     */
    fun hideLockScreenMessage() {
        if (!isLockScreenOverlayShowing || lockScreenOverlayView == null) return

        try {
            windowManager?.removeView(lockScreenOverlayView)
            lockScreenOverlayView = null
            isLockScreenOverlayShowing = false
            currentLockScreenMessage = null
            currentOwnerContact = null
            Log.i(TAG, "Lock screen message overlay hidden")
            
            notifyFlutter("LOCK_SCREEN_MESSAGE_HIDDEN")
        } catch (e: Exception) {
            Log.e(TAG, "Error hiding lock screen overlay: ${e.message}")
        }
    }

    /**
     * Check if lock screen message is showing
     */
    fun isLockScreenMessageShowing(): Boolean = isLockScreenOverlayShowing
}
