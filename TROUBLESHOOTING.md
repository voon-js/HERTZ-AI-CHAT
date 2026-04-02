# Troubleshooting & Debugging Guide

Complete reference for diagnosing and fixing issues with the on-device LLM backend.

---

## 🔍 Diagnostic Workflow

### 1. Check Build Success

```bash
# Clean and rebuild with full verbosity
flutter clean
flutter build apk --release -v 2>&1 | tee build.log

# Search for key terms:
grep -i "llama\|cmake\|ndk\|error" build.log

# Look for:
# ✓ "[Gradle] Building llama_wrapper"
# ✓ "libllama_wrapper.so" in output paths
# ✗ "CMake Error", "undefined reference", "abiFilters"
```

### 2. Check Native Library Loaded

```bash
# On device, check logcat
adb logcat | grep -E "FFI|LlamaWrapper|dlopen"

# Should see:
# "[FFI] ✓ Successfully loaded libllama_wrapper.so"

# If not, check:
adb shell ls -la /data/app/com.example.aichat*/lib/arm64-v8a/

# Should show:
# libllama_wrapper.so (1-5 MB)
# libllama.so (10-20 MB, if separate)
```

### 3. Check Model Downloaded

```dart
import 'package:nothing_chat/services/model_manager.dart';

void checkModel() async {
  final mm = ModelManager();
  final exists = await mm.modelExists('model.gguf');
  final path = await mm.getModelPath('model.gguf');
  
  print('Exists: $exists');
  print('Path: $path');
  
  if (exists) {
    final file = File(path);
    print('Size: ${await file.length()} bytes');
  }
}
```

---

## 🐛 Build Issues

### CMake Not Found

**Error:**
```
CMake version not on a PATH.
```

**Solution:**
```bash
# Option 1: Install via Android Studio
# Settings → SDK Manager → SDK Tools → Install "CMake"

# Option 2: Verify cmake in PATH
which cmake
cmake --version

# Option 3: Specify explicitly in build.gradle.kts
// In android folder, create local.properties:
cmake.dir=/path/to/cmake

# Option 4: Update CMake version in build.gradle.kts
externalNativeBuild {
    cmake {
        path = file("../CMakeLists.txt")
        version = "3.24.0"  // Try different version
    }
}
```

### llama.cpp Not Found

**Error:**
```
CMakeLists.txt:XX: target 'llama' - not found
android/cpp/CMakeLists.txt:XX: llama.cpp/CMakeLists.txt not found
```

**Solution:**
```bash
# Verify llama.cpp exists
ls -la android/cpp/llama.cpp/

# If empty or missing:
cd android/cpp
rm -rf llama.cpp  # Clean up failed clone
git clone https://github.com/ggerganov/llama.cpp.git

# Verify critical files
ls llama.cpp/include/llama.h
ls llama.cpp/CMakeLists.txt
ls llama.cpp/common.h

# If git clone hangs, use shallow clone:
git clone --depth 1 https://github.com/ggerganov/llama.cpp.git

# Verify clone worked
cd llama.cpp && git log --oneline -1 && cd ..
```

### NDK Not Found

**Error:**
```
NDK not configured for this project
Unable to get default NDK path
```

**Solution:**
```bash
# Create android/local.properties:
# Find your NDK installation
# macOS/Linux:
ls ~/Library/Android/Sdk/ndk/  # macOS
ls ~/Android/Sdk/ndk/           # Linux

# Windows:
dir "%AppData%\..\Local\Android\Sdk\ndk\"

# Copy full path as:
# ndk.dir=/path/to/ndk/25.2.9519653

# Also set in environment:
export ANDROID_NDK_HOME=/path/to/ndk/25.2.9519653

# Or via gradle.properties:
echo "ndk.version=25.2.9519653" >> gradle.properties
```

### Gradle Compilation Error

**Error:**
```
undefined reference to `llama_init_model'
undefined reference to `__android_log_print'
```

**Solution:**
- Missing `android/log.h` include
- Fix: Already included in llama_wrapper.cpp header

**If error persists:**
```cpp
// Verify llama_wrapper.cpp starts with:
#include "llama.cpp/include/llama.h"
#include <android/log.h>

// Check CMakeLists.txt links log:
target_link_libraries(llama_wrapper PRIVATE
    llama  # llama.cpp
    log    # Android logging
)
```

---

## 🎯 FFI & Runtime Issues

### dlopen Failed - Library Not Found

**Error:**
```
DynamicLibrary.open('libllama_wrapper.so'): dlopen failed
```

**Diagnosis:**
```bash
# Check if library was built
flutter build apk --release -v | grep -i "llama_wrapper"

# Manually check built APK
cd build/app/outputs/flutter-apk
unzip app-release.apk -d apk_contents
ls -la apk_contents/lib/arm64-v8a/

# Should show:
# libllama_wrapper.so
# libflutter.so
# libapp.so
# libc++_shared.so
```

**Fix Options:**

1. **Rebuild with NDK**
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release -v
   ```

2. **Verify NDK installed**
   ```bash
   sdkmanager "ndk;25.2.9519653"
   ```

3. **Manually compile**
   ```bash
   cd android/cpp
   mkdir -p build/arm64-v8a && cd build/arm64-v8a
   cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
     -DANDROID_ABI=arm64-v8a \
     -DANDROID_PLATFORM=android-21 \
     -DCMAKE_BUILD_TYPE=Release \
     ../..
   cmake --build .
   ```

### ABI Mismatch

**Error:**
```
CANNOT LINK EXECUTABLE: cannot locate symbol "__cxa_new_handler"
Referenced by: /data/data/com.app/lib/libllama_wrapper.so
```

**Cause**: Library compiled for armeabi-v7a but app built for arm64-v8a

**Fix**:
```gradle
// android/app/build.gradle.kts
android {
    defaultConfig {
        ndk {
            abiFilters.add("arm64-v8a")  // MUST be arm64-v8a
            // abiFilters.add("armeabi-v7a")  // Remove if present
        }
    }
}

// Clean and rebuild
flutter clean
flutter build apk --release
```

### Symbol Not Found at Runtime

**Error:**
```
Failed to load native library: dlopen failed:
undefined symbol: llama_init_model
```

**Cause**: Function not exported from library

**Fix**: Check llama_wrapper.cpp uses `extern "C"`:
```cpp
extern "C" {

LlamaContext llama_init_model(...) {
  // implementation
}

void llama_free(LlamaContext ctx) {
  // implementation
}

} // extern "C"
```

If still not working:
```bash
# Check if symbol is exported
arm64-android-nm android/app/src/main/jniLibs/arm64-v8a/libllama_wrapper.so | grep llama_init_model

# Should show:
# 0000... T llama_init_model
```

---

## 💾 Memory & Performance Issues

### App Crashes on Model Init (SIGSEGV, SIGABRT)

**Cause**: Out of memory or insufficient RAM

**Diagnosis:**
```bash
# Check device RAM
adb shell cat /proc/meminfo

# Monitor during init
adb shell while true; do ps -aux | grep -E "^$(adb shell id -u|tr -d ' '):"; sleep 1; done
```

**Fixes**:

1. **Reduce context window size**: Edit `android/cpp/llama_wrapper.cpp` (~line 140):
   ```cpp
   ctx_params.n_ctx = 1024;  // From 2048
   ```
   Then rebuild.

2. **Use lower sequence length**:
   ```dart
   ai.sendMessage(prompt, maxTokens: 64)  // Reduced
   ```

3. **Reduce thread count**:
   ```dart
   await ai.initialize(nThreads: 2)  // From 4
   ```

4. **Use smaller model**: Switch to TinyLlama 1.1B (Q4)

5. **Check available RAM beforehand**:
   ```dart
   import 'dartio' show Platform;
   print('Available processors: ${Platform.numberOfProcessors}');
   ```

### Generation Takes Forever

**Cause**: Device too slow, maxTokens too high, or model too large

**Diagnosis**:
```bash
# Monitor CPU during generation
adb shell top -d 1 | grep com.example.aichat

# Check CPU usage should be high (80%+)
# If low, check threading
```

**Fixes**:

1. **Reduce token count**:
   ```dart
   ai.sendMessage(prompt, maxTokens: 32)  // Much lower
   ```

2. **Increase threads** (if available CPU):
   ```dart
   await ai.initialize(nThreads: 6)  // From 4
   ```

3. **Use smaller quantization**: Q4_K_M → Q3_K_S
   (requires re-downloading model)

4. **Add timeout to prevent hanging**:
   ```dart
   try {
     final stream = ai.sendMessage(prompt, maxTokens: 100);
     await stream.timeout(Duration(minutes: 2));
   } on TimeoutException {
     print('Generation too slow for this device');
   }
   ```

### High Memory Usage Between Generations

**Cause**: Model context not freed

**Check**: After each generation, call `ai.dispose()`:
```dart
final stream = ai.sendMessage(prompt);
await for (final token in stream) { ... }
ai.dispose();  // Must call this!
```

---

## 🔌 Model Download Issues

### Download Never Completes

**Cause**: Network issue, server error, or file too large

**Debug**:
```dart
// Add detailed logging
await ModelManager().downloadModel(
  'model.gguf',
  'https://...',
  onProgress: (recv, total) {
    print('$recv / $total  (${(recv/total*100).toStringAsFixed(1)}%)');
    if (recv == total) print('COMPLETE');
  },
);
```

**Fix**:
```bash
# Test download with curl first
curl -L -o test.gguf "https://..." -C -  # Resume if interrupted

# Check file size
ls -lh test.gguf | awk '{print $5}'

# If incomplete, resume:
curl -L -C - -o test.gguf "https://..."
```

### Download Fails with 404 or 403

**Error**:
```
HTTP 404: Not found
HTTP 403: Forbidden
```

**Fix**:
```bash
# Verify URL is correct
# Test in browser first

# Common issue: HuggingFace URLs need ?download=true
# Correct URL format:
curl -L "https://huggingface.co/TheBloke/.../resolve/main/model.gguf" -o model.gguf

# If still fails, login to HuggingFace:
curl -H "Authorization: Bearer $HF_TOKEN" "https://huggingface.co/.../resolve/main/model.gguf" -o model.gguf
```

### Model File Corrupted After Download

**Symptom**:
```
"Failed to load model: Invalid GGUF file format"
or
"llama_load_model_from_file failed"
```

**Fix**:
```dart
// Delete corrupted file and re-download
await ModelManager().deleteModel('model.gguf');

// Re-download (automatic on next init)
await ai.initialize(modelName: 'model.gguf', modelUrl: '...');

// Or manually verify:
adb shell file /data/data/com.app/app_flutter/models/model.gguf
# Should output: "GGUF format, version 3"
```

### Download Interrupted (No Resume)

**Note**: Current implementation doesn't resume partial downloads

**Workaround**:
```dart
// Delete partial file
await ModelManager().deleteModel('model.gguf');

// Retry (will re-download fresh)
await ai.initialize(modelName: '...', modelUrl: '...');
```

---

## 📱 Device-Specific Issues

### Works on Emulator, Fails on Device

**Cause**: Emulator is x86_64, device is arm64-v8a

**Fix**: Only test on real ARM64 device
```gradle
// Ensure only arm64 is built:
ndk {
    abiFilters.add("arm64-v8a")
}
```

### Works on Flagship, Fails on Mid-Range

**Cause**: Mid-range device has less RAM or slower CPU

**Solutions**:
1. Reduce model size (use 1.1B instead of 3B)
2. Use more aggressive quantization (Q3_K_S)
3. Reduce context window (1024 instead of 2048)
4. Reduce maxTokens (32-64 instead of 256)

### Works on Android 12, Fails on Android 10

**Cause**: Scoped storage or permission issue

**Check**:
```bash
# Verify app has file write permission
adb shell am dump-heap com.example.aichat /data/data/com.example.aichat/model.gguf

# Check app storage directory
adb shell ls -la /data/data/com.example.aichat/app_flutter/models/
```

**Fix in AndroidManifest.xml** (if needed):
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

---

## 🔬 Advanced Debugging

### Enable Native Logging

In `android/cpp/llama_wrapper.cpp`, ensure logging macros are used:
```cpp
LOGI("Model loaded");  // Visible in logcat
LOGE("Error: %s", error_msg);  // Error level
LOGD("Debug info");    // Debug level (only if debuggable)
```

### View Logcat in Real-Time

```bash
# Watch native logs
adb logcat | grep -E "LlamaWrapper|FFI|llama"

# Save to file
adb logcat > logcat.txt &

# Filter by PID
PID=$(adb shell pidof com.example.aichat)
adb logcat --pid=$PID
```

### Compare File MD5 (Model Integrity)

```bash
# Download model and check hash
curl -L "https://..." -o model.gguf
md5sum model.gguf

# HuggingFace usually provides hash on model page
# Or calculate on remote file:
curl -L "https://..." | md5sum
```

### Profile CPU Usage

```bash
# During generation:
adb shell "top -n 1 -o %CPU,%MEM,NAME | grep -E 'CPU|aichat'"

# Or use Android Profiler in Android Studio:
# Run app → View → Tool Windows → Profiler
```

### Check Native Crash (ANR)

```bash
# If app crashes, check tombstone
adb bugreport bugreport.zip
unzip bugreport.zip
cat */logs/tombstone_*.txt | head -50

# Look for:
# - "signal", "signum" (crash type)
# - "backtrace" (call stack)
```

---

## ✅ Debugging Checklist

- [ ] `flutter clean && flutter pub get` - Fresh state
- [ ] `flutter build apk --release -v` - Check for build errors
- [ ] Verify `.so` file exists in `jniLibs/arm64-v8a/`
- [ ] Check device is ARM64: `adb shell getprop ro.product.cpu.abi`
- [ ] Test `DynamicLibrary.open('libllama_wrapper.so')` separately
- [ ] Verify model file exists and is readable
- [ ] Test model download independently (curl)
- [ ] Monitor device RAM during initialization
- [ ] Add timeouts to prevent hangs
- [ ] Check logcat for exact error messages
- [ ] Reduce complexity (smaller model, fewer tokens)
- [ ] Test on real device (not emulator)

---

## 📞 Getting Help

1. **Check logcat**: `adb logcat | grep -E "Error|Exception|LlamaWrapper"`
2. **Read full guide**: See `LLM_BACKEND_GUIDE.md`
3. **Search llama.cpp issues**: https://github.com/ggerganov/llama.cpp/issues
4. **Dart FFI docs**: https://dart.dev/guides/libraries/c-interop

