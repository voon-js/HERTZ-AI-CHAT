import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart' as ffi_pkg;
import 'native_library_loader.dart';

/// FFI type definitions for C functions
/// These match the C function signatures in llama_wrapper.h

// === Init Model ===
typedef InitModelNative = ffi.Pointer<ffi.Void> Function(
  ffi.Pointer<ffi_pkg.Utf8> modelPath,
  ffi.Int32 nThreads,
);

typedef InitModelDart = ffi.Pointer<ffi.Void> Function(
  ffi.Pointer<ffi_pkg.Utf8> modelPath,
  int nThreads,
);

// === Token Callback ===
/// Called for each generated token from native code
typedef TokenCallbackNative = ffi.Void Function(
  ffi.Pointer<ffi.Char> token,
  ffi.Int32 length,
);

// === Generate ===
typedef GenerateNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void> ctx,
  ffi.Pointer<ffi_pkg.Utf8> prompt,
  ffi.Int32 maxTokens,
  ffi.Pointer<ffi.NativeFunction<TokenCallbackNative>> callback,
);

typedef GenerateDart = int Function(
  ffi.Pointer<ffi.Void> ctx,
  ffi.Pointer<ffi_pkg.Utf8> prompt,
  int maxTokens,
  ffi.Pointer<ffi.NativeFunction<TokenCallbackNative>> callback,
);

// === Free ===
typedef FreeNative = ffi.Void Function(ffi.Pointer<ffi.Void> ctx);

typedef FreeDart = void Function(ffi.Pointer<ffi.Void> ctx);

// === Get Error ===
typedef GetErrorNative = ffi.Pointer<ffi_pkg.Utf8> Function();

typedef GetErrorDart = ffi.Pointer<ffi_pkg.Utf8> Function();

/// Low-level FFI interface to native llama wrapper
/// 
/// This class provides direct bindings to the C API.
/// For typical use, see [AIService] which wraps this with higher-level abstractions.
class LlmFFI {
  static final LlmFFI _instance = LlmFFI._();

  factory LlmFFI() => _instance;

  LlmFFI._();

  // Function pointers (resolved lazily)
  late final InitModelDart _initModel;
  late final GenerateDart _generate;
  late final FreeDart _free;
  late final GetErrorDart _getError;

  bool _initialized = false;

  /// Ensure all function pointers are resolved
  void _ensureInitialized() {
    if (_initialized) return;

    final lib = NativeLibraryLoader.library;

    // Load and cast function pointers
    _initModel = lib
        .lookup<ffi.NativeFunction<InitModelNative>>('llama_init_model')
        .asFunction();

    _generate = lib
        .lookup<ffi.NativeFunction<GenerateNative>>('llama_generate')
        .asFunction();

    _free =
      lib.lookup<ffi.NativeFunction<FreeNative>>('llama_free_context').asFunction();

    _getError = lib
        .lookup<ffi.NativeFunction<GetErrorNative>>('llama_get_error')
        .asFunction();

    _initialized = true;
    print('[LlmFFI] All function pointers resolved');
  }

  /// Initialize model from file path
  /// 
  /// [modelPath] Full path to GGUF file
  /// [nThreads] CPU threads for inference (typically cores - 1)
  /// 
  /// Returns opaque model context handle, or throws if initialization fails
  ffi.Pointer<ffi.Void> initModel(String modelPath, {int nThreads = 4}) {
    _ensureInitialized();
    
    final pathPtr = modelPath.toNativeUtf8();
    try {
      final ctx = _initModel(pathPtr, nThreads);
      
      if (ctx == ffi.nullptr) {
        throw Exception('Native init_model returned NULL: ${getError()}');
      }
      
      print('[LlmFFI] Model initialized. Context: $ctx, Threads: $nThreads');
      return ctx;
    } finally {
      ffi_pkg.malloc.free(pathPtr);
    }
  }

  /// Generate tokens with streaming callback
  /// 
  /// Blocks until generation complete or max tokens reached.
  /// 
  /// [ctx] Context from initModel()
  /// [prompt] Input text to generate from
  /// [maxTokens] Maximum tokens to generate
  /// [callback] Function pointer called for each token
  /// 
  /// Returns 0 on success, -1 on error
  int generate(
    ffi.Pointer<ffi.Void> ctx,
    String prompt,
    int maxTokens,
    ffi.Pointer<ffi.NativeFunction<TokenCallbackNative>> callback,
  ) {
    _ensureInitialized();
    
    final promptPtr = prompt.toNativeUtf8();
    try {
      print('[LlmFFI] Generate: maxTokens=$maxTokens, prompt="${prompt.substring(0, min(50, prompt.length))}"');
      final result = _generate(ctx, promptPtr, maxTokens, callback);
      
      if (result != 0) {
        throw Exception('Generate failed: ${getError()}');
      }
      
      print('[LlmFFI] Generation complete');
      return result;
    } finally {
      ffi_pkg.malloc.free(promptPtr);
    }
  }

  /// Free model context and all resources
  void free(ffi.Pointer<ffi.Void> ctx) {
    _ensureInitialized();
    print('[LlmFFI] Freeing model context: $ctx');
    _free(ctx);
  }

  /// Get most recent error message from native layer
  String getError() {
    _ensureInitialized();
    try {
      final ptr = _getError();
        return ptr == ffi.nullptr
          ? 'Unknown error'
          : ffi_pkg.Utf8Pointer(ptr).toDartString();
    } catch (e) {
      return 'Error retrieving error message: $e';
    }
  }
}

/// Utility: return smaller of two values (for text preview)
int min(int a, int b) => a < b ? a : b;
