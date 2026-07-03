import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:musify/main.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeService {
  static final ShakeService _instance = ShakeService._internal();
  factory ShakeService() => _instance;
  ShakeService._internal();

  StreamSubscription? _sensorSubscription;
  Timer? _singleShakeTimer;
  Timer? _cooldownTimer;
  int _shakeCount = 0;
  bool _inCooldown = false;
  DateTime _lastShakeTime = DateTime.now();
  DateTime _flatLockUntil = DateTime.now();

  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;

  void init() {
    shakeToSkipEnabled.addListener(_onSettingChanged);
    _onSettingChanged();
  }

  void _onSettingChanged() {
    if (shakeToSkipEnabled.value) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _startListening() {
    _stopListening(); // Ensure clean state
    
    // We use accelerometerEventStream (includes gravity) instead of userAccelerometer
    // to manually filter it and detect the absolute orientation (Flat Lock).
    _sensorSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval).listen((AccelerometerEvent event) {
      
      // Don't process if music is not playing
      if (audioHandler.playbackState.value.processingState == AudioProcessingState.idle || 
          !audioHandler.playbackState.value.playing) {
        return;
      }

      if (_inCooldown) return;

      // 1. Isolate Gravity with Low-Pass Filter
      final double alpha = 0.8;
      _gravityX = alpha * _gravityX + (1 - alpha) * event.x;
      _gravityY = alpha * _gravityY + (1 - alpha) * event.y;
      _gravityZ = alpha * _gravityZ + (1 - alpha) * event.z;

      // 2. FLAT LOCK & SHOCK LOCK
      // If the phone is currently resting flat (_gravityZ > 7.5), 
      // OR if it just took a massive vertical shock (event.z > 12.0),
      // we lock the sensor to absorb all bounce/rebound events.
      if (_gravityZ.abs() > 7.5 || event.z.abs() > 12.0) {
        _flatLockUntil = DateTime.now().add(const Duration(milliseconds: 1000));
      }

      if (DateTime.now().isBefore(_flatLockUntil)) {
        return; // Fully block processing during the shock/flat lock window
      }

      // 3. Remove gravity to get pure linear acceleration
      double linearX = event.x - _gravityX;
      double linearY = event.y - _gravityY;
      // We explicitly DO NOT calculate linearZ!

      // 4. Calculate magnitude ONLY on X and Y axes (Blinds the sensor to bed/table drops)
      // A drop on a flat surface is almost 100% Z-axis force. A human shake is X/Y axis force.
      final magnitude = sqrt(linearX * linearX + linearY * linearY);
      
      double threshold = 20.0; // medium (increased for release build speed)
      switch (shakeToSkipSensitivity.value) {
        case 'low':
          threshold = 30.0; // Hard shake
          break;
        case 'high':
          threshold = 14.0; // Light shake
          break;
      }

      if (magnitude > threshold) {
        final now = DateTime.now();
        
        // Debounce actual trigger
        if (now.difference(_lastShakeTime).inMilliseconds > 400) {
          _lastShakeTime = now;
          _shakeCount++;

          if (_shakeCount == 1) {
            _singleShakeTimer = Timer(const Duration(milliseconds: 600), () {
              if (_shakeCount == 1) {
                _triggerAction(isNext: true);
              }
            });
          } else if (_shakeCount == 2) {
            _singleShakeTimer?.cancel();
            _triggerAction(isNext: false);
          }
        }
      }
    });
  }

  void _triggerAction({required bool isNext}) {
    HapticFeedback.mediumImpact();
    
    if (isNext) {
      audioHandler.skipToNext();
    } else {
      audioHandler.skipToPrevious();
    }

    _shakeCount = 0;
    _inCooldown = true;
    
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(milliseconds: 1500), () {
      _inCooldown = false;
    });
  }

  void _stopListening() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _singleShakeTimer?.cancel();
    _cooldownTimer?.cancel();
    _shakeCount = 0;
    _inCooldown = false;
  }

  void dispose() {
    shakeToSkipEnabled.removeListener(_onSettingChanged);
    _stopListening();
  }
}
