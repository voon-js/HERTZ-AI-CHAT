import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'notification_service.dart';

/// Manages model file lifecycle: download, storage, existence checks
class ModelManager {
  static final ModelManager _instance = ModelManager._();

  factory ModelManager() => _instance;

  ModelManager._();

  final NotificationService _notificationService = NotificationService();
  bool _shouldCancelDownloads = false;
  int _activeDownloadCount = 0;

  /// Check if model exists and is readable
  /// 
  /// [modelName] Filename for the model (e.g., "tinyllama-1.1b.gguf")
  /// 
  /// Returns true if file exists and has size > 0
  Future<bool> modelExists(String modelName) async {
    try {
      final file = await _getModelFile(modelName);
      final exists = file.existsSync();
      if (exists) {
        final size = await file.length();
        print('[ModelManager] ✓ Model exists: ${file.path} ($size bytes)');
        return true;
      }
      print('[ModelManager] ✗ Model not found: ${file.path}');
      return false;
    } catch (e) {
      print('[ModelManager] Error checking model: $e');
      return false;
    }
  }

  /// Get full file path for model
  /// 
  /// Creates models directory if it doesn't exist.
  /// 
  /// Returns absolute path to model file (may not exist yet)
  Future<String> getModelPath(String modelName) async {
    final file = await _getModelFile(modelName);
    return file.path;
  }

  /// Download model from URL to local storage
  /// 
  /// [modelName] Filename (determines storage location)
  /// [url] Full HTTPS URL to download from
  /// [onProgress] Optional callback: (bytesReceived, totalBytes)
  /// 
  /// Throws if download fails. Does NOT re-download if file exists.
  /// 
  /// Example:
  /// ```dart
  /// await modelManager.downloadModel(
  ///   'tinyllama.gguf',
  ///   'https://huggingface.co/.../resolve/main/tinyllama.gguf',
  ///   onProgress: (received, total) {
  ///     print('${(received/total*100).toStringAsFixed(1)}%');
  ///   },
  /// );
  /// ```
  Future<void> downloadModel(
    String modelName,
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final file = await _getModelFile(modelName);
    final partialFile = File('${file.path}.part');

    if (partialFile.existsSync()) {
      partialFile.deleteSync();
      print('[ModelManager] Removed stale partial download: ${partialFile.path}');
    }

    // Skip if already exists
    if (file.existsSync()) {
      final size = await file.length();
      print('[ModelManager] ✓ Model already exists: ${file.path} ($size bytes)');
      return;
    }

    print('[ModelManager] Starting download from: $url');

    try {
      await _beginDownloadSession();

      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: Failed to download model from $url');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      int? lastNotifiedPercent;

      // Download to a temporary file first, then rename atomically.
      final sink = partialFile.openWrite();

      await _notificationService.showDownloadProgress(
        modelName: modelName,
        received: 0,
        total: total,
      );

      try {
        await for (final chunk in response.stream) {
          // Check if download was cancelled
          if (_shouldCancelDownloads) {
            await sink.close();
            if (partialFile.existsSync()) {
              partialFile.deleteSync();
            }
            throw Exception('Download cancelled by user');
          }

          received += chunk.length;
          onProgress?.call(received, total);
          sink.add(chunk);

          if (total > 0) {
            final percent = ((received / total) * 100).clamp(0, 100).round();
            if (lastNotifiedPercent == null || percent != lastNotifiedPercent) {
              lastNotifiedPercent = percent;
              await _notificationService.showDownloadProgress(
                modelName: modelName,
                received: received,
                total: total,
              );
            }
          } else {
            await _notificationService.showDownloadProgress(
              modelName: modelName,
              received: received,
              total: total,
            );
          }

          // Log progress every 10%
          if (total > 0 && received % (total ~/ 10 + 1) == 0) {
            final pct = (received / total * 100).toStringAsFixed(1);
            print('[ModelManager] Download progress: $pct%');
          }
        }

        await sink.close();
        if (file.existsSync()) {
          file.deleteSync();
        }
        partialFile.renameSync(file.path);

        await _notificationService.showDownloadCompleted(modelName);

        print('[ModelManager] ✓ Download complete: ${file.path}');
        print('[ModelManager]   Size: ${await file.length()} bytes');
      } catch (e) {
        await sink.close();
        if (partialFile.existsSync()) {
          partialFile.deleteSync();
        }
        rethrow;
      }
    } catch (e) {
      print('[ModelManager] ✗ Download failed: $e');
      if (!e.toString().contains('cancelled')) {
        await _notificationService.showDownloadFailed(modelName);
      }
      rethrow;
    } finally {
      await _endDownloadSession();
    }
  }

  Future<void> _beginDownloadSession() async {
    _activeDownloadCount++;
    if (_activeDownloadCount == 1) {
      await WakelockPlus.enable();
    }
  }

  Future<void> _endDownloadSession() async {
    if (_activeDownloadCount > 0) {
      _activeDownloadCount--;
    }
    if (_activeDownloadCount == 0) {
      await WakelockPlus.disable();
    }
  }

  /// Request cancellation of all active downloads
  void requestCancelDownloads() {
    _shouldCancelDownloads = true;
  }

  /// Clear cancellation state for next download session
  void clearCancellationState() {
    _shouldCancelDownloads = false;
  }

  /// Cancel all active downloads and clean up partial files
  Future<void> cancelAllDownloads() async {
    _shouldCancelDownloads = true;
    
    // Give a moment for the download loop to exit
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Clean up all partial files
    try {
      final dir = await _getModelsDirectory();
      final files = dir.listSync();
      for (final file in files) {
        if (file.path.endsWith('.part')) {
          File(file.path).deleteSync();
          print('[ModelManager] Cleaned up partial file: ${file.path}');
        }
      }
    } catch (e) {
      print('[ModelManager] Error cleaning up partial files: $e');
    }
  }

  /// Delete model file from storage
  Future<void> deleteModel(String modelName) async {
    try {
      final file = await _getModelFile(modelName);
      if (file.existsSync()) {
        file.deleteSync();
        print('[ModelManager] ✓ Deleted model: ${file.path}');
      }

      final partialFile = File('${file.path}.part');
      if (partialFile.existsSync()) {
        partialFile.deleteSync();
        print('[ModelManager] ✓ Deleted partial model: ${partialFile.path}');
      }
    } catch (e) {
      print('[ModelManager] Error deleting model: $e');
    }
  }

  /// Get list of downloaded models
  Future<List<String>> listModels() async {
    try {
      final modelsDir = await _getModelsDirectory();
      if (!modelsDir.existsSync()) return [];

      final files = modelsDir.listSync();
      final models = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.gguf'))
          .map((f) => f.path.split('/').last)
          .toList();

      print('[ModelManager] Found ${models.length} models');
      return models;
    } catch (e) {
      print('[ModelManager] Error listing models: $e');
      return [];
    }
  }

  /// Get total size of all downloaded models
  Future<int> getTotalModelSize() async {
    int total = 0;
    try {
      final models = await listModels();
      for (final name in models) {
        final file = await _getModelFile(name);
        if (file.existsSync()) {
          total += await file.length();
        }
      }
    } catch (e) {
      print('[ModelManager] Error calculating total size: $e');
    }
    return total;
  }

  /// Get or create models directory
  Future<Directory> _getModelsDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory('${appDir.path}/models');

    if (!modelsDir.existsSync()) {
      modelsDir.createSync(recursive: true);
      print('[ModelManager] Created models directory: ${modelsDir.path}');
    }

    return modelsDir;
  }

  /// Get model file reference (may not exist)
  Future<File> _getModelFile(String modelName) async {
    final modelsDir = await _getModelsDirectory();
    return File('${modelsDir.path}/$modelName');
  }
}
