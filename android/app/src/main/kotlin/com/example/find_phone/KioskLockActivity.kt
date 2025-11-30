package com.example.find_phone

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.hardware.camera2.*
import android.media.AudioManager
import android.media.ImageReader
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.text.InputType
import android.util.Log
import android.util.Size
import android.view.Gravity
import android.view.KeyEvent
import android.view.Surface
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.*
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.UUID

/**
 * Full-screen Kiosk Lock Activity.
 * 
 * This activity:
 * - Shows only password entry field
 * - Blocks all system navigation (home, back, recent apps)
 * - Cannot be dismissed without correct password
 * - Enables mobile data on activation
 * - Blocks USB connections
 * 
 * Requirements:
 * - Full Kiosk Mode on screen lock
 * - Password-only unlock
 * - Block all other interactions
 */
class KioskLockActivity : Activity() {

    companion object {
        private const val TAG = "KioskLockActivity"
        const val PREFS_NAME = "kiosk_lock_prefs"
        const val KEY_TELEGRAM_BOT_TOKEN = "telegram_bot_token"
        const val KEY_TELEGRAM_CHAT_ID = "telegram_chat_id"
        const val KEY_EMERGENCY_PHONE = "emergency_phone"
        const val KEY_KIOSK_PASSWORD = "kiosk_password"
    }

    private lateinit var passwordInput: EditText
    private lateinit var unlockButton: Button
    private lateinit var errorText: TextView
    private lateinit var statusText: TextView
    private lateinit var mainLayout: LinearLayout
    private var capturedPhotoImageView: ImageView? = null
    private var warningTextView: TextView? = null
    private var failedAttempts = 0
    private var lastCapturedPhoto: ByteArray? = null
    
    private lateinit var audioManager: AudioManager
    
    // Dynamic settings
    private var telegramBotToken: String = ""
    private var telegramChatId: String = ""
    private var emergencyPhone: String = ""
    private var kioskPassword: String = "123456" // Default password
    
    // Alarm player for wrong password
    private var alarmPlayer: android.media.MediaPlayer? = null
    private var isAlarmPlaying = false
    private val volumeHandler = Handler(Looper.getMainLooper())
    private val volumeCheckRunnable = object : Runnable {
        override fun run() {
            forceMaxVolume()
            volumeHandler.postDelayed(this, 300) // Check every 300ms for faster response
        }
    }
    
    // Volume change listener to immediately restore max volume
    private val volumeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                forceMaxVolume()
            }
        }
    }

    private val commandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                "com.example.find_phone.KIOSK_UNLOCK" -> {
                    Log.i(TAG, "Received unlock command")
                    finishKiosk()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.i(TAG, "KioskLockActivity created")
        
        // Load Telegram settings
        loadTelegramSettings()
        
        // Initialize audio manager
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Setup window flags for full kiosk mode
        setupWindowFlags()
        
        // Create UI programmatically
        setupUI()
        
        // Register command receiver
        registerCommandReceiver()
        
        // Enable mobile data
        enableMobileData()
        
        // USB blocking disabled for now - causes issues with debugging
        // blockUsb()
        
        // Set max volume and keep it max
        forceMaxVolume()
        volumeHandler.post(volumeCheckRunnable)
        
        // Register volume change receiver
        registerVolumeReceiver()
        
        // Start lock task (Kiosk Mode)
        startKioskMode()
        
        // Log activation
        logSecurityEvent("kiosk_lock_activated", mapOf(
            "timestamp" to System.currentTimeMillis()
        ))
        
        // IMPORTANT: Capture photo and send alert immediately when screen opens
        capturePhotoAndSendAlert()
    }
    
    /**
     * Capture photo and send alert immediately when kiosk opens
     */
    private fun capturePhotoAndSendAlert() {
        Log.i(TAG, "📸 Capturing photo and sending alert on kiosk open...")
        
        // Wait a bit for camera to be ready, then capture
        mainHandler.postDelayed({
            captureAndSendPhoto()
        }, 1500)
        
        // Also send location alert
        sendEmergencyAlert()
    }
    
    /**
     * Load all settings from SharedPreferences
     */
    private fun loadTelegramSettings() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Load Telegram settings with defaults
        telegramBotToken = prefs.getString(KEY_TELEGRAM_BOT_TOKEN, null) 
            ?: "8574324828:AAHTPbf7yUNAG8VsndCIht8PYo_iwuc2d00"
        telegramChatId = prefs.getString(KEY_TELEGRAM_CHAT_ID, null) 
            ?: "7442106503"
        emergencyPhone = prefs.getString(KEY_EMERGENCY_PHONE, null) ?: ""
        
        // Load dynamic password (default: 123456)
        kioskPassword = prefs.getString(KEY_KIOSK_PASSWORD, null) ?: "123456"
        
        Log.i(TAG, "Settings loaded - Password: ${kioskPassword.take(2)}***, Bot Token: ${telegramBotToken.take(10)}..., Chat ID: $telegramChatId")
    }
    
    /**
     * Check if Telegram is configured
     */
    private fun isTelegramConfigured(): Boolean {
        return telegramBotToken.isNotEmpty() && telegramChatId.isNotEmpty()
    }
    
    /**
     * Check if device has internet connection
     */
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            return capabilities.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            return networkInfo?.isConnected == true
        }
    }

    /**
     * Setup window flags for full-screen kiosk mode
     */
    private fun setupWindowFlags() {
        // Show on lock screen and KEEP SCREEN ON to prevent turning off
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        
        // Keep screen on to prevent screen from turning off
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // IMPORTANT: Allow keyboard to work properly
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )
        
        // Set colors only - don't hide system UI (breaks keyboard)
        window.statusBarColor = Color.parseColor("#1A1A2E")
        window.navigationBarColor = Color.parseColor("#1A1A2E")
    }

    /**
     * Setup UI programmatically
     */
    private fun setupUI() {
        // ScrollView to handle keyboard
        val scrollView = ScrollView(this).apply {
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            isFillViewport = true
        }
        
        mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1A1A2E"))
            setPadding(48, 48, 48, 48)
        }

        // Lock icon
        val lockIcon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            setColorFilter(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(150, 150).apply {
                gravity = Gravity.CENTER
                bottomMargin = 32
            }
        }
        mainLayout.addView(lockIcon)

        // Title
        val titleText = TextView(this).apply {
            text = "🔒 الجهاز مقفل"
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 16
            }
        }
        mainLayout.addView(titleText)

        // Subtitle
        val subtitleText = TextView(this).apply {
            text = "أدخل كلمة المرور لفتح الجهاز"
            textSize = 16f
            setTextColor(Color.parseColor("#9E9E9E"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 32
            }
        }
        mainLayout.addView(subtitleText)

        // Password input - keyboard shows when focused
        passwordInput = EditText(this).apply {
            hint = "اضغط هنا لإدخال كلمة المرور"
            setHintTextColor(Color.parseColor("#888888"))
            setTextColor(Color.WHITE)
            textSize = 18f
            gravity = Gravity.CENTER
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            setBackgroundColor(Color.parseColor("#2A2A4E"))
            setPadding(32, 32, 32, 32)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 24
                leftMargin = 32
                rightMargin = 32
            }
            imeOptions = EditorInfo.IME_ACTION_DONE
            isFocusable = true
            isFocusableInTouchMode = true
            
            // Show keyboard when focused
            setOnFocusChangeListener { _, hasFocus ->
                if (hasFocus) {
                    postDelayed({
                        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
                        imm.showSoftInput(this, android.view.inputmethod.InputMethodManager.SHOW_FORCED)
                    }, 200)
                }
            }
            
            setOnEditorActionListener { _, actionId, _ ->
                if (actionId == EditorInfo.IME_ACTION_DONE) {
                    attemptUnlock()
                    true
                } else false
            }
        }
        mainLayout.addView(passwordInput)

        // Unlock button
        unlockButton = Button(this).apply {
            text = "فتح القفل"
            textSize = 18f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#1565C0"))
            setPadding(32, 20, 32, 20)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 24
                leftMargin = 32
                rightMargin = 32
            }
            setOnClickListener { 
                attemptUnlock() 
            }
        }
        mainLayout.addView(unlockButton)

        // Error text
        errorText = TextView(this).apply {
            text = ""
            textSize = 14f
            setTextColor(Color.parseColor("#EF5350"))
            gravity = Gravity.CENTER
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 16
            }
        }
        mainLayout.addView(errorText)

        // Status text (tracking info)
        statusText = TextView(this).apply {
            text = "⚠️ هذا التطبيق للحماية من السرقة\nيتم تتبع الموقع وتسجيل المحاولات"
            textSize = 12f
            setTextColor(Color.parseColor("#FFA726"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 32
            }
        }
        mainLayout.addView(statusText)

        scrollView.addView(mainLayout)
        setContentView(scrollView)
    }
    
    /**
     * Show keyboard
     */
    private fun showKeyboard() {
        passwordInput.requestFocus()
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
        imm.showSoftInput(passwordInput, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
    }
    
    /**
     * Hide keyboard
     */
    private fun hideKeyboard() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
        imm.hideSoftInputFromWindow(passwordInput.windowToken, 0)
    }
    
    // Container for warning UI
    private var warningContainer: LinearLayout? = null
    
    /**
     * Show captured photo with warning message to the thief
     */
    private fun showCapturedPhotoWarning(photoBytes: ByteArray) {
        lastCapturedPhoto = photoBytes
        
        mainHandler.post {
            try {
                // Remove previous warning container if exists
                warningContainer?.let { mainLayout.removeView(it) }
                
                // Create warning container with red background
                warningContainer = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    setBackgroundColor(Color.parseColor("#D32F2F"))
                    setPadding(32, 32, 32, 32)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 24
                        leftMargin = 16
                        rightMargin = 16
                    }
                }
                
                // Big warning icon and title
                val warningTitle = TextView(this).apply {
                    text = "🚨 تحذير! 🚨"
                    textSize = 24f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = 16
                    }
                }
                warningContainer?.addView(warningTitle)
                
                // Decode and show photo
                val bitmap = BitmapFactory.decodeByteArray(photoBytes, 0, photoBytes.size)
                if (bitmap != null) {
                    capturedPhotoImageView = ImageView(this).apply {
                        setImageBitmap(bitmap)
                        layoutParams = LinearLayout.LayoutParams(350, 350).apply {
                            gravity = Gravity.CENTER
                            bottomMargin = 16
                        }
                        scaleType = ImageView.ScaleType.CENTER_CROP
                        // Add border
                        setBackgroundColor(Color.WHITE)
                        setPadding(4, 4, 4, 4)
                    }
                    warningContainer?.addView(capturedPhotoImageView)
                }
                
                // Photo captured text
                val photoText = TextView(this).apply {
                    text = "📸 تم التقاط صورتك!"
                    textSize = 20f
                    setTextColor(Color.YELLOW)
                    gravity = Gravity.CENTER
                    setTypeface(null, android.graphics.Typeface.BOLD)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = 12
                    }
                }
                warningContainer?.addView(photoText)
                
                // Location text
                val locationText = TextView(this).apply {
                    text = "📍 تم تحديد موقعك بدقة!"
                    textSize = 18f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = 8
                    }
                }
                warningContainer?.addView(locationText)
                
                // Telegram sent text - ALWAYS show as sent (psychological effect)
                val telegramText = TextView(this).apply {
                    text = "✅ تم إرسال صورتك وموقعك للمالك عبر التيليجرام"
                    textSize = 16f
                    setTextColor(Color.parseColor("#90EE90")) // Light green
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = 16
                    }
                }
                warningContainer?.addView(telegramText)
                
                // Separator
                val separator = View(this).apply {
                    setBackgroundColor(Color.WHITE)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        2
                    ).apply {
                        topMargin = 8
                        bottomMargin = 16
                    }
                }
                warningContainer?.addView(separator)
                
                // Return phone warning
                val returnText = TextView(this).apply {
                    text = "⚠️ أعد الهاتف لصاحبه فوراً!\nهذا أفضل لك قبل اتخاذ إجراءات قانونية"
                    textSize = 16f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        bottomMargin = 12
                    }
                }
                warningContainer?.addView(returnText)
                
                // Contact number if available
                if (emergencyPhone.isNotEmpty()) {
                    val contactText = TextView(this).apply {
                        text = "📞 للتواصل وإرجاع الهاتف:\n$emergencyPhone"
                        textSize = 18f
                        setTextColor(Color.YELLOW)
                        gravity = Gravity.CENTER
                        setTypeface(null, android.graphics.Typeface.BOLD)
                        layoutParams = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.WRAP_CONTENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            topMargin = 8
                        }
                    }
                    warningContainer?.addView(contactText)
                }
                
                // Add to main layout
                mainLayout.addView(warningContainer)
                
                Log.i(TAG, "Warning UI shown to thief with photo")
                
            } catch (e: Exception) {
                Log.e(TAG, "Error showing warning: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    /**
     * Attempt to unlock with entered password
     */
    private fun attemptUnlock() {
        val password = passwordInput.text.toString()
        
        if (password.isEmpty()) {
            showError("الرجاء إدخال كلمة المرور")
            return
        }

        // Verify password
        if (verifyPassword(password)) {
            Log.i(TAG, "Password verified - unlocking")
            // Stop alarm if playing
            stopAlarm()
            finishKiosk()
        } else {
            failedAttempts++
            showError("كلمة المرور غير صحيحة (${failedAttempts})")
            passwordInput.text.clear()
            
            // Log failed attempt
            logSecurityEvent("kiosk_password_failed", mapOf(
                "failed_attempts" to failedAttempts,
                "timestamp" to System.currentTimeMillis()
            ))
            
            // Capture photo with front camera and send to Telegram
            captureAndSendPhoto()
            
            // Start loud alarm on FIRST wrong password - won't stop until correct password
            startLoudAlarm()
            
            // Send alert with location to Telegram
            sendEmergencyAlert()
        }
    }
    
    // Camera variables
    private var cameraDevice: CameraDevice? = null
    private var cameraCaptureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var cameraHandler: Handler? = null
    private var cameraThread: HandlerThread? = null
    private var isCameraCapturing = false
    
    /**
     * Capture photo with front camera and send to Telegram
     */
    private fun captureAndSendPhoto() {
        if (isCameraCapturing) {
            Log.w(TAG, "Camera capture already in progress")
            return
        }
        
        isCameraCapturing = true
        Log.i(TAG, "Starting front camera capture...")
        
        // Start camera thread
        cameraThread = HandlerThread("CameraThread").apply { start() }
        cameraHandler = Handler(cameraThread!!.looper)
        
        cameraHandler?.post {
            try {
                val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                
                // Find front camera
                var frontCameraId: String? = null
                for (cameraId in cameraManager.cameraIdList) {
                    val characteristics = cameraManager.getCameraCharacteristics(cameraId)
                    val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                    if (facing == CameraCharacteristics.LENS_FACING_FRONT) {
                        frontCameraId = cameraId
                        break
                    }
                }
                
                if (frontCameraId == null) {
                    Log.e(TAG, "No front camera found")
                    isCameraCapturing = false
                    return@post
                }
                
                Log.i(TAG, "Front camera found: $frontCameraId")
                
                // Get camera characteristics
                val characteristics = cameraManager.getCameraCharacteristics(frontCameraId)
                val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                
                // Get optimal size
                val outputSizes = map?.getOutputSizes(ImageFormat.JPEG)
                val imageSize = outputSizes?.firstOrNull { it.width <= 1280 && it.height <= 960 }
                    ?: outputSizes?.lastOrNull()
                    ?: Size(640, 480)
                
                Log.i(TAG, "Using image size: ${imageSize.width}x${imageSize.height}")
                
                // Create ImageReader
                imageReader = ImageReader.newInstance(
                    imageSize.width,
                    imageSize.height,
                    ImageFormat.JPEG,
                    2
                )
                
                imageReader?.setOnImageAvailableListener({ reader ->
                    val image = reader.acquireLatestImage()
                    if (image != null) {
                        try {
                            val buffer = image.planes[0].buffer
                            val bytes = ByteArray(buffer.remaining())
                            buffer.get(bytes)
                            
                            Log.i(TAG, "Photo captured! Size: ${bytes.size} bytes")
                            
                            // Send to Telegram in background
                            Thread {
                                sendPhotoToTelegram(bytes)
                            }.start()
                            
                        } finally {
                            image.close()
                            closeCamera()
                        }
                    }
                }, cameraHandler)
                
                // Check camera permission
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (checkSelfPermission(android.Manifest.permission.CAMERA) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                        Log.e(TAG, "Camera permission not granted")
                        isCameraCapturing = false
                        return@post
                    }
                }
                
                // Open camera
                cameraManager.openCamera(frontCameraId, object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        Log.i(TAG, "Camera opened")
                        cameraDevice = camera
                        createCaptureSession()
                    }
                    
                    override fun onDisconnected(camera: CameraDevice) {
                        Log.w(TAG, "Camera disconnected")
                        closeCamera()
                    }
                    
                    override fun onError(camera: CameraDevice, error: Int) {
                        Log.e(TAG, "Camera error: $error")
                        closeCamera()
                    }
                }, cameraHandler)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error capturing photo: ${e.message}")
                e.printStackTrace()
                isCameraCapturing = false
            }
        }
    }
    
    /**
     * Create capture session
     */
    private fun createCaptureSession() {
        try {
            val surface = imageReader?.surface ?: return
            
            cameraDevice?.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        Log.i(TAG, "Capture session configured")
                        cameraCaptureSession = session
                        
                        // Wait a bit for camera to warm up, then capture
                        cameraHandler?.postDelayed({
                            captureImage()
                        }, 500)
                    }
                    
                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Capture session configuration failed")
                        closeCamera()
                    }
                },
                cameraHandler
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating capture session: ${e.message}")
            closeCamera()
        }
    }
    
    /**
     * Capture image
     */
    private fun captureImage() {
        try {
            val surface = imageReader?.surface ?: return
            
            val captureBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder?.addTarget(surface)
            
            // Auto settings
            captureBuilder?.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
            captureBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            captureBuilder?.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            
            cameraCaptureSession?.capture(
                captureBuilder!!.build(),
                object : CameraCaptureSession.CaptureCallback() {
                    override fun onCaptureCompleted(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        result: TotalCaptureResult
                    ) {
                        Log.i(TAG, "Capture completed")
                    }
                    
                    override fun onCaptureFailed(
                        session: CameraCaptureSession,
                        request: CaptureRequest,
                        failure: CaptureFailure
                    ) {
                        Log.e(TAG, "Capture failed: ${failure.reason}")
                        closeCamera()
                    }
                },
                cameraHandler
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing image: ${e.message}")
            closeCamera()
        }
    }
    
    /**
     * Close camera resources
     */
    private fun closeCamera() {
        try {
            cameraCaptureSession?.close()
            cameraCaptureSession = null
            
            cameraDevice?.close()
            cameraDevice = null
            
            imageReader?.close()
            imageReader = null
            
            cameraThread?.quitSafely()
            cameraThread = null
            cameraHandler = null
            
            isCameraCapturing = false
            Log.i(TAG, "Camera closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing camera: ${e.message}")
        }
    }
    
    /**
     * Send photo to Telegram
     */
    private fun sendPhotoToTelegram(photoBytes: ByteArray) {
        // Show warning to thief first
        showCapturedPhotoWarning(photoBytes)
        
        // Check if Telegram is configured
        if (!isTelegramConfigured()) {
            Log.w(TAG, "Telegram not configured - skipping photo send")
            return
        }
        
        // Check network
        if (!isNetworkAvailable()) {
            Log.w(TAG, "No network available - will retry later")
            // Save photo for later sending
            savePhotoForLater(photoBytes)
            return
        }
        
        try {
            Log.i(TAG, "Sending photo to Telegram chat: $telegramChatId")
            
            val timeStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            val location = getCurrentLocation()
            val locationStr = if (location != null) {
                "📍 الموقع: https://maps.google.com/?q=${location.latitude},${location.longitude}"
            } else {
                "📍 الموقع: جاري التحديد..."
            }
            
            val caption = """
🚨 تنبيه أمني!
⏰ $timeStr
$locationStr
❌ محاولات فاشلة: $failedAttempts
${if (emergencyPhone.isNotEmpty()) "📞 للتواصل: $emergencyPhone" else ""}
            """.trimIndent()
            
            val boundary = "----${UUID.randomUUID()}"
            val url = URL("https://api.telegram.org/bot${telegramBotToken}/sendPhoto")
            
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            
            val outputStream = DataOutputStream(connection.outputStream)
            
            // Add chat_id
            outputStream.writeBytes("--$boundary\r\n")
            outputStream.writeBytes("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n")
            outputStream.writeBytes("$telegramChatId\r\n")
            
            // Add caption
            outputStream.writeBytes("--$boundary\r\n")
            outputStream.writeBytes("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
            outputStream.write(caption.toByteArray(Charsets.UTF_8))
            outputStream.writeBytes("\r\n")
            
            // Add photo
            outputStream.writeBytes("--$boundary\r\n")
            outputStream.writeBytes("Content-Disposition: form-data; name=\"photo\"; filename=\"security_photo.jpg\"\r\n")
            outputStream.writeBytes("Content-Type: image/jpeg\r\n\r\n")
            outputStream.write(photoBytes)
            outputStream.writeBytes("\r\n")
            
            // End boundary
            outputStream.writeBytes("--$boundary--\r\n")
            outputStream.flush()
            outputStream.close()
            
            val responseCode = connection.responseCode
            Log.i(TAG, "Telegram photo response: $responseCode")
            
            if (responseCode == 200) {
                Log.i(TAG, "✅ Photo sent to Telegram successfully!")
                // Update warning UI
                updateWarningStatus(true)
            } else {
                val error = connection.errorStream?.bufferedReader()?.readText()
                Log.e(TAG, "Telegram photo error: $error")
                updateWarningStatus(false)
            }
            
            connection.disconnect()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error sending photo to Telegram: ${e.message}")
            e.printStackTrace()
            updateWarningStatus(false)
        }
    }
    
    /**
     * Save photo for later sending when network is available
     */
    private fun savePhotoForLater(photoBytes: ByteArray) {
        try {
            val file = java.io.File(filesDir, "pending_photo_${System.currentTimeMillis()}.jpg")
            file.writeBytes(photoBytes)
            Log.i(TAG, "Photo saved for later: ${file.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Error saving photo: ${e.message}")
        }
    }
    
    /**
     * Update warning status after send attempt
     */
    private fun updateWarningStatus(success: Boolean) {
        mainHandler.post {
            warningTextView?.let {
                val status = if (success) "✅ تم إرسال الصورة والموقع بنجاح!" else "⚠️ فشل الإرسال - سيتم المحاولة مرة أخرى"
                it.text = """
📍 تم تحديد موقعك
📸 $status

🚨 أعد الهاتف لصاحبه!
${if (emergencyPhone.isNotEmpty()) "📞 للتواصل: $emergencyPhone" else ""}
                """.trimIndent()
            }
        }
    }

    /**
     * Verify password - uses dynamic password from settings
     */
    private fun verifyPassword(password: String): Boolean {
        // First check dynamic kiosk password
        if (password == kioskPassword) {
            Log.i(TAG, "Password verified using dynamic kiosk password")
            return true
        }
        
        // Fallback: check stored hash from accessibility service
        val prefs = getSharedPreferences(
            AntiTheftAccessibilityService.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        val storedHash = prefs.getString(AntiTheftAccessibilityService.KEY_PASSWORD_HASH, null)
        val storedSalt = prefs.getString(AntiTheftAccessibilityService.KEY_PASSWORD_SALT, null)
        
        if (storedHash != null && storedSalt != null) {
            val inputHash = hashPassword(password, storedSalt)
            if (inputHash == storedHash) {
                Log.i(TAG, "Password verified using stored hash")
                return true
            }
        }
        
        return false
    }

    /**
     * Hash password with salt using SHA-256
     */
    private fun hashPassword(password: String, salt: String): String {
        val combined = password + salt
        val digest = MessageDigest.getInstance("SHA-256")
        val hashBytes = digest.digest(combined.toByteArray())
        return hashBytes.joinToString("") { "%02x".format(it) }
    }

    /**
     * Show error message
     */
    private fun showError(message: String) {
        errorText.text = message
        errorText.visibility = View.VISIBLE
    }

    /**
     * Start Kiosk Mode (Lock Task)
     */
    private fun startKioskMode() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
                Log.i(TAG, "Lock task started")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting lock task: ${e.message}")
            // Fallback: use accessibility service to block other apps
            enableAccessibilityBlocking()
        }
    }
    
    /**
     * Enable blocking via Accessibility Service
     */
    private fun enableAccessibilityBlocking() {
        val intent = Intent("com.example.find_phone.ACCESSIBILITY_COMMAND")
        intent.putExtra("command", "ENABLE_KIOSK_BLOCKING")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Finish Kiosk Mode and close activity
     */
    private fun finishKiosk() {
        try {
            // Clear kiosk pending state
            val prefs = getSharedPreferences(ScreenLockReceiver.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean("kiosk_pending", false).apply()
            
            // Stop lock task
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
            }
            
            // Log unlock
            logSecurityEvent("kiosk_unlocked", mapOf(
                "failed_attempts" to failedAttempts,
                "timestamp" to System.currentTimeMillis()
            ))
            
            // Notify Flutter
            val intent = Intent("com.example.find_phone.KIOSK_EVENT")
            intent.putExtra("action", "KIOSK_UNLOCKED")
            intent.putExtra("timestamp", System.currentTimeMillis())
            intent.setPackage(packageName)
            sendBroadcast(intent)
            
            finish()
        } catch (e: Exception) {
            Log.e(TAG, "Error finishing kiosk: ${e.message}")
            finish()
        }
    }

    /**
     * Enable mobile data
     */
    private fun enableMobileData() {
        val intent = Intent("com.example.find_phone.DATA_COMMAND")
        intent.putExtra("command", "ENABLE_MOBILE_DATA")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Block USB connections
     */
    private fun blockUsb() {
        val intent = Intent("com.example.find_phone.USB_COMMAND")
        intent.putExtra("command", "BLOCK_USB")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Capture photo
     */
    private fun capturePhoto(reason: String) {
        val intent = Intent("com.example.find_phone.CAPTURE_PHOTO")
        intent.putExtra("reason", reason)
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Trigger alarm (legacy - kept for compatibility)
     */
    private fun triggerAlarm() {
        startLoudAlarm()
    }
    
    /**
     * Start loud alarm that won't stop until correct password
     */
    private fun startLoudAlarm() {
        if (isAlarmPlaying) return
        
        try {
            // Set volume to max
            forceMaxVolume()
            
            // Create alarm sound using system alarm
            alarmPlayer = android.media.MediaPlayer().apply {
                setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                
                // Use system alarm sound
                val alarmUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                    ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE)
                    ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
                
                setDataSource(this@KioskLockActivity, alarmUri)
                isLooping = true // Keep playing until stopped
                prepare()
                start()
            }
            
            isAlarmPlaying = true
            Log.i(TAG, "Loud alarm started - will not stop until correct password")
            
            // Keep volume at max while alarm is playing
            volumeHandler.post(object : Runnable {
                override fun run() {
                    if (isAlarmPlaying) {
                        forceMaxVolume()
                        volumeHandler.postDelayed(this, 100)
                    }
                }
            })
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting alarm: ${e.message}")
            // Fallback: use ToneGenerator
            try {
                val toneGenerator = android.media.ToneGenerator(AudioManager.STREAM_ALARM, 100)
                toneGenerator.startTone(android.media.ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, -1)
            } catch (e2: Exception) {
                Log.e(TAG, "Error with ToneGenerator: ${e2.message}")
            }
        }
    }
    
    /**
     * Stop the alarm
     */
    private fun stopAlarm() {
        try {
            alarmPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            alarmPlayer = null
            isAlarmPlaying = false
            Log.i(TAG, "Alarm stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm: ${e.message}")
        }
    }

    /**
     * Log security event
     */
    private fun logSecurityEvent(eventType: String, metadata: Map<String, Any>) {
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
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }

    /**
     * Register command receiver
     */
    private fun registerCommandReceiver() {
        val filter = IntentFilter().apply {
            addAction("com.example.find_phone.KIOSK_UNLOCK")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(commandReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(commandReceiver, filter)
        }
    }

    // Block back button
    override fun onBackPressed() {
        // Do nothing - block back button
        Log.d(TAG, "Back button blocked")
    }

    // Power button tracking for long press detection
    private var powerButtonDownTime: Long = 0
    private var powerButtonLongPressHandled = false
    private val LONG_PRESS_THRESHOLD = 800L // 800ms for long press
    
    // Block key events including volume and power
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_POWER -> {
                Log.d(TAG, "🔴 Power button DOWN - capturing photo!")
                
                // Capture photo on ANY power button press (not just long press)
                if (powerButtonDownTime == 0L) {
                    powerButtonDownTime = System.currentTimeMillis()
                    powerButtonLongPressHandled = false
                    
                    // Capture photo immediately on power button press
                    captureAndSendPhoto()
                    sendEmergencyAlert()
                }
                true
            }
            KeyEvent.KEYCODE_HOME,
            KeyEvent.KEYCODE_APP_SWITCH,
            KeyEvent.KEYCODE_MENU,
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_MUTE,
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                Log.d(TAG, "Key blocked: $keyCode")
                // Keep volume at max immediately
                forceMaxVolume()
                true
            }
            else -> super.onKeyDown(keyCode, event)
        }
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_POWER -> {
                Log.d(TAG, "Power button UP")
                val pressDuration = System.currentTimeMillis() - powerButtonDownTime
                powerButtonDownTime = 0
                
                // If it was a long press and not handled yet, handle it now
                if (pressDuration >= LONG_PRESS_THRESHOLD && !powerButtonLongPressHandled) {
                    Log.i(TAG, "🔴 Power button LONG PRESS on release! Capturing photo...")
                    captureAndSendPhoto()
                    sendEmergencyAlert()
                }
                true
            }
            KeyEvent.KEYCODE_VOLUME_UP,
            KeyEvent.KEYCODE_VOLUME_DOWN,
            KeyEvent.KEYCODE_VOLUME_MUTE -> {
                forceMaxVolume()
                true
            }
            else -> super.onKeyUp(keyCode, event)
        }
    }
    
    override fun onKeyLongPress(keyCode: Int, event: KeyEvent?): Boolean {
        // Block long press on power button and capture photo
        if (keyCode == KeyEvent.KEYCODE_POWER) {
            Log.d(TAG, "Power long press callback - capturing photo!")
            if (!powerButtonLongPressHandled) {
                powerButtonLongPressHandled = true
                captureAndSendPhoto()
                sendEmergencyAlert()
            }
            return true
        }
        return super.onKeyLongPress(keyCode, event)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Just keep screen on - don't do anything else
        if (hasFocus) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun onPause() {
        super.onPause()
        // Don't restart - let ScreenLockReceiver handle it
        Log.d(TAG, "onPause called")
    }
    
    override fun onStop() {
        super.onStop()
        Log.d(TAG, "onStop called")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy called")
        volumeHandler.removeCallbacks(volumeCheckRunnable)
        try {
            unregisterReceiver(commandReceiver)
        } catch (e: Exception) {
            // Ignore
        }
        try {
            unregisterReceiver(volumeReceiver)
        } catch (e: Exception) {
            // Ignore
        }
        // Close camera resources
        closeCamera()
    }
    

    
    /**
     * Force volume to maximum for all streams
     */
    private fun forceMaxVolume() {
        try {
            // Set all audio streams to maximum
            val streams = listOf(
                AudioManager.STREAM_RING,
                AudioManager.STREAM_MUSIC,
                AudioManager.STREAM_ALARM,
                AudioManager.STREAM_NOTIFICATION,
                AudioManager.STREAM_SYSTEM,
                AudioManager.STREAM_VOICE_CALL
            )
            
            for (stream in streams) {
                val maxVolume = audioManager.getStreamMaxVolume(stream)
                val currentVolume = audioManager.getStreamVolume(stream)
                if (currentVolume < maxVolume) {
                    audioManager.setStreamVolume(stream, maxVolume, 0)
                }
            }
            
            // Disable mute and DND
            audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting max volume: ${e.message}")
        }
    }
    
    /**
     * Register volume change receiver
     */
    private fun registerVolumeReceiver() {
        val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(volumeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(volumeReceiver, filter)
        }
    }
    
    /**
     * Send emergency alert via Telegram Bot API
     * This works in background without opening any app
     */
    private fun sendEmergencyAlert() {
        // Check if Telegram is configured
        if (!isTelegramConfigured()) {
            Log.w(TAG, "Telegram not configured - skipping emergency alert")
            return
        }
        
        Thread {
            try {
                // Wait for mobile data to be enabled
                Thread.sleep(3000)
                
                // Check network
                if (!isNetworkAvailable()) {
                    Log.w(TAG, "No network available for emergency alert")
                    return@Thread
                }
                
                Log.i(TAG, "Sending Telegram alert to chat ID: $telegramChatId")
                
                // Get current location
                val location = getCurrentLocation()
                Log.i(TAG, "Location: $location")
                
                // Send message via Telegram Bot API
                sendTelegramMessage(location)
                
                // Also send location if available
                if (location != null) {
                    Thread.sleep(500)
                    sendTelegramLocation(location)
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error sending emergency alert: ${e.message}")
                e.printStackTrace()
            }
        }.start()
    }
    
    /**
     * Send message via Telegram Bot API
     */
    private fun sendTelegramMessage(location: android.location.Location?) {
        if (!isTelegramConfigured()) return
        
        try {
            val timeStr = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
            
            val locationStr = if (location != null) {
                "📍 الموقع: https://maps.google.com/?q=${location.latitude},${location.longitude}"
            } else {
                "📍 الموقع: غير متاح"
            }
            
            val message = """
🚨 *تنبيه سرقة!*
━━━━━━━━━━━━━━
⏰ الوقت: $timeStr
$locationStr
❌ محاولات فاشلة: $failedAttempts
${if (emergencyPhone.isNotEmpty()) "📞 للتواصل: $emergencyPhone" else ""}
━━━━━━━━━━━━━━
⚠️ الجهاز في وضع الحماية
            """.trimIndent()
            
            val encodedMessage = java.net.URLEncoder.encode(message, "UTF-8")
            val url = "https://api.telegram.org/bot${telegramBotToken}/sendMessage?chat_id=$telegramChatId&text=$encodedMessage&parse_mode=Markdown"
            
            val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val responseCode = connection.responseCode
            Log.i(TAG, "Telegram message sent, response code: $responseCode")
            
            if (responseCode == 200) {
                Log.i(TAG, "Telegram message sent successfully to $telegramChatId")
            } else {
                val error = connection.errorStream?.bufferedReader()?.readText()
                Log.e(TAG, "Telegram error: $error")
            }
            
            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error sending Telegram message: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * Send location via Telegram Bot API
     */
    private fun sendTelegramLocation(location: android.location.Location) {
        if (!isTelegramConfigured()) return
        
        try {
            val url = "https://api.telegram.org/bot${telegramBotToken}/sendLocation?chat_id=$telegramChatId&latitude=${location.latitude}&longitude=${location.longitude}"
            
            val connection = java.net.URL(url).openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            
            val responseCode = connection.responseCode
            Log.i(TAG, "Telegram location sent, response code: $responseCode")
            
            connection.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error sending Telegram location: ${e.message}")
        }
    }
    
    /**
     * Get current location - simple version
     */
    private fun getCurrentLocation(): android.location.Location? {
        return try {
            val locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
            
            // Check permission
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    Log.w(TAG, "Location permission not granted")
                    return null
                }
            }
            
            // Try GPS first
            var location = locationManager.getLastKnownLocation(android.location.LocationManager.GPS_PROVIDER)
            
            // Fallback to network
            if (location == null) {
                location = locationManager.getLastKnownLocation(android.location.LocationManager.NETWORK_PROVIDER)
            }
            
            // Fallback to passive
            if (location == null) {
                location = locationManager.getLastKnownLocation(android.location.LocationManager.PASSIVE_PROVIDER)
            }
            
            location
        } catch (e: Exception) {
            Log.e(TAG, "Error getting location: ${e.message}")
            null
        }
    }
    

    
    // Handler for main thread operations
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * Override dispatchKeyEvent to block power button
     */
    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        if (event?.keyCode == KeyEvent.KEYCODE_POWER) {
            Log.d(TAG, "Power button blocked")
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
