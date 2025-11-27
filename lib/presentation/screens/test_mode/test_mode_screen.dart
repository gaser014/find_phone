import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/entities/captured_photo.dart';
import '../../../domain/entities/location_data.dart';
import '../../../domain/entities/remote_command.dart';
import '../../../services/test_mode/i_test_mode_service.dart';

/// Test Mode Screen for testing all protection features.
///
/// Provides test buttons for all features and displays test results.
///
/// Requirements:
/// - 24.1: Provide test buttons for all protection features
/// - 24.2: Test alarm for 5 seconds only, no SMS
/// - 24.3: Test camera capture, display photo, no logging
/// - 24.4: Simulate SMS commands without actual SMS
/// - 24.5: Display test results report
/// - 24.6: Display detailed error messages for failed tests
class TestModeScreen extends StatefulWidget {
  final ITestModeService testModeService;
  final Future<Uint8List?> Function(String photoId)? readPhotoData;

  const TestModeScreen({
    super.key,
    required this.testModeService,
    this.readPhotoData,
  });

  @override
  State<TestModeScreen> createState() => _TestModeScreenState();
}

class _TestModeScreenState extends State<TestModeScreen> {
  bool _isRunningAllTests = false;
  bool _isRunningTest = false;
  List<TestResult> _testResults = [];
  CapturedPhoto? _capturedPhoto;
  Uint8List? _capturedPhotoData;

  @override
  void initState() {
    super.initState();
    _testResults = widget.testModeService.getLastTestResults();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunningAllTests = true;
      _testResults = [];
    });

    try {
      final results = await widget.testModeService.runAllTests();
      setState(() {
        _testResults = results;
      });

      final passedCount = results.where((r) => r.passed).length;
      final totalCount = results.length;
      _showSnackBar(
        'اكتمل الاختبار: $passedCount/$totalCount نجح',
        isError: passedCount < totalCount,
      );
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء تشغيل الاختبارات: $e', isError: true);
    } finally {
      setState(() {
        _isRunningAllTests = false;
      });
    }
  }

  Future<void> _testAlarm() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testAlarm();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار الإنذار' : 'فشل اختبار الإنذار',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testCamera() async {
    setState(() => _isRunningTest = true);
    try {
      final (result, photo) = await widget.testModeService.testCamera();
      _addTestResult(result);
      
      if (photo != null && widget.readPhotoData != null) {
        final photoData = await widget.readPhotoData!(photo.id);
        setState(() {
          _capturedPhoto = photo;
          _capturedPhotoData = photoData;
        });
        
        if (photoData != null) {
          _showCapturedPhotoDialog();
        }
      }
      
      _showSnackBar(
        result.passed ? 'نجح اختبار الكاميرا' : 'فشل اختبار الكاميرا',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testLocation() async {
    setState(() => _isRunningTest = true);
    try {
      final (result, location) = await widget.testModeService.testLocation();
      _addTestResult(result);
      
      if (location != null) {
        _showLocationDialog(location);
      }
      
      _showSnackBar(
        result.passed ? 'نجح اختبار الموقع' : 'فشل اختبار الموقع',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testSmsCommand(RemoteCommandType commandType) async {
    // Show password input dialog
    final password = await _showPasswordInputDialog();
    if (password == null || password.isEmpty) return;

    setState(() => _isRunningTest = true);
    try {
      final (result, command) = await widget.testModeService.testSmsCommand(
        commandType,
        password,
      );
      _addTestResult(result);
      
      _showSnackBar(
        result.passed ? 'نجح اختبار أمر SMS' : 'فشل اختبار أمر SMS',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testSmsSending() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testSmsSending();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار SMS' : 'فشل اختبار SMS',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testDeviceAdmin() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testDeviceAdmin();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار مدير الجهاز' : 'فشل اختبار مدير الجهاز',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testAccessibility() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testAccessibilityService();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار إمكانية الوصول' : 'فشل اختبار إمكانية الوصول',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testProtectedMode() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testProtectedMode();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار وضع الحماية' : 'فشل اختبار وضع الحماية',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testKioskMode() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testKioskMode();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار وضع Kiosk' : 'فشل اختبار وضع Kiosk',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  Future<void> _testSimMonitoring() async {
    setState(() => _isRunningTest = true);
    try {
      final result = await widget.testModeService.testSimMonitoring();
      _addTestResult(result);
      _showSnackBar(
        result.passed ? 'نجح اختبار مراقبة SIM' : 'فشل اختبار مراقبة SIM',
        isError: !result.passed,
      );
    } finally {
      setState(() => _isRunningTest = false);
    }
  }

  void _addTestResult(TestResult result) {
    setState(() {
      // Remove existing result for same feature if exists
      _testResults.removeWhere((r) => r.featureName == result.featureName);
      _testResults.insert(0, result);
    });
  }

  Future<String?> _showPasswordInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختبار أمر SMS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل كلمة مرور للاختبار:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('اختبار'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCapturedPhotoDialog() {
    if (_capturedPhotoData == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('صورة الاختبار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _capturedPhotoData!,
                  width: 250,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تم التقاط الصورة بنجاح',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_capturedPhoto != null) ...[
                const SizedBox(height: 8),
                Text(
                  'الوقت: ${_capturedPhoto!.timestamp.toString().substring(0, 19)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog(LocationData location) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('موقع الاختبار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLocationRow('خط العرض', location.latitude.toStringAsFixed(6)),
              _buildLocationRow('خط الطول', location.longitude.toStringAsFixed(6)),
              _buildLocationRow('الدقة', '${location.accuracy.toStringAsFixed(0)} متر'),
              _buildLocationRow('الوقت', location.timestamp.toString().substring(0, 19)),
              const SizedBox(height: 16),
              Text(
                'رابط خرائط Google:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SelectableText(
                location.toGoogleMapsLink(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _showTestResultDetails(TestResult result) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                result.passed ? Icons.check_circle : Icons.error,
                color: result.passed ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(result.featureName)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (result.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'تفاصيل الخطأ:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (result.suggestedFix != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'الحل المقترح:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.suggestedFix!,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'وقت الاختبار: ${result.timestamp.toString().substring(0, 19)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وضع الاختبار'),
          centerTitle: true,
          actions: [
            if (_testResults.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => _testResults = []);
                },
                tooltip: 'مسح النتائج',
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Run All Tests Button
              _buildRunAllTestsButton(),
              const SizedBox(height: 24),

              // Individual Test Buttons
              _buildSectionHeader('اختبارات فردية'),
              const SizedBox(height: 8),
              _buildTestButtonsGrid(),
              const SizedBox(height: 24),

              // SMS Command Tests
              _buildSectionHeader('اختبار أوامر SMS'),
              const SizedBox(height: 8),
              _buildSmsCommandButtons(),
              const SizedBox(height: 24),

              // Test Results
              if (_testResults.isNotEmpty) ...[
                _buildSectionHeader('نتائج الاختبار'),
                const SizedBox(height: 8),
                _buildTestResultsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunAllTestsButton() {
    final passedCount = _testResults.where((r) => r.passed).length;
    final totalCount = _testResults.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isRunningAllTests || _isRunningTest ? null : _runAllTests,
              icon: _isRunningAllTests
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunningAllTests ? 'جاري الاختبار...' : 'تشغيل جميع الاختبارات'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            if (_testResults.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    passedCount == totalCount ? Icons.check_circle : Icons.warning,
                    color: passedCount == totalCount ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$passedCount من $totalCount اختبار نجح',
                    style: TextStyle(
                      color: passedCount == totalCount ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
    );
  }

  Widget _buildTestButtonsGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTestButton(
              'الإنذار',
              Icons.volume_up,
              _testAlarm,
              Colors.red,
            ),
            _buildTestButton(
              'الكاميرا',
              Icons.camera_alt,
              _testCamera,
              Colors.purple,
            ),
            _buildTestButton(
              'الموقع',
              Icons.location_on,
              _testLocation,
              Colors.blue,
            ),
            _buildTestButton(
              'SMS',
              Icons.sms,
              _testSmsSending,
              Colors.green,
            ),
            _buildTestButton(
              'مدير الجهاز',
              Icons.admin_panel_settings,
              _testDeviceAdmin,
              Colors.orange,
            ),
            _buildTestButton(
              'إمكانية الوصول',
              Icons.accessibility,
              _testAccessibility,
              Colors.teal,
            ),
            _buildTestButton(
              'وضع الحماية',
              Icons.shield,
              _testProtectedMode,
              Colors.indigo,
            ),
            _buildTestButton(
              'وضع Kiosk',
              Icons.lock,
              _testKioskMode,
              Colors.brown,
            ),
            _buildTestButton(
              'مراقبة SIM',
              Icons.sim_card,
              _testSimMonitoring,
              Colors.cyan,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: _isRunningTest || _isRunningAllTests ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsCommandButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSmsCommandButton('LOCK', RemoteCommandType.lock, Colors.orange),
            _buildSmsCommandButton('LOCATE', RemoteCommandType.locate, Colors.blue),
            _buildSmsCommandButton('ALARM', RemoteCommandType.alarm, Colors.red),
            _buildSmsCommandButton('WIPE', RemoteCommandType.wipe, Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsCommandButton(
    String label,
    RemoteCommandType commandType,
    Color color,
  ) {
    return SizedBox(
      width: 80,
      child: ElevatedButton(
        onPressed: _isRunningTest || _isRunningAllTests
            ? null
            : () => _testSmsCommand(commandType),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTestResultsList() {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _testResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final result = _testResults[index];
          return ListTile(
            leading: Icon(
              result.passed ? Icons.check_circle : Icons.error,
              color: result.passed ? Colors.green : Colors.red,
            ),
            title: Text(result.featureName),
            subtitle: Text(
              result.passed ? 'نجح' : 'فشل',
              style: TextStyle(
                color: result.passed ? Colors.green : Colors.red,
              ),
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _showTestResultDetails(result),
          );
        },
      ),
    );
  }
}
