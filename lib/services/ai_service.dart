import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'llm_ffi.dart';
import 'model_manager.dart';

typedef _TokenCallbackNativeFn = ffi.Void Function(
  ffi.Pointer<ffi.Char>,
  ffi.Int32,
);

class AIService {
  static final AIService _instance = AIService._();

  factory AIService() => _instance;

  AIService._();

  final _modelManager = ModelManager();

  Isolate? _workerIsolate;
  SendPort? _workerCommandPort;
  ReceivePort? _workerReceivePort;
  StreamSubscription<dynamic>? _workerSubscription;

  bool _isModelInitialized = false;
  String? _initializedModelName;
  bool _isGeneratingInWorker = false;
  int _requestId = 0;

  final Map<int, StreamController<String>> _generationControllers = {};
  final Map<int, Completer<void>> _initCompleters = {};

  bool get isInitialized => _isModelInitialized;

  Future<bool> hasModel(String modelName) => _modelManager.modelExists(modelName);

  Future<String?> getModelPath(String modelName) async {
    if (!await _modelManager.modelExists(modelName)) return null;
    return _modelManager.getModelPath(modelName);
  }

  Future<void> initialize({
    required String modelName,
    required String modelUrl,
    int nThreads = 4,
    void Function(int received, int total)? onProgress,
  }) async {
    if (isInitialized) {
      if (_initializedModelName == modelName) {
        print('[AIService] ✓ Already initialized with requested model');
        return;
      }

      print('[AIService] Switching model: $_initializedModelName -> $modelName');
      await _stopWorker();
    }

    print('[AIService] Initializing AI service...');
    print('[AIService]   Model: $modelName');
    print('[AIService]   Threads: $nThreads');

    var attemptedRecovery = false;

    while (true) {
      try {
        final modelExists = await _modelManager.modelExists(modelName);
        if (!modelExists) {
          print('[AIService] Model not found locally. Starting download...');
          print('[AIService] Source: $modelUrl');

          await _modelManager.downloadModel(
            modelName,
            modelUrl,
            onProgress: onProgress,
          );
        }

        final modelPath = await _modelManager.getModelPath(modelName);
        print('[AIService] Model path: $modelPath');

        await _ensureWorkerStarted();

        final initId = _nextRequestId();
        final initCompleter = Completer<void>();
        _initCompleters[initId] = initCompleter;

        _workerCommandPort!.send({
          'type': 'init',
          'id': initId,
          'modelPath': modelPath,
          'nThreads': nThreads,
        });

        await initCompleter.future;
        _isModelInitialized = true;
        _initializedModelName = modelName;
        print('[AIService] ✓ Initialization complete');
        return;
      } catch (e) {
        print('[AIService] ✗ Initialization failed: $e');
        _isModelInitialized = false;
        _initializedModelName = null;
        await _stopWorker();

        if (!attemptedRecovery) {
          attemptedRecovery = true;
          print('[AIService] Attempting recovery by deleting local model and re-downloading...');
          await _modelManager.deleteModel(modelName);
          continue;
        }

        rethrow;
      }
    }
  }

  Stream<String> sendMessage(
    String prompt, {
    int maxTokens = 256,
  }) async* {
    if (!isInitialized) {
      throw StateError(
        'AIService not initialized. Call await AIService().initialize() first.',
      );
    }

    if (prompt.isEmpty) {
      throw ArgumentError('Prompt cannot be empty');
    }

    if (maxTokens < 1) {
      throw ArgumentError('maxTokens must be >= 1');
    }

    if (_isGeneratingInWorker) {
      throw StateError('Generation already in progress');
    }

    final id = _nextRequestId();
    final controller = StreamController<String>(
      onCancel: () {
        _generationControllers.remove(id);
      },
    );

    _generationControllers[id] = controller;
    _isGeneratingInWorker = true;

    _workerCommandPort!.send({
      'type': 'generate',
      'id': id,
      'prompt': prompt,
      'maxTokens': maxTokens,
    });

    try {
      yield* controller.stream;
    } finally {
      _isGeneratingInWorker = false;
      _generationControllers.remove(id);
    }
  }

  void stopGenerating() {
    if (!_isGeneratingInWorker) return;
    _workerLlm.stopGeneration();
  }

  void dispose() {
    unawaited(_stopWorker());
  }

  int _nextRequestId() {
    _requestId += 1;
    return _requestId;
  }

  Future<void> _ensureWorkerStarted() async {
    if (_workerCommandPort != null) return;

    _workerReceivePort = ReceivePort();
    _workerIsolate = await Isolate.spawn(
      _workerMain,
      _workerReceivePort!.sendPort,
      errorsAreFatal: true,
      debugName: 'ai_service_worker',
    );

    final readyCompleter = Completer<void>();

    _workerSubscription = _workerReceivePort!.listen((dynamic message) {
      if (message is! Map) return;

      final type = message['type'] as String?;
      final id = message['id'] as int?;

      if (type == 'ready') {
        _workerCommandPort = message['sendPort'] as SendPort?;
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
        return;
      }

      if (type == 'init_ok' && id != null) {
        final initCompleter = _initCompleters.remove(id);
        if (initCompleter != null && !initCompleter.isCompleted) {
          initCompleter.complete();
        }
        return;
      }

      if (type == 'token' && id != null) {
        final controller = _generationControllers[id];
        if (controller != null && !controller.isClosed) {
          controller.add(message['token'] as String? ?? '');
        }
        return;
      }

      if (type == 'done' && id != null) {
        final controller = _generationControllers[id];
        if (controller != null && !controller.isClosed) {
          controller.close();
        }
        _generationControllers.remove(id);
        _isGeneratingInWorker = false;
        return;
      }

      if (type == 'error' && id != null) {
        final error = Exception(message['message'] as String? ?? 'Unknown worker error');

        final initCompleter = _initCompleters.remove(id);
        if (initCompleter != null && !initCompleter.isCompleted) {
          initCompleter.completeError(error);
          return;
        }

        final controller = _generationControllers[id];
        if (controller != null && !controller.isClosed) {
          controller.addError(error);
          controller.close();
        }
        _generationControllers.remove(id);
        _isGeneratingInWorker = false;
      }
    });

    await readyCompleter.future;
  }

  Future<void> _stopWorker() async {
    if (_workerCommandPort != null) {
      _workerCommandPort!.send({'type': 'dispose'});
    }

    for (final entry in _generationControllers.entries) {
      if (!entry.value.isClosed) {
        entry.value.addError(StateError('AI service disposed during generation'));
        await entry.value.close();
      }
    }
    _generationControllers.clear();

    for (final entry in _initCompleters.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          StateError('AI service disposed during initialization'),
        );
      }
    }
    _initCompleters.clear();

    await _workerSubscription?.cancel();
    _workerSubscription = null;

    _workerReceivePort?.close();
    _workerReceivePort = null;

    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerCommandPort = null;
    _isModelInitialized = false;
    _initializedModelName = null;
    _isGeneratingInWorker = false;
  }

  static SendPort? _workerEventPort;
  static int _workerActiveRequestId = -1;
  static final LlmFFI _workerLlm = LlmFFI();
  static ffi.Pointer<ffi.Void>? _workerContext;
  static bool _workerBusy = false;

  static void _workerTokenCallback(ffi.Pointer<ffi.Char> tokenPtr, int length) {
    if (_workerEventPort == null || length <= 0 || _workerActiveRequestId < 0) {
      return;
    }

    final bytes = tokenPtr.cast<ffi.Uint8>().asTypedList(length);
    final token = String.fromCharCodes(bytes);

    _workerEventPort!.send({
      'type': 'token',
      'id': _workerActiveRequestId,
      'token': token,
    });
  }

  static void _workerMain(SendPort hostSendPort) {
    final commandPort = ReceivePort();
    _workerEventPort = hostSendPort;

    hostSendPort.send({
      'type': 'ready',
      'sendPort': commandPort.sendPort,
    });

    commandPort.listen((dynamic message) {
      if (message is! Map) return;

      final type = message['type'] as String?;
      final id = message['id'] as int?;

      try {
        if (type == 'dispose') {
          if (_workerContext != null && _workerContext != ffi.nullptr) {
            _workerLlm.free(_workerContext!);
            _workerContext = null;
          }
          commandPort.close();
          return;
        }

        if (type == 'init' && id != null) {
          final modelPath = message['modelPath'] as String;
          final nThreads = message['nThreads'] as int;

          if (_workerContext != null && _workerContext != ffi.nullptr) {
            _workerLlm.free(_workerContext!);
            _workerContext = null;
          }

          _workerContext = _workerLlm.initModel(modelPath, nThreads: nThreads);
          hostSendPort.send({'type': 'init_ok', 'id': id});
          return;
        }

        if (type == 'generate' && id != null) {
          if (_workerBusy) {
            hostSendPort.send({
              'type': 'error',
              'id': id,
              'message': 'Model is busy generating another response',
            });
            return;
          }

          if (_workerContext == null || _workerContext == ffi.nullptr) {
            hostSendPort.send({
              'type': 'error',
              'id': id,
              'message': 'Model is not initialized',
            });
            return;
          }

          _workerBusy = true;
          _workerActiveRequestId = id;

          final prompt = message['prompt'] as String;
          final maxTokens = message['maxTokens'] as int;
          final callbackPtr = ffi.Pointer.fromFunction<_TokenCallbackNativeFn>(
            _workerTokenCallback,
          );

          _workerLlm.generate(_workerContext!, prompt, maxTokens, callbackPtr);

          _workerBusy = false;
          _workerActiveRequestId = -1;
          hostSendPort.send({'type': 'done', 'id': id});
          return;
        }
      } catch (e) {
        if (id != null) {
          hostSendPort.send({
            'type': 'error',
            'id': id,
            'message': e.toString(),
          });
        }
        _workerBusy = false;
        _workerActiveRequestId = -1;
      }
    });
  }
}
