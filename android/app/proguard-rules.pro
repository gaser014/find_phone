# ProGuard rules for Anti-Theft Protection App
# Requirement 22.1: Implement code obfuscation for release build

# Google Play Core (required for Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }

# Keep our app's main classes
-keep class com.example.find_phone.MainActivity { *; }

# Keep Device Admin Receiver (required for Device Admin functionality)
-keep class com.example.find_phone.DeviceAdminReceiver { *; }
-keep class com.example.find_phone.DeviceAdminService { *; }

# Keep Accessibility Service (required for accessibility functionality)
-keep class com.example.find_phone.AntiTheftAccessibilityService { *; }

# Keep Boot Receiver (required for boot completed functionality)
-keep class com.example.find_phone.BootCompletedReceiver { *; }

# Keep SMS Receiver (required for SMS functionality)
-keep class com.example.find_phone.SmsReceiver { *; }

# Keep Foreground Service
-keep class com.example.find_phone.ProtectionForegroundService { *; }

# Keep Auto-Restart Job Service
-keep class com.example.find_phone.AutoRestartJobService { *; }

# Keep Alarm Service
-keep class com.example.find_phone.AlarmService { *; }

# Keep USB Service
-keep class com.example.find_phone.UsbService { *; }

# Keep WhatsApp Service
-keep class com.example.find_phone.WhatsAppService { *; }

# Keep Notification Service
-keep class com.example.find_phone.NotificationService { *; }

# Keep Dialer Code Receiver
-keep class com.example.find_phone.DialerCodeReceiver { *; }

# Keep all native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep R8 full mode compatibility
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# SQLCipher rules
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Geolocator rules
-keep class com.baseflow.geolocator.** { *; }

# Camera rules
-keep class io.flutter.plugins.camera.** { *; }

# WorkManager rules
-keep class androidx.work.** { *; }

# Crypto rules
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Telephony rules
-keep class com.shounakmulay.telephony.** { *; }

# Permission handler rules
-keep class com.baseflow.permissionhandler.** { *; }

# Secure storage rules
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Shared preferences rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Path provider rules
-keep class io.flutter.plugins.pathprovider.** { *; }

# Google Maps rules
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# Audio recording rules
-keep class com.llfbandit.record.** { *; }

# Just Audio rules
-keep class com.ryanheise.just_audio.** { *; }

# Obfuscate everything else
-repackageclasses 'a'
-allowaccessmodification
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Remove debug prints
-assumenosideeffects class kotlin.io.ConsoleKt {
    public static void println(...);
    public static void print(...);
}
