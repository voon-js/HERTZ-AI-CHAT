# On-Device LLM Backend - Quick Start Guide

**Status**: Complete implementation ready to build  
**Target**: Android ARM64 only  
**Model**: Small quantized GGUF (2B–3B parameters)  
**Effort**: 30 mins setup → 5–30 mins first build → done  

---

## 🚀 Quick Start (5 Steps)

### Step 1: Install Android NDK

The Android NDK is required to compile native C/C++ code (llama.cpp).

**Option A: Through Android Studio (Easiest)**
```
1. Open Android Studio
2. Settings → SDK Manager
3. Click "SDK Tools" tab
4. Install "NDK (Side by side)" - pick v25.x or later
5. Copy the path shown (e.g., /path/to/Sdk/ndk/25.2.9519653)
```

**Option B: From Android Developer Site**
- Download from: https://developer.android.com/studio/projects/install-ndk
- Extract to Android SDK folder
- Add to `android/local.properties`: `ndk.dir=/path/to/ndk/25.2.9519653`

**Verify Installation:**
```bash
ls $NDK_HOME/toolchains/llvm/prebuilt/*/bin/aarch64-*
# Should show: clang, clang++, etc.
```

### Step 2: Clone llama.cpp

The llama.cpp source code is needed for compilation.

```bash
# Navigate to project
cd c:\HERTZ-AI-CHAT

# Clone llama.cpp
cd android/cpp
git clone https://github.com/ggerganov/llama.cpp.git

# Verify structure
ls -la llama.cpp/include/llama.h
# Should exist: include/llama.h, CMakeLists.txt, etc.
```

**If clone fails**: 
- Check internet connection
- Ensure git is installed: `git --version`
- Try HTTPS URL: `https://github.com/ggerganov/llama.cpp.git`

### Step 3: Get Dart Dependencies

```bash
cd c:\HERTZ-AI-CHAT
flutter clean
flutter pub get
```

### Step 4: Build Android App (Triggers Native Compilation)

```bash
# Build release APK (includes native compilation)
flutter build apk --release -v

# Or install directly to device
# flutter run --release -v

# Output paths:
# APK:        build/app/outputs/flutter-apk/app-release.apk
# Native lib: android/app/src/main/jniLibs/arm64-v8a/libllama_wrapper.so
```

**First build takes 10–30 minutes** (compiling llama.cpp for arm64-v8a)

Subsequent builds: 2–5 minutes

### Step 5: Download Model and Test

**Option A: Test with Dart**
```dart
import 'package:nothing_chat/services/ai_service.dart';

void testAI() async {
  final ai = AIService();
  
  // Initialize (first run: ~5-15 min download)
  await ai.initialize(
    modelName: 'tinyllama-1.1b.gguf',
    modelUrl: 'https://huggingface.co/TheBloke/'
        'TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/'
        'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    onProgress: (recv, total) => 
        print('Download: ${(recv/total*100).toStringAsFixed(1)}%'),
  );

  // Generate response
  print('Prompt: What is AI?');
  final stream = ai.sendMessage('What is AI?', maxTokens: 100);
  await for (final token in stream) {
    stdout.write(token);
  }
  
  ai.dispose();
}
```

**Option B: Test on Device**
```bash
# Device must be ARM64 with 6GB+ RAM
# Install built APK
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Run and check logs
adb logcat | grep -E "AIService|LlamaWrapper|FFI"
```

---

## 📁 File Structure (What Was Created)

```
c:\HERTZ-AI-CHAT\
├── lib/services/                    [NEW: AI Backend]
│   ├── ai_service.dart              ← Main public API
│   ├── llm_ffi.dart                 ← Dart↔C bindings
│   ├── model_manager.dart           ← Download & storage
│   ├── native_library_loader.dart   ← .so loading
│   └── example_usage.dart           ← Usage examples
│
├── android/cpp/                     [NEW: Native Code]
│   ├── CMakeLists.txt               ← Build config
│   ├── llama_wrapper.h              ← C API header
│   ├── llama_wrapper.cpp            ← Implementation
│   └── llama.cpp/                   ← Git submodule
│       └── [llama source code]
│
├── android/app/build.gradle.kts     [MODIFIED]
│   └── Added: NDK + CMake config
│
├── CMakeLists.txt                   [NEW: Root config]
├── pubspec.yaml                     [MODIFIED]
│   └── Added: http, path_provider, ffi
│
└── LLM_BACKEND_GUIDE.md             [NEW: Full docs]
```

---

## 🧪 Verify Everything Works

### 1. Check Native Library Built

```bash
# After successful build:
ls -lh android/app/src/main/jniLibs/arm64-v8a/

# You should see:
# libllama_wrapper.so        (1-5 MB)
# libllama.so                (5-20 MB - if separate)
# libc++_shared.so           (few MB)
```

If missing: Re-run `flutter build apk --release -v` with full verbosity.

### 2. Test FFI Loading

```dart
import 'package:nothing_chat/services/native_library_loader.dart';

void testLoading() {
  try {
    final lib = NativeLibraryLoader.library;
    print('✓ Native library loaded successfully');
  } catch (e) {
    print('✗ Failed: $e');
  }
}
```

### 3. Run Example

```dart
import 'package:nothing_chat/services/example_usage.dart';

// In main() or main widget:
// await exampleBasicUsage();
```

---

## ⚡ Performance Tuning

### Choose Right Model

| Model | Size | Q4 Speed | RAM | Devices |
|-------|------|----------|-----|---------|
| TinyLlama 1.1B | 600 MB | 8-12 t/s | 3-4 GB | Mid-range+ |
| Phi 3 Mini | 2.2 GB | 4-8 t/s | 4-5 GB | Mid-range+ |
| LLaMA 2 7B | 4 GB+ | 2-4 t/s | 8+ GB | Flagship+ |

**Recommendation**: Start with TinyLlama (fast, low RAM)

### Tune Thread Count

```dart
// Auto-detect CPU cores
import 'dart:io';
final cores = Platform.numberOfProcessors;

await ai.initialize(
  nThreads: (cores - 1).clamp(2, 8),  // Leave 1 for OS
  ...
);
```

### Adjust Token Limits

```dart
// Start conservative, increase as needed
ai.sendMessage('prompt', maxTokens: 64)  // Very short
ai.sendMessage('prompt', maxTokens: 256) // Normal
ai.sendMessage('prompt', maxTokens: 1024) // Long (risky on mobile)
```

---

## ❌ Common Issues & Fixes

### **Issue: "dlopen failed: cannot open shared object file"**

**Cause**: libllama_wrapper.so not built  
**Fix**:
```bash
flutter clean
flutter build apk --release -v

# Check build output for llama_wrapper compilation
# Should see: "Building llama_wrapper"

# If still missing, manual build:
cd android/cpp/build
cmake -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  ..
cmake --build . --release
```

### **Issue: "No such file or directory" after clone**

**Cause**: llama.cpp submodule not found  
**Fix**:
```bash
cd android/cpp
git clone https://github.com/ggerganov/llama.cpp.git
git log --oneline - llama.cpp | head -1
# Should show recent commit

# Verify key files exist:
ls llama.cpp/include/llama.h
ls llama.cpp/CMakeLists.txt
```

### **Issue: App crashes with SIGSEGV during init_model**

**Cause**: Low RAM, incompatible model, or corrupted model file  
**Fix**:
```dart
// Try smaller maxTokens
await ai.initialize(
  nThreads: 2,  // Reduce threads (less RAM)
  ...
);

// Or delete model and re-download
await ModelManager().deleteModel('tinyllama-1.1b.gguf');
// Then re-initialize (will re-download)
```

### **Issue: Generation never returns (infinite loop)**

**Cause**: Model too large, maxTokens too high, or device too slow  
**Fix**:
```dart
// Add timeout
try {
  final stream = ai.sendMessage(prompt, maxTokens: 32);
  await stream.timeout(Duration(minutes: 5)).toList();
} on TimeoutException {
  print('Generation timeout - model too slow for this device');
  ai.dispose();
}
```

### **Issue: CMake not found or cmake version mismatch**

**Cause**: Wrong CMake version in build.gradle.kts  
**Fix**: Update `android/app/build.gradle.kts`:
```gradle
externalNativeBuild {
    cmake {
        path = file("../CMakeLists.txt")
        version = "3.22.1"  // Try 3.23.0 or 3.24.0
    }
}
```

Or install CMake via Android Studio:
```
Settings → SDK Manager → SDK Tools → Install "CMake" (v3.22+)
```

### **Issue: "ABI mismatch" or app won't run**

**Cause**: App built for armeabi-v7a but libllama built for arm64-v8a  
**Fix**: Ensure only arm64-v8a is built:
```gradle
// android/app/build.gradle.kts
android {
    defaultConfig {
        ndk {
            abiFilters.add("arm64-v8a")  // ONLY this
            // Remove if you had: abiFilters.add("armeabi-v7a")
        }
    }
}
```

### **Issue: Download fails (HTTP error)**

**Cause**: Invalid URL, network error, or server down  
**Fix**:
```dart
// Verify URL in browser first
// Test with curl:
curl -L "https://huggingface.co/.../tinyllama-1.1b.gguf" -o test.gguf

// Check file size matches
// If > 500 MB, give generous timeout:
// Downloads can take 10+ minutes on slower connections
```

### **Issue: Out of memory (OOM) during init_model**

**Cause**: Device has < 4 GB RAM available  
**Fix**:
```dart
// Use smaller model
// Or reduce context window in C code (currently 2048, reduce to 1024)

// Edit android/cpp/llama_wrapper.cpp, line ~150:
// ctx_params.n_ctx = 1024;  // Instead of 2048

// Rebuild:
flutter clean && flutter build apk --release
```

---

## 📚 API Reference (Quick)

### Main Class: `AIService`

```dart
// Singleton
final ai = AIService();

// Initialize (first run: download model)
await ai.initialize(
  modelName: 'model.gguf',
  modelUrl: 'https://...',
  nThreads: 4,
  onProgress: (recv, total) {},
);

// Check status
bool ready = ai.isInitialized;

// Generate streaming response
Stream<String> response = ai.sendMessage(
  'Prompt text',
  maxTokens: 256,
);

// Listen
await for (final token in response) {
  print(token);
}

// Cleanup
ai.dispose();
```

### Model Manager: `ModelManager`

```dart
final mm = ModelManager();

// Check model exists
bool exists = await mm.modelExists('model.gguf');

// Get path
String path = await mm.getModelPath('model.gguf');

// Download
await mm.downloadModel('model.gguf', 'https://...',
  onProgress: (recv, total) {},
);

// Delete
await mm.deleteModel('model.gguf');

// List all
List<String> models = await mm.listModels();

// Get total size
int totalBytes = await mm.getTotalModelSize();
```

---

## 🔗 Resources

- **llama.cpp**: https://github.com/ggerganov/llama.cpp
- **Models (HuggingFace)**: https://huggingface.co/TheBloke/ (search GGUF)
- **Android NDK**: https://developer.android.com/ndk
- **Dart FFI**: https://dart.dev/guides/libraries/c-interop

---

## ✅ Next Steps

1. **Complete Quick Start Steps 1–5 above** (30 mins)
2. **Run basic test** (verify it compiles)
3. **Integrate into chat UI** (use `AIService.sendMessage()`)
4. **Tune performance** (adjust threads, tokens, model)
5. **Ship to production** ✨

---

**Questions?** Check `LLM_BACKEND_GUIDE.md` for comprehensive documentation.
