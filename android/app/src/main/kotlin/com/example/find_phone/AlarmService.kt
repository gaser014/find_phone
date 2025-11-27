package com.example.find_phone

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Service for managing loud alarm sounds for anti-theft protection.
 * 
 * Features:
 * - Maximum volume alarm that ignores device volume settings
 * - Continuous playback until stopped
 * - 2-minute duration for remote ALARM command
 * - Vibration support
 * 
 * Requirements: 7.1, 7.2, 7.4, 7.5, 8.5
 */
class AlarmService private constructor(private val context: Context) {

    companion object {
        private const val TAG = "AlarmService"
        
        @Volatile
        private var instance: AlarmService? = null

        fun getInstance(context: Context): AlarmService {
            return instance ?: synchronized(this) {
                instance ?: AlarmService(context.applicationContext).also { instance = it }
            }
        }
    }

    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var vibrator: Vibrator? = null
    private var originalVolume: Int = 0
    private var isPlaying: Boolean = false
    private var alarmHandler: Handler? = null
    private var stopRunnable: Runnable? = null

    init {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibratorManager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        alarmHandler = Handler(Looper.getMainLooper())
    }

    /**
     * Trigger a loud alarm at maximum volume.
     * 
     * @param durationMs Duration in milliseconds (default: 2 minutes)
     * @param maxVolume If true, sets volume to maximum
     * @param ignoreVolumeSettings If true, overrides device volume settings
     * @return true if alarm started successfully
     * 
     * Requirements: 7.1, 7.4, 8.5
     */
    fun triggerAlarm(
        durationMs: Long = 120000L,
        maxVolume: Boolean = true,
        ignoreVolumeSettings: Boolean = true
    ): Boolean {
        return try {
            if (isPlaying) {
                Log.d(TAG, "Alarm already playing")
                return true
            }

            // Save original volume
            audioManager?.let { am ->
                originalVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
                
                // Set to maximum volume if requested
                if (maxVolume || ignoreVolumeSettings) {
                    val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    am.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)
                }
            }

            // Get alarm sound URI
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            // Create and configure MediaPlayer
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, alarmUri)
                isLooping = true
                prepare()
                start()
            }

            isPlaying = true

            // Start vibration pattern
            startVibration()

            // Schedule auto-stop after duration
            if (durationMs > 0) {
                stopRunnable = Runnable { stopAlarm() }
                alarmHandler?.postDelayed(stopRunnable!!, durationMs)
            }

            Log.d(TAG, "Alarm triggered for ${durationMs}ms")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering alarm: ${e.message}")
            false
        }
    }

    /**
     * Stop the currently playing alarm.
     * 
     * @return true if alarm stopped successfully
     * 
     * Requirement: 7.5
     */
    fun stopAlarm(): Boolean {
        return try {
            // Cancel scheduled stop
            stopRunnable?.let { alarmHandler?.removeCallbacks(it) }
            stopRunnable = null

            // Stop media player
            mediaPlayer?.let { mp ->
                if (mp.isPlaying) {
                    mp.stop()
                }
                mp.release()
            }
            mediaPlayer = null

            // Stop vibration
            stopVibration()

            // Restore original volume
            audioManager?.let { am ->
                am.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
            }

            isPlaying = false
            Log.d(TAG, "Alarm stopped")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping alarm: ${e.message}")
            isPlaying = false
            false
        }
    }

    /**
     * Check if an alarm is currently playing.
     */
    fun isAlarmPlaying(): Boolean {
        return isPlaying && (mediaPlayer?.isPlaying == true)
    }

    /**
     * Start vibration pattern for alarm.
     */
    private fun startVibration() {
        vibrator?.let { v ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Vibration pattern: vibrate 1s, pause 0.5s, repeat
                val pattern = longArrayOf(0, 1000, 500)
                v.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                val pattern = longArrayOf(0, 1000, 500)
                v.vibrate(pattern, 0)
            }
        }
    }

    /**
     * Stop vibration.
     */
    private fun stopVibration() {
        vibrator?.cancel()
    }

    /**
     * Check if audio permission is available.
     * Note: Audio playback doesn't require special permissions on Android.
     */
    fun hasAudioPermission(): Boolean {
        return true
    }

    /**
     * Set custom alarm sound.
     * 
     * @param soundPath Path to the alarm sound file
     */
    fun setAlarmSound(soundPath: String) {
        // Custom sound implementation - for future use
        Log.d(TAG, "Custom alarm sound set: $soundPath")
    }

    /**
     * Clean up resources.
     */
    fun dispose() {
        stopAlarm()
        alarmHandler = null
    }
}
