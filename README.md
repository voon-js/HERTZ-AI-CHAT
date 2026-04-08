# Hertz - On-Device AI Chat (Flutter + llama.cpp)

A local-first AI chat application built with Flutter and a native llama.cpp backend (via Dart FFI), focused on privacy, responsive chat UX, and practical mobile stability controls.

## Project Summary

This project demonstrates production-oriented app engineering by combining:
- Cross-platform Flutter UI architecture (chat, settings, overlays, model flow)
- Native C/C++ inference integration with llama.cpp using Dart FFI
- Streaming token generation with isolate-safe cancellation behavior
- Attachment ingestion pipeline (OCR + document extraction) with safety guards
- Persistent generation tuning for practical on-device inference control

The app is branded as Hertz and is designed as an offline-capable chat experience after model download.

## Engineering Skills Demonstrated

### 1. Native AI Runtime Integration
- Dart-to-C bindings through FFI in lib/services/llm_ffi.dart
- Native wrapper layer in android/cpp/llama_wrapper.cpp and android/cpp/llama_wrapper.h
- CMake/NDK integration for Android native build pipeline

### 2. Real-Time Streaming and Control
- Token-by-token response streaming in lib/services/ai_service.dart
- Immediate stop-generation handling through isolate message routing
- Defensive lifecycle handling for long-running generation streams

### 3. Context Safety and Prompt Budgeting
- Two-tier context risk checks in lib/pages/chat_page.dart
- Current prompt warning and total-context warning behavior
- Session-only suppression option for repeat context-full warnings

### 4. Attachment Intelligence Pipeline
- OCR via ML Kit for image attachments
- File text extraction with timeout/isolate protection
- Prompt assembly controls with truncation limits and stability-first behavior

### 5. Stateful UX and App Reliability
- Persistent generation settings with SharedPreferences
- Model management and first-load experience
- Multi-platform shell support (Android/iOS/web/desktop)

## Technical Highlights

- Framework: Flutter (Dart)
- Native Backend: llama.cpp (C/C++)
- Interop: Dart FFI
- Mobile Native Toolchain: Android NDK + CMake
- Key Flutter Packages:
  - shared_preferences
  - image_picker
  - file_picker
  - google_mlkit_text_recognition
  - extract_text
  - syncfusion_flutter_pdf
  - ffi
  - http

## Repository Structure

- lib/main.dart - app entry, theme, shell navigation
- lib/pages/chat_page.dart - main chat flow, context checks, attachment handling
- lib/pages/generation_settings_page.dart - generation tuning UI
- lib/services/ai_service.dart - streaming generation service and orchestration
- lib/services/generation_settings.dart - persisted generation settings
- lib/services/model_manager.dart - model download/storage management
- lib/services/llm_ffi.dart - FFI bindings to native inference APIs
- android/cpp/llama_wrapper.cpp - native llama.cpp wrapper implementation
- android/cpp/CMakeLists.txt - native build configuration

## How to Run

1. Install Flutter SDK and Android toolchain (Android Studio + NDK).
2. Clone llama.cpp into android/cpp/llama.cpp (if not present).
3. Install dependencies:
	- flutter pub get
4. Build and run:
	- flutter build apk --release
5. Launch Hertz, download/select a model, then start chatting.

## Current Runtime Notes

- On-device inference backend is implemented for Android ARM64.
- Context/stability warnings are tuned in-app for mobile reliability.
- Generation controls are persisted across app restarts.

## Why This Project Matters

Hertz reflects practical AI app engineering: local-first privacy, native inference integration, robust prompt/context handling, and UX decisions that prioritize real-world device stability over demo-only behavior.

---

If you are reviewing this repository for engineering capability, focus on the FFI-native inference bridge, streaming/cancellation flow, and the context safety logic in the chat pipeline.
