import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/location_data.dart';
import '../../domain/entities/remote_command.dart';

/// Result of a feature test.
class TestResult {
  /// Name of the feature tested
  final String featureName;
  
  /// Whether the test passed
  final bool passed;
  
  /// Detailed message about the test result
  final String message;
  
  /// Error message if test failed
  final String? errorMessage;
  
  /// Suggested fix if test failed
  final String? suggestedFix;
  
  /// When the test was executed
  final DateTime timestamp;

  TestResult({
    required this.featureName,
    required this.passed,
    required this.message,
    this.errorMessage,
    this.suggestedFix,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TestResult.success(String featureName, String message) {
    return TestResult(
      featureName: featureName,
      passed: true,
      message: message,
    );
  }

  factory TestResult.failure(
    String featureName,
    String message, {
    String? errorMessage,
    String? suggestedFix,
  }) {
    return TestResult(
      featureName: featureName,
      passed: false,
      message: message,
      errorMessage: errorMessage,
      suggestedFix: suggestedFix,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featureName': featureName,
      'passed': passed,
      'message': message,
      'errorMessage': errorMessage,
      'suggestedFix': suggestedFix,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Interface for Test Mode Service.
///
/// Provides functionality to test all protection features without
/// triggering real security events or sending actual SMS messages.
///
/// Requirements: 24.1 - 24.6
abstract class ITestModeService {
  /// Test the alarm feature.
  ///
  /// Plays alarm for 5 seconds only and does not send real SMS.
  ///
  /// Requirements: 24.2
  Future<TestResult> testAlarm();

  /// Test the camera capture feature.
  ///
  /// Takes a photo and displays it without logging as security event.
  /// Returns the captured photo for display.
  ///
  /// Requirements: 24.3
  Future<(TestResult, CapturedPhoto?)> testCamera();

  /// Test the location tracking feature.
  ///
  /// Gets current location and verifies GPS is working.
  Future<(TestResult, LocationData?)> testLocation();

  /// Simulate receiving an SMS command.
  ///
  /// Simulates receiving a command without requiring actual SMS.
  /// Does not execute the actual command, just validates parsing.
  ///
  /// Requirements: 24.4
  Future<(TestResult, RemoteCommand?)> testSmsCommand(
    RemoteCommandType commandType,
    String password,
  );

  /// Test SMS sending capability.
  ///
  /// Verifies SMS permissions without sending actual message.
  Future<TestResult> testSmsSending();

  /// Test device admin permissions.
  ///
  /// Verifies device admin is active and working.
  Future<TestResult> testDeviceAdmin();

  /// Test accessibility service.
  ///
  /// Verifies accessibility service is enabled and working.
  Future<TestResult> testAccessibilityService();

  /// Test protected mode activation.
  ///
  /// Verifies protected mode can be enabled/disabled.
  Future<TestResult> testProtectedMode();

  /// Test kiosk mode activation.
  ///
  /// Verifies kiosk mode can be enabled.
  Future<TestResult> testKioskMode();

  /// Test SIM card monitoring.
  ///
  /// Verifies SIM card information can be read.
  Future<TestResult> testSimMonitoring();

  /// Run all tests and return results.
  ///
  /// Requirements: 24.5
  Future<List<TestResult>> runAllTests();

  /// Get the last test results.
  List<TestResult> getLastTestResults();

  /// Check if test mode is currently active.
  bool get isTestModeActive;

  /// Enter test mode.
  Future<void> enterTestMode();

  /// Exit test mode.
  Future<void> exitTestMode();
}
