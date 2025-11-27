/// Dependency Injection module.
///
/// This module provides dependency injection setup for all services
/// in the Anti-Theft Protection app.
///
/// Usage:
/// ```dart
/// import 'package:find_phone/core/di/di.dart';
///
/// void main() async {
///   await setupServiceLocator();
///   await initializeServices();
///   runApp(MyApp());
/// }
/// ```
library di;

export 'service_locator.dart';
