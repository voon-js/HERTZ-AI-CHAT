import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Manages loading of native llama.cpp wrapper library
class NativeLibraryLoader {
  static ffi.DynamicLibrary? _library;

  /// Load native library dynamically
  /// 
  /// On Android, looks for libllama_wrapper.so in app's lib directory
  /// This is automatically set up by Flutter's build system from android/jniLibs
  static ffi.DynamicLibrary get library {
    if (_library != null) return _library!;

    if (!Platform.isAndroid) {
      throw UnsupportedError(
          'On-device LLM backend only supports Android ARM64. '
          'Current platform: ${Platform.operatingSystem}');
    }

    try {
      // DynamicLibrary.open() uses the standard system library search path
      // On Android, this includes the app's jniLibs/arm64-v8a directory
      _library = ffi.DynamicLibrary.open('libllama_wrapper.so');
      debugPrint('[FFI] ✓ Successfully loaded libllama_wrapper.so');
    } catch (e) {
      throw Exception(
          'Failed to load native library: $e\n'
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
          'Ensure libllama_wrapper.so is in:\n'
          '  android/app/src/main/jniLibs/arm64-v8a/\n'
          '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
          'This is built automatically by CMake when you run:\n'
          '  flutter build apk --release\n');
    }

    return _library!;
  }

  /// Explicit unload (rarely needed)
  static void unload() {
    _library = null;
    debugPrint('[FFI] Native library unloaded');
  }
}
