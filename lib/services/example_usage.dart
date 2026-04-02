// lib/services/example_usage.dart
// This file demonstrates how to use the AIService

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';

/// Example: Initialize and use the AI service
/// 
/// This shows a complete workflow:
/// 1. Create service instance
/// 2. Initialize with model download (first run)
/// 3. Send messages and stream responses
/// 4. Cleanup

Future<void> exampleBasicUsage() async {
  print('═════════════════════════════════════════════════════════');
  print('AIService Example Usage');
  print('═════════════════════════════════════════════════════════\n');

  final ai = AIService();

  try {
    // ============================================================
    // Step 1: Initialize AI Service
    // ============================================================
    
    print('📥 Initializing AI service...\n');

    await ai.initialize(
      // Filename for storage (will be reused on subsequent runs)
      modelName: 'tinyllama-1.1b-chat.gguf',

      // Full URL to download model from
      // TinyLlama is ~600MB, download takes 5-15 minutes
      modelUrl:
          'https://huggingface.co/TheBloke/'
          'TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/'
          'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',

      // Multi-threading: adjust based on device CPU cores
      // For reference: typically 4-8 threads on mid-range devices
      nThreads: (Platform.numberOfProcessors - 1).clamp(2, 8),

      // Progress callback during download (optional)
      onProgress: (received, total) {
        final pct = total > 0 ? (received / total * 100).toStringAsFixed(1) : '0';
        print('Download progress: $pct% ($received / $total bytes)');
      },
    );

    print('\n✓ AI service ready!\n');

    // ============================================================
    // Step 2: Send Messages and Stream Responses
    // ============================================================

    // Example prompts to try
    const prompts = [
      'Hello! What is Flutter?',
      'Explain quantum computing in 50 words.',
      'Write a short poem about AI.',
    ];

    for (int i = 0; i < prompts.length; i++) {
      final prompt = prompts[i];
      print('───────────────────────────────────────────────────────');
      print('Prompt ${i + 1}: $prompt\n');

      // sendMessage returns a Stream<String>
      // Each item is one token of the response
      final responseStream = ai.sendMessage(
        prompt,
        maxTokens: 128, // Limit response size
      );

      // Listen to stream and print tokens as they arrive
      await for (final token in responseStream) {
        stdout.write(token); // Print live (no newline)
      }
      print('\n'); // New line after response
    }

    print('═════════════════════════════════════════════════════════');
    print('Example complete!');
  } catch (e) {
    print('❌ Error: $e');
    debugPrintStack(label: 'Stack trace');
  } finally {
    // ============================================================
    // Step 3: Cleanup (Important!)
    // ============================================================
    print('\nCleaning up...');
    ai.dispose();
    print('Done.');
  }
}

/// Example: Advanced usage with error handling
Future<void> exampleAdvancedUsage() async {
  print('═════════════════════════════════════════════════════════');
  print('AIService Advanced Usage');
  print('═════════════════════════════════════════════════════════\n');

  final ai = AIService();

  try {
    // Initialize with custom config
    await ai.initialize(
      modelName: 'tinyllama-1.1b-chat.gguf',
      modelUrl:
          'https://huggingface.co/TheBloke/'
          'TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/'
          'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      nThreads: 4,
    );

    // Check if model is initialized
    if (!ai.isInitialized) {
      print('Error: AI service failed to initialize');
      return;
    }

    print('✓ AI initialized\n');

    // Generate with timeout (avoid infinite hangs)
    final prompt = 'What is machine learning?';
    print('Prompt: $prompt\n');

    String response = '';
    try {
      final stream = ai.sendMessage(prompt, maxTokens: 200);

      // Add timeout to prevent hanging forever
      await for (final token in stream.timeout(
        const Duration(minutes: 5),
        onTimeout: (sink) {
          print('\n⚠️  Generation timeout!');
          sink.close();
        },
      )) {
        response += token;
        stdout.write(token);
      }
    } on TimeoutException {
      print('\n⚠️  Generation took too long');
    }

    print('\n\nFull response:\n$response');
  } on StateError {
    print('Error: AI service not initialized');
  } on Exception catch (e) {
    print('Generation error: $e');
  } finally {
    ai.dispose();
  }
}

/// Example: Integration with Flutter widget
///
/// This is for use inside a Flutter StatefulWidget build method.
/// DO NOT run this directly - it's meant to show integration patterns.
/*

class _ChatWidgetState extends State<ChatWidget> {
  final ai = AIService();
  bool isInitialized = false;
  String responseText = '';
  bool isGenerating = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      await ai.initialize(
        modelName: 'tinyllama-1.1b-chat.gguf',
        modelUrl: '...model url...',
        onProgress: (received, total) {
          setState(() {
            // Update download progress UI
          });
        },
      );
      setState(() {
        isInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Init failed: $e')),
      );
    }
  }

  Future<void> _sendMessage(String prompt) async {
    if (!isInitialized) return;

    setState(() {
      responseText = '';
      isGenerating = true;
    });

    try {
      final stream = ai.sendMessage(prompt);
      await for (final token in stream) {
        setState(() {
          responseText += token;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isGenerating = false;
      });
    }
  }

  @override
  void dispose() {
    ai.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!isInitialized) Text('Initializing...'),
        if (isInitialized) ...[
          TextField(
            onSubmitted: isGenerating ? null : _sendMessage,
            enabled: !isGenerating,
          ),
          if (isGenerating) CircularProgressIndicator(),
          Expanded(child: Text(responseText)),
        ],
      ],
    );
  }
}

*/
