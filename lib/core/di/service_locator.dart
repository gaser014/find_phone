import 'package:get_it/get_it.dart';

import '../../services/accessibility/accessibility.dart';
import '../../services/alarm/alarm.dart';
import '../../services/alert/alert.dart';
import '../../services/app_blocking/app_blocking.dart';
import '../../services/audio_recording/audio_recording.dart';
import '../../services/authentication/authentication.dart';
import '../../services/backup/backup.dart';
import '../../services/boot/boot.dart';
import '../../services/camera/camera.dart';
import '../../services/cloud_upload/cloud_upload.dart';
import '../../services/daily_report/daily_report.dart';
import '../../services/device_admin/device_admin.dart';
import '../../services/location/location.dart';
import '../../services/monitoring/monitoring.dart';
import '../../services/protection/protection.dart';
import '../../services/remote_command/remote_command.dart';
import '../../services/security_log/security_log.dart';
import '../../services/sms/sms.dart';
import '../../services/storage/storage.dart';
import '../../services/test_mode/test_mode.dart';
import '../../services/usb/usb.dart';
import '../../services/battery/battery.dart';
import '../../services/foreground/foreground.dart';
import '../../services/whatsapp/whatsapp.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Initialize all services with dependency injection.
///
/// This function sets up all services in the correct order,
/// respecting their dependencies.
///
/// Requirements: All - Wire all services together with dependency injection
Future<void> setupServiceLocator() async {
  // ==================== Core Services ====================
  // These services have no dependencies on other services

  // Storage Service - Foundation for all persistent data
  sl.registerLazySingleton<StorageService>(() => StorageService());
  sl.registerLazySingleton<IStorageService>(() => sl<StorageService>());

  // Initialize storage
  await sl<StorageService>().init();

  // ==================== Security Services ====================

  // Authentication Service - Depends on Storage
  sl.registerLazySingleton<IAuthenticationService>(
    () => AuthenticationService(storageService: sl<IStorageService>()),
  );

  // Security Log Service
  sl.registerLazySingleton<ISecurityLogService>(() => SecurityLogService());

  // ==================== Platform Services ====================

  // Device Admin Service - Native Android service (singleton)
  sl.registerLazySingleton<IDeviceAdminService>(() => DeviceAdminService.instance);

  // Accessibility Service - Native Android service (singleton)
  sl.registerLazySingleton<IAccessibilityService>(() => AccessibilityService.instance);

  // Boot Service - Native Android service
  sl.registerLazySingleton<IBootService>(() => BootService());

  // Foreground Service - Native Android service (singleton)
  sl.registerLazySingleton<IForegroundService>(() => ForegroundService.instance);

  // Battery Service - Native Android service (singleton)
  sl.registerLazySingleton<IBatteryService>(() => BatteryService.instance);

  // ==================== Feature Services ====================

  // Location Service - No dependencies (uses SharedPreferences internally)
  sl.registerLazySingleton<ILocationService>(() => LocationService());

  // Camera Service - Depends on Storage
  sl.registerLazySingleton<ICameraService>(
    () => CameraService(storageService: sl<IStorageService>()),
  );

  // Alarm Service (singleton)
  sl.registerLazySingleton<IAlarmService>(() => AlarmService.instance);

  // SMS Service - Depends on Storage, Auth, Security Log
  sl.registerLazySingleton<ISmsService>(
    () => SmsService(
      storageService: sl<IStorageService>(),
      authenticationService: sl<IAuthenticationService>(),
      securityLogService: sl<ISecurityLogService>(),
    ),
  );

  // USB Service - Depends on Storage
  sl.registerLazySingleton<IUsbService>(
    () => UsbService(storageService: sl<IStorageService>()),
  );

  // WhatsApp Service - Depends on Storage, Location
  sl.registerLazySingleton<IWhatsAppService>(
    () => WhatsAppService(
      storageService: sl<IStorageService>(),
      locationService: sl<ILocationService>(),
    ),
  );

  // Audio Recording Service - Depends on Storage
  sl.registerLazySingleton<IAudioRecordingService>(
    () => AudioRecordingService(storageService: sl<IStorageService>()),
  );

  // Cloud Upload Service - Depends on Storage, Camera, SMS, WhatsApp
  sl.registerLazySingleton<ICloudUploadService>(
    () => CloudUploadService(
      storageService: sl<IStorageService>(),
      cameraService: sl<ICameraService>(),
      smsService: sl<ISmsService>(),
      whatsAppService: sl<IWhatsAppService>(),
    ),
  );

  // ==================== Composite Services ====================

  // Alert Service - Depends on SMS, Camera, Location, Security Log
  sl.registerLazySingleton<IAlertService>(
    () => AlertService(
      smsService: sl<ISmsService>(),
      cameraService: sl<ICameraService>(),
      locationService: sl<ILocationService>(),
      securityLogService: sl<ISecurityLogService>(),
      storageService: sl<IStorageService>(),
    ),
  );

  // Monitoring Service - Depends on Storage, Security Log
  sl.registerLazySingleton<IMonitoringService>(
    () => MonitoringService(
      storageService: sl<IStorageService>(),
      securityLogService: sl<ISecurityLogService>(),
    ),
  );

  // App Blocking Service - Depends on Storage, Accessibility
  sl.registerLazySingleton<IAppBlockingService>(
    () => AppBlockingService(
      storageService: sl<IStorageService>(),
      accessibilityService: sl<IAccessibilityService>(),
    ),
  );

  // Protection Service - Depends on Storage, Auth, Accessibility, Device Admin, Boot
  sl.registerLazySingleton<IProtectionService>(
    () => ProtectionService(
      storageService: sl<IStorageService>(),
      authService: sl<IAuthenticationService>(),
      accessibilityService: sl<IAccessibilityService>(),
      deviceAdminService: sl<IDeviceAdminService>(),
      bootService: sl<IBootService>(),
    ),
  );

  // Remote Command Executor - Depends on Device Admin, Location, SMS, Storage, Security Log, Accessibility
  sl.registerLazySingleton<IRemoteCommandExecutor>(
    () => RemoteCommandExecutor(
      deviceAdminService: sl<IDeviceAdminService>(),
      locationService: sl<ILocationService>(),
      smsService: sl<ISmsService>(),
      storageService: sl<IStorageService>(),
      securityLogService: sl<ISecurityLogService>(),
      accessibilityService: sl<IAccessibilityService>(),
    ),
  );

  // Daily Report Service - Depends on Storage, Protection, Location, Security Log, SMS
  sl.registerLazySingleton<IDailyReportService>(
    () => DailyReportService(
      storageService: sl<IStorageService>(),
      protectionService: sl<IProtectionService>(),
      locationService: sl<ILocationService>(),
      securityLogService: sl<ISecurityLogService>(),
      smsService: sl<ISmsService>(),
    ),
  );

  // Backup Service - Depends on Storage, Security Log
  sl.registerLazySingleton<IBackupService>(
    () => BackupService(
      storageService: sl<IStorageService>(),
      securityLogService: sl<ISecurityLogService>(),
    ),
  );

  // Test Mode Service - Depends on multiple services
  sl.registerLazySingleton<ITestModeService>(
    () => TestModeService(
      alarmService: sl<IAlarmService>(),
      cameraService: sl<ICameraService>(),
      locationService: sl<ILocationService>(),
      smsService: sl<ISmsService>(),
      deviceAdminService: sl<IDeviceAdminService>(),
      accessibilityService: sl<IAccessibilityService>(),
      protectionService: sl<IProtectionService>(),
      monitoringService: sl<IMonitoringService>(),
    ),
  );
}

/// Initialize all services that require async initialization.
///
/// Call this after [setupServiceLocator] to initialize services
/// that need async setup.
Future<void> initializeServices() async {
  // Initialize Security Log Service with encryption key
  final securityLogService = sl<ISecurityLogService>();

  // Use a default key for now - in production, derive from master password
  const defaultEncryptionKey = 'anti_theft_default_key_32bytes!!';
  await securityLogService.initialize(defaultEncryptionKey);

  // Initialize Location Service
  final locationService = sl<ILocationService>();
  await locationService.initialize();

  // Initialize Camera Service
  final cameraService = sl<ICameraService>();
  await cameraService.initialize();

  // Initialize Alarm Service
  final alarmService = sl<IAlarmService>();
  await alarmService.initialize();

  // Initialize Protection Service
  final protectionService = sl<IProtectionService>();
  await protectionService.initialize();

  // Initialize SMS Service
  final smsService = sl<ISmsService>();
  await smsService.initialize();

  // Initialize Audio Recording Service
  final audioService = sl<IAudioRecordingService>();
  await audioService.initialize();

  // Initialize Foreground Service
  final foregroundService = sl<IForegroundService>() as ForegroundService;
  await foregroundService.initialize();

  // Initialize Battery Service
  final batteryService = sl<IBatteryService>() as BatteryService;
  await batteryService.initialize();
}

/// Dispose all services.
///
/// Call this when the app is being terminated.
Future<void> disposeServices() async {
  // Dispose services in reverse order of initialization
  if (sl.isRegistered<IAudioRecordingService>()) {
    await sl<IAudioRecordingService>().dispose();
  }

  if (sl.isRegistered<ISmsService>()) {
    await sl<ISmsService>().dispose();
  }

  if (sl.isRegistered<IProtectionService>()) {
    await sl<IProtectionService>().dispose();
  }

  if (sl.isRegistered<IAlarmService>()) {
    await sl<IAlarmService>().dispose();
  }

  if (sl.isRegistered<ICameraService>()) {
    await sl<ICameraService>().dispose();
  }

  if (sl.isRegistered<ILocationService>()) {
    await sl<ILocationService>().dispose();
  }

  if (sl.isRegistered<ISecurityLogService>()) {
    await sl<ISecurityLogService>().close();
  }

  // Reset the service locator
  await sl.reset();
}

/// Reset the service locator for testing.
///
/// This clears all registered services.
Future<void> resetServiceLocator() async {
  await sl.reset();
}
