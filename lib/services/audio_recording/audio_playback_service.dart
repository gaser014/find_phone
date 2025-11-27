import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../domain/entities/audio_recording.dart';
import 'i_audio_recording_service.dart';

/// Service for playing back audio recordings in security logs.
///
/// This service handles decryption and playback of encrypted audio recordings
/// captured during security events.
///
/// Requirements: 34.4 - Audio playback in security logs
class AudioPlaybackService {
  final IAudioRecordingService _audioRecordingService;
  final AudioPlayer _audioPlayer;

  String? _currentRecordingId;
  String? _currentTempFilePath;
  bool _isInitialized = false;

  /// Stream controller for playback state changes.
  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast();

  /// Stream of playback state changes.
  Stream<AudioPlaybackState> get stateStream => _stateController.stream;

  /// Current playback state.
  AudioPlaybackState _currentState = AudioPlaybackState.stopped;
  AudioPlaybackState get currentState => _currentState;

  /// Current playback position.
  Duration get position => _audioPlayer.position;

  /// Total duration of current recording.
  Duration? get duration => _audioPlayer.duration;

  /// Whether playback is currently active.
  bool get isPlaying => _audioPlayer.playing;

  /// The ID of the currently loaded recording.
  String? get currentRecordingId => _currentRecordingId;

  AudioPlaybackService({
    required IAudioRecordingService audioRecordingService,
    AudioPlayer? audioPlayer,
  })  : _audioRecordingService = audioRecordingService,
        _audioPlayer = audioPlayer ?? AudioPlayer();

  /// Initialize the playback service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _updateState(AudioPlaybackState.completed);
      } else if (state.playing) {
        _updateState(AudioPlaybackState.playing);
      } else {
        _updateState(AudioPlaybackState.paused);
      }
    });

    _isInitialized = true;
  }

  /// Dispose of the playback service.
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
    await _stateController.close();
    _isInitialized = false;
  }

  /// Update the playback state and notify listeners.
  void _updateState(AudioPlaybackState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Load and play an audio recording.
  ///
  /// [recordingId] - The ID of the recording to play
  ///
  /// Returns true if playback started successfully.
  Future<bool> play(String recordingId) async {
    try {
      // If same recording is already loaded, just resume
      if (_currentRecordingId == recordingId && _currentTempFilePath != null) {
        await _audioPlayer.play();
        return true;
      }

      // Stop any current playback
      await stop();

      // Get the decrypted file path
      final tempFilePath =
          await _audioRecordingService.getPlaybackFilePath(recordingId);
      if (tempFilePath == null) return false;

      _currentRecordingId = recordingId;
      _currentTempFilePath = tempFilePath;

      // Load and play
      await _audioPlayer.setFilePath(tempFilePath);
      await _audioPlayer.play();

      return true;
    } catch (e) {
      _updateState(AudioPlaybackState.error);
      return false;
    }
  }

  /// Play an AudioRecording object directly.
  ///
  /// [recording] - The recording to play
  ///
  /// Returns true if playback started successfully.
  Future<bool> playRecording(AudioRecording recording) async {
    return play(recording.id);
  }

  /// Pause playback.
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Resume playback.
  Future<void> resume() async {
    await _audioPlayer.play();
  }

  /// Stop playback and clean up.
  Future<void> stop() async {
    await _audioPlayer.stop();
    _updateState(AudioPlaybackState.stopped);

    // Clean up temp file
    if (_currentTempFilePath != null) {
      await _audioRecordingService.cleanupPlaybackFiles();
      _currentTempFilePath = null;
    }
    _currentRecordingId = null;
  }

  /// Seek to a specific position.
  ///
  /// [position] - The position to seek to
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Set the playback speed.
  ///
  /// [speed] - The playback speed (1.0 is normal)
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
  }

  /// Set the volume.
  ///
  /// [volume] - The volume level (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  /// Get a stream of position updates.
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Get a stream of duration updates.
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// Get a stream of buffered position updates.
  Stream<Duration> get bufferedPositionStream =>
      _audioPlayer.bufferedPositionStream;
}

/// Playback state enumeration.
enum AudioPlaybackState {
  /// Playback is stopped.
  stopped,

  /// Audio is currently playing.
  playing,

  /// Playback is paused.
  paused,

  /// Playback has completed.
  completed,

  /// An error occurred during playback.
  error,
}
