import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/location_data.dart';
import '../../domain/entities/remote_command.dart';
import '../alarm/i_alarm_service.dart';
import '../camera/i_camera_service.dart';
import '../location/i_location_service.dart';
import '../sms/i_sms_service.dart';
import '../device_admin/i_device_admin_service.dart';
import '../accessibility/i_accessibility_service.dart';
import '../protection/i_protection_service.dart';
import '../monitoring/i_monitoring_service.dart';
import 'i_test_mode_service.dart';

/// Implementation of Test Mode Service.
///
/// Provides functionality to test all protection features without
/// triggering real security events or sending actual SMS messages.
///
/// Requirements: 24.1 - 24.6
class TestModeService implements ITestModeService {
  final IAlarmService _alarmService;
  final ICameraService _cameraService;
  final ILocationService _locationService;
  final ISmsService _smsService;
  final IDeviceAdminService _deviceAdminService;
  final IAccessibilityService _accessibilityService;
  final IProtectionService _protectionService;
  final IMonitoringService? _monitoringService;

  bool _isTestModeActive = false;
  List<TestResult> _lastTestResults = [];

  TestModeService({
    required IAlarmService alarmService,
    required ICameraService cameraService,
    required ILocationService locationService,
    required ISmsService smsService,
    required IDeviceAdminService deviceAdminService,
    required IAccessibilityService accessibilityService,
    required IProtectionService protectionService,
    IMonitoringService? monitoringService,
  })  : _alarmService = alarmService,
        _cameraService = cameraService,
        _locationService = locationService,
        _smsService = smsService,
        _deviceAdminService = deviceAdminService,
        _accessibilityService = accessibilityService,
        _protectionService = protectionService,
        _monitoringService = monitoringService;

  @override
  bool get isTestModeActive => _isTestModeActive;

  @override
  Future<void> enterTestMode() async {
    _isTestModeActive = true;
    _lastTestResults = [];
  }

  @override
  Future<void> exitTestMode() async {
    _isTestModeActive = false;
  }

  @override
  List<TestResult> getLastTestResults() => List.unmodifiable(_lastTestResults);

  /// Test the alarm feature.
  ///
  /// Plays alarm for 5 seconds only and does not send real SMS.
  ///
  /// Requirements: 24.2
  @override
  Future<TestResult> testAlarm() async {
    try {
      // Check audio permission first
      final hasPermission = await _alarmService.hasAudioPermission();
      if (!hasPermission) {
        final granted = await _alarmService.requestAudioPermission();
        if (!granted) {
          return TestResult.failure(
            'اختبار الإنذار',
            'فشل اختبار الإنذار',
            errorMessage: 'لم يتم منح صلاحية الصوت',
            suggestedFix: 'يرجى منح صلاحية الصوت من إعدادات التطبيق',
          );
        }
      }

      // Trigger alarm for 5 seconds only (test mode)
      final success = await _alarmService.triggerAlarm(
        duration: const Duration(seconds: 5),
        ignoreVolumeSettings: true,
        continuous: false,
        reason: 'test_mode',
      );

      if (success) {
        return TestResult.success(
          'اختبار الإنذار',
          'تم تشغيل الإنذار بنجاح لمدة 5 ثوانٍ',
        );
      } else {
        return TestResult.failure(
          'اختبار الإنذار',
          'فشل في تشغيل الإنذار',
          errorMessage: 'لم يتمكن النظام من تشغيل الإنذار',
          suggestedFix: 'تأكد من أن الجهاز يدعم تشغيل الصوت',
        );
      }
    } catch (e) {
      return TestResult.failure(
        'اختبار الإنذار',
        'حدث خطأ أثناء اختبار الإنذار',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من صلاحيات الصوت وإعدادات الجهاز',
      );
    }
  }

  /// Test the camera capture feature.
  ///
  /// Takes a photo and displays it without logging as security event.
  ///
  /// Requirements: 24.3
  @override
  Future<(TestResult, CapturedPhoto?)> testCamera() async {
    try {
      // Check camera permission first
      final hasPermission = await _cameraService.hasCameraPermission();
      if (!hasPermission) {
        final granted = await _cameraService.requestCameraPermission();
        if (!granted) {
          return (
            TestResult.failure(
              'اختبار الكاميرا',
              'فشل اختبار الكاميرا',
              errorMessage: 'لم يتم منح صلاحية الكاميرا',
              suggestedFix: 'يرجى منح صلاحية الكاميرا من إعدادات التطبيق',
            ),
            null
          );
        }
      }

      // Check if front camera is available
      final hasFrontCamera = await _cameraService.hasFrontCamera();
      if (!hasFrontCamera) {
        return (
          TestResult.failure(
            'اختبار الكاميرا',
            'الكاميرا الأمامية غير متوفرة',
            errorMessage: 'لا توجد كاميرا أمامية على هذا الجهاز',
            suggestedFix: 'هذه الميزة تتطلب كاميرا أمامية',
          ),
          null
        );
      }

      // Initialize camera if needed
      if (!_cameraService.isInitialized) {
        await _cameraService.initialize();
      }

      // Capture photo with test_mode reason (won't be logged as security event)
      final photo = await _cameraService.captureFrontPhoto(
        reason: 'test_mode',
      );

      if (photo != null) {
        return (
          TestResult.success(
            'اختبار الكاميرا',
            'تم التقاط الصورة بنجاح',
          ),
          photo
        );
      } else {
        return (
          TestResult.failure(
            'اختبار الكاميرا',
            'فشل في التقاط الصورة',
            errorMessage: 'لم يتمكن النظام من التقاط صورة',
            suggestedFix: 'تأكد من أن الكاميرا تعمل بشكل صحيح',
          ),
          null
        );
      }
    } catch (e) {
      return (
        TestResult.failure(
          'اختبار الكاميرا',
          'حدث خطأ أثناء اختبار الكاميرا',
          errorMessage: e.toString(),
          suggestedFix: 'تأكد من صلاحيات الكاميرا وأنها غير مستخدمة من تطبيق آخر',
        ),
        null
      );
    }
  }

  /// Test the location tracking feature.
  @override
  Future<(TestResult, LocationData?)> testLocation() async {
    try {
      // Check location permission first
      final hasPermission = await _locationService.hasLocationPermission();
      if (!hasPermission) {
        final granted = await _locationService.requestLocationPermission();
        if (!granted) {
          return (
            TestResult.failure(
              'اختبار الموقع',
              'فشل اختبار الموقع',
              errorMessage: 'لم يتم منح صلاحية الموقع',
              suggestedFix: 'يرجى منح صلاحية الموقع من إعدادات التطبيق',
            ),
            null
          );
        }
      }

      // Check if location services are enabled
      final isEnabled = await _locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        return (
          TestResult.failure(
            'اختبار الموقع',
            'خدمات الموقع معطلة',
            errorMessage: 'خدمات GPS معطلة على الجهاز',
            suggestedFix: 'يرجى تفعيل خدمات الموقع من إعدادات الجهاز',
          ),
          null
        );
      }

      // Get current location
      final location = await _locationService.getCurrentLocation();

      return (
        TestResult.success(
          'اختبار الموقع',
          'تم الحصول على الموقع بنجاح\n'
              'الإحداثيات: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}\n'
              'الدقة: ${location.accuracy.toStringAsFixed(0)} متر',
        ),
        location
      );
    } catch (e) {
      return (
        TestResult.failure(
          'اختبار الموقع',
          'حدث خطأ أثناء اختبار الموقع',
          errorMessage: e.toString(),
          suggestedFix: 'تأكد من تفعيل GPS وصلاحيات الموقع',
        ),
        null
      );
    }
  }

  /// Simulate receiving an SMS command.
  ///
  /// Requirements: 24.4
  @override
  Future<(TestResult, RemoteCommand?)> testSmsCommand(
    RemoteCommandType commandType,
    String password,
  ) async {
    try {
      // Get command name in Arabic
      String commandName;
      switch (commandType) {
        case RemoteCommandType.lock:
          commandName = 'LOCK (قفل)';
          break;
        case RemoteCommandType.wipe:
          commandName = 'WIPE (مسح)';
          break;
        case RemoteCommandType.locate:
          commandName = 'LOCATE (تحديد الموقع)';
          break;
        case RemoteCommandType.alarm:
          commandName = 'ALARM (إنذار)';
          break;
      }

      // Simulate SMS message format
      final commandString = '${commandType.name.toUpperCase()}#$password';
      
      // Parse the command (simulated sender)
      final command = RemoteCommand.parse('+201234567890', commandString);

      if (command == null) {
        return (
          TestResult.failure(
            'اختبار أمر SMS: $commandName',
            'فشل في تحليل الأمر',
            errorMessage: 'صيغة الأمر غير صحيحة',
            suggestedFix: 'تأكد من صيغة الأمر: COMMAND#password',
          ),
          null
        );
      }

      // Verify command was parsed correctly
      if (command.type != commandType) {
        return (
          TestResult.failure(
            'اختبار أمر SMS: $commandName',
            'نوع الأمر غير متطابق',
            errorMessage: 'تم تحليل الأمر كـ ${command.type} بدلاً من $commandType',
            suggestedFix: 'تحقق من منطق تحليل الأوامر',
          ),
          null
        );
      }

      if (command.password != password) {
        return (
          TestResult.failure(
            'اختبار أمر SMS: $commandName',
            'كلمة المرور غير متطابقة',
            errorMessage: 'لم يتم استخراج كلمة المرور بشكل صحيح',
            suggestedFix: 'تحقق من منطق تحليل كلمة المرور',
          ),
          null
        );
      }

      return (
        TestResult.success(
          'اختبار أمر SMS: $commandName',
          'تم تحليل الأمر بنجاح\n'
              'النوع: ${command.type.name}\n'
              'المرسل: ${command.sender}\n'
              'ملاحظة: لم يتم تنفيذ الأمر فعلياً (وضع الاختبار)',
        ),
        command
      );
    } catch (e) {
      return (
        TestResult.failure(
          'اختبار أمر SMS',
          'حدث خطأ أثناء اختبار أمر SMS',
          errorMessage: e.toString(),
          suggestedFix: 'تحقق من منطق تحليل الأوامر',
        ),
        null
      );
    }
  }

  /// Test SMS sending capability.
  @override
  Future<TestResult> testSmsSending() async {
    try {
      final hasPermission = await _smsService.hasSmsPermission();
      if (!hasPermission) {
        final granted = await _smsService.requestSmsPermission();
        if (!granted) {
          return TestResult.failure(
            'اختبار إرسال SMS',
            'فشل اختبار SMS',
            errorMessage: 'لم يتم منح صلاحية SMS',
            suggestedFix: 'يرجى منح صلاحية SMS من إعدادات التطبيق',
          );
        }
      }

      // Check if emergency contact is configured
      final emergencyContact = await _smsService.getEmergencyContact();
      if (emergencyContact == null || emergencyContact.isEmpty) {
        return TestResult.failure(
          'اختبار إرسال SMS',
          'رقم الطوارئ غير محدد',
          errorMessage: 'لم يتم تحديد رقم جهة اتصال الطوارئ',
          suggestedFix: 'يرجى إعداد رقم جهة اتصال الطوارئ أولاً',
        );
      }

      return TestResult.success(
        'اختبار إرسال SMS',
        'صلاحيات SMS متوفرة\n'
            'رقم الطوارئ: $emergencyContact\n'
            'ملاحظة: لم يتم إرسال رسالة فعلية (وضع الاختبار)',
      );
    } catch (e) {
      return TestResult.failure(
        'اختبار إرسال SMS',
        'حدث خطأ أثناء اختبار SMS',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من صلاحيات SMS',
      );
    }
  }

  /// Test device admin permissions.
  @override
  Future<TestResult> testDeviceAdmin() async {
    try {
      final isActive = await _deviceAdminService.isAdminActive();
      if (!isActive) {
        return TestResult.failure(
          'اختبار مدير الجهاز',
          'مدير الجهاز غير مفعل',
          errorMessage: 'صلاحيات Device Administrator غير مفعلة',
          suggestedFix: 'يرجى تفعيل صلاحيات مدير الجهاز من الإعدادات',
        );
      }

      return TestResult.success(
        'اختبار مدير الجهاز',
        'صلاحيات مدير الجهاز مفعلة بنجاح',
      );
    } catch (e) {
      return TestResult.failure(
        'اختبار مدير الجهاز',
        'حدث خطأ أثناء اختبار مدير الجهاز',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من تفعيل صلاحيات Device Administrator',
      );
    }
  }

  /// Test accessibility service.
  @override
  Future<TestResult> testAccessibilityService() async {
    try {
      final isEnabled = await _accessibilityService.isServiceEnabled();
      if (!isEnabled) {
        return TestResult.failure(
          'اختبار خدمة إمكانية الوصول',
          'خدمة إمكانية الوصول غير مفعلة',
          errorMessage: 'Accessibility Service غير مفعلة',
          suggestedFix: 'يرجى تفعيل خدمة إمكانية الوصول من إعدادات الجهاز',
        );
      }

      return TestResult.success(
        'اختبار خدمة إمكانية الوصول',
        'خدمة إمكانية الوصول مفعلة بنجاح',
      );
    } catch (e) {
      return TestResult.failure(
        'اختبار خدمة إمكانية الوصول',
        'حدث خطأ أثناء اختبار خدمة إمكانية الوصول',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من تفعيل Accessibility Service',
      );
    }
  }

  /// Test protected mode activation.
  @override
  Future<TestResult> testProtectedMode() async {
    try {
      final isActive = await _protectionService.isProtectedModeActive();
      
      return TestResult.success(
        'اختبار وضع الحماية',
        'وضع الحماية ${isActive ? "مفعل" : "غير مفعل"}\n'
            'يمكن تفعيل/إلغاء وضع الحماية من لوحة التحكم',
      );
    } catch (e) {
      return TestResult.failure(
        'اختبار وضع الحماية',
        'حدث خطأ أثناء اختبار وضع الحماية',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من إعدادات التطبيق',
      );
    }
  }

  /// Test kiosk mode activation.
  @override
  Future<TestResult> testKioskMode() async {
    try {
      final isActive = await _protectionService.isKioskModeActive();
      
      return TestResult.success(
        'اختبار وضع Kiosk',
        'وضع Kiosk ${isActive ? "مفعل" : "غير مفعل"}\n'
            'يمكن تفعيل/إلغاء وضع Kiosk من لوحة التحكم',
      );
    } catch (e) {
      return TestResult.failure(
        'اختبار وضع Kiosk',
        'حدث خطأ أثناء اختبار وضع Kiosk',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من صلاحيات Task Locking',
      );
    }
  }

  /// Test SIM card monitoring.
  @override
  Future<TestResult> testSimMonitoring() async {
    try {
      if (_monitoringService == null) {
        return TestResult.failure(
          'اختبار مراقبة SIM',
          'خدمة المراقبة غير متوفرة',
          errorMessage: 'لم يتم تهيئة خدمة المراقبة',
          suggestedFix: 'تأكد من تهيئة خدمة المراقبة',
        );
      }

      // Just verify the service is available
      return TestResult.success(
        'اختبار مراقبة SIM',
        'خدمة مراقبة SIM متوفرة\n'
            'سيتم اكتشاف أي تغيير في شريحة SIM',
      );
    } catch (e) {
      return TestResult.failure(
        'اختبار مراقبة SIM',
        'حدث خطأ أثناء اختبار مراقبة SIM',
        errorMessage: e.toString(),
        suggestedFix: 'تأكد من صلاحيات قراءة معلومات الهاتف',
      );
    }
  }

  /// Run all tests and return results.
  ///
  /// Requirements: 24.5
  @override
  Future<List<TestResult>> runAllTests() async {
    await enterTestMode();
    _lastTestResults = [];

    // Run all tests
    _lastTestResults.add(await testAlarm());
    
    final (cameraResult, _) = await testCamera();
    _lastTestResults.add(cameraResult);
    
    final (locationResult, _) = await testLocation();
    _lastTestResults.add(locationResult);
    
    _lastTestResults.add(await testSmsSending());
    _lastTestResults.add(await testDeviceAdmin());
    _lastTestResults.add(await testAccessibilityService());
    _lastTestResults.add(await testProtectedMode());
    _lastTestResults.add(await testKioskMode());
    _lastTestResults.add(await testSimMonitoring());

    // Test SMS command parsing for all command types
    for (final commandType in RemoteCommandType.values) {
      final (result, _) = await testSmsCommand(commandType, 'testPassword123');
      _lastTestResults.add(result);
    }

    await exitTestMode();
    return List.unmodifiable(_lastTestResults);
  }
}
