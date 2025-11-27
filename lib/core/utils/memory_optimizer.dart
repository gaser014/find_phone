import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Memory optimization utilities for the Anti-Theft Protection app.
///
/// Provides functionality to monitor and optimize memory usage
/// to keep the app under 50MB footprint.
///
/// Requirements: 10.5 - Minimize memory footprint to under 50MB
class MemoryOptimizer {
  static const String _channelName = 'com.example.find_phone/memory';
  static final MethodChannel _methodChannel = const MethodChannel(_channelName);

  /// Memory threshold in bytes (50MB)
  static const int memoryThresholdBytes = 50 * 1024 * 1024;

  /// Low memory threshold in bytes (40MB - trigger cleanup)
  static const int lowMemoryThresholdBytes = 40 * 1024 * 1024;

  /// Singleton instance
  static MemoryOptimizer? _instance;

  /// Get singleton instance
  static MemoryOptimizer get instance {
    _instance ??= MemoryOptimizer._();
    return _instance!;
  }

  MemoryOptimizer._();

  /// Get current memory usage in bytes.
  Future<int> getCurrentMemoryUsage() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getMemoryUsage');
      return result ?? 0;
    } on PlatformException catch (e) {
      debugPrint('Error getting memory usage: ${e.message}');
      return 0;
    }
  }

  /// Get current memory usage in MB.
  Future<double> getCurrentMemoryUsageMB() async {
    final bytes = await getCurrentMemoryUsage();
    return bytes / (1024 * 1024);
  }

  /// Check if memory usage is within acceptable limits.
  Future<bool> isMemoryUsageAcceptable() async {
    final usage = await getCurrentMemoryUsage();
    return usage < memoryThresholdBytes;
  }

  /// Check if memory cleanup is needed.
  Future<bool> needsMemoryCleanup() async {
    final usage = await getCurrentMemoryUsage();
    return usage > lowMemoryThresholdBytes;
  }

  /// Perform memory cleanup.
  ///
  /// This triggers garbage collection and clears caches.
  Future<void> performCleanup() async {
    debugPrint('MemoryOptimizer: Performing memory cleanup');

    // Clear image cache
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    // Request native cleanup
    try {
      await _methodChannel.invokeMethod('performCleanup');
    } on PlatformException catch (e) {
      debugPrint('Error performing native cleanup: ${e.message}');
    }

    debugPrint('MemoryOptimizer: Cleanup complete');
  }

  /// Trim memory when app goes to background.
  ///
  /// Called when the app receives a memory warning or goes to background.
  Future<void> trimMemory() async {
    debugPrint('MemoryOptimizer: Trimming memory');

    // Clear image cache
    PaintingBinding.instance.imageCache.clear();

    // Request native trim
    try {
      await _methodChannel.invokeMethod('trimMemory');
    } on PlatformException catch (e) {
      debugPrint('Error trimming memory: ${e.message}');
    }
  }

  /// Set maximum image cache size.
  ///
  /// Limits the image cache to reduce memory usage.
  void setImageCacheSize({int maxImages = 50, int maxSizeBytes = 10 * 1024 * 1024}) {
    PaintingBinding.instance.imageCache.maximumSize = maxImages;
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxSizeBytes;
  }

  /// Get memory statistics.
  Future<MemoryStats> getMemoryStats() async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getMemoryStats',
      );

      if (result != null) {
        return MemoryStats.fromMap(Map<String, dynamic>.from(result));
      }
    } on PlatformException catch (e) {
      debugPrint('Error getting memory stats: ${e.message}');
    }

    return MemoryStats.empty();
  }

  /// Start periodic memory monitoring.
  ///
  /// Monitors memory usage and performs cleanup when needed.
  Timer startPeriodicMonitoring({
    Duration interval = const Duration(minutes: 5),
    void Function(MemoryStats)? onStats,
  }) {
    return Timer.periodic(interval, (_) async {
      final stats = await getMemoryStats();
      onStats?.call(stats);

      if (await needsMemoryCleanup()) {
        await performCleanup();
      }
    });
  }
}

/// Memory statistics.
class MemoryStats {
  /// Total memory used by the app in bytes.
  final int usedMemory;

  /// Maximum memory available to the app in bytes.
  final int maxMemory;

  /// Native heap size in bytes.
  final int nativeHeapSize;

  /// Native heap allocated in bytes.
  final int nativeHeapAllocated;

  /// Dalvik heap size in bytes.
  final int dalvikHeapSize;

  /// Dalvik heap allocated in bytes.
  final int dalvikHeapAllocated;

  MemoryStats({
    required this.usedMemory,
    required this.maxMemory,
    required this.nativeHeapSize,
    required this.nativeHeapAllocated,
    required this.dalvikHeapSize,
    required this.dalvikHeapAllocated,
  });

  factory MemoryStats.fromMap(Map<String, dynamic> map) {
    return MemoryStats(
      usedMemory: map['usedMemory'] as int? ?? 0,
      maxMemory: map['maxMemory'] as int? ?? 0,
      nativeHeapSize: map['nativeHeapSize'] as int? ?? 0,
      nativeHeapAllocated: map['nativeHeapAllocated'] as int? ?? 0,
      dalvikHeapSize: map['dalvikHeapSize'] as int? ?? 0,
      dalvikHeapAllocated: map['dalvikHeapAllocated'] as int? ?? 0,
    );
  }

  factory MemoryStats.empty() {
    return MemoryStats(
      usedMemory: 0,
      maxMemory: 0,
      nativeHeapSize: 0,
      nativeHeapAllocated: 0,
      dalvikHeapSize: 0,
      dalvikHeapAllocated: 0,
    );
  }

  /// Get used memory in MB.
  double get usedMemoryMB => usedMemory / (1024 * 1024);

  /// Get max memory in MB.
  double get maxMemoryMB => maxMemory / (1024 * 1024);

  /// Get memory usage percentage.
  double get usagePercentage {
    if (maxMemory == 0) return 0;
    return (usedMemory / maxMemory) * 100;
  }

  /// Check if memory usage is within acceptable limits (under 50MB).
  bool get isAcceptable => usedMemory < MemoryOptimizer.memoryThresholdBytes;

  @override
  String toString() {
    return 'MemoryStats(used: ${usedMemoryMB.toStringAsFixed(1)}MB, '
        'max: ${maxMemoryMB.toStringAsFixed(1)}MB, '
        'usage: ${usagePercentage.toStringAsFixed(1)}%)';
  }
}
