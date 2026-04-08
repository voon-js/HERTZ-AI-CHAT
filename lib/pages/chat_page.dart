import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:extract_text/extract_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
  hide ModelManager;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/chat_history_service.dart';
import '../services/generation_settings.dart';
import '../services/model_manager.dart';
import '../services/model_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/file_upload_overlay.dart';
import '../widgets/model_selector_overlay.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback onNavigateSettings;

  const ChatPage({super.key, required this.onNavigateSettings});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with TickerProviderStateMixin {
  bool _isSidebarOpen = false;
  bool _isFileUploadOpen = false;
  bool _isModelSelectorOpen = false;
  String _currentModel = ModelCatalog.defaultModel.name;

  final AIService _ai = AIService();
  final ChatHistoryService _historyService = ChatHistoryService();
  final ModelManager _modelManager = ModelManager();
  final GenerationSettingsService _generationSettings = GenerationSettingsService();
  final List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  String? _activeConversationId;
  final ScrollController _chatScrollController = ScrollController();
  bool _isInitializing = true;
  bool _isGenerating = false;
  bool _showFirstLoadScreen = false;
  double? _firstLoadProgress;
  String _firstLoadStatus = 'Select a model to install.';
  String? _firstLoadErrorText;
  String? _errorText;
  late final AnimationController _pulseController;
  late Future<Map<String, List<ModelCatalogEntry>>> _firstLoadModelsFuture;
  final Set<String> _selectedFirstLoadModelIds = {};
  Timer? _historySaveTimer;
  bool _isHistorySaveInProgress = false;
  bool _isHistorySaveQueued = false;
  bool _isFirstLoadInstalling = false;
  final List<XFile> _pendingImages = [];
  final List<XFile> _pendingFiles = [];
  static const int _maxImageOcrBytes = 5 * 1024 * 1024;
  static const int _maxTextPreviewBytes = 256 * 1024;
  static const int _maxBinaryExtractBytes = 8 * 1024 * 1024;
  static const int _maxAttachmentItemsForExtraction = 4;
  static const int _maxExtractedChunkChars = 4000;
  static const int _maxCombinedAttachmentChars = 12000;
  static const int _maxUserPromptChars = 2000;
  static const int _defaultMaxInferencePromptChars = 2000;
  static const int _currentPromptWarningChars = 1450;
  static const int _totalContextWarningChars = 2100;
  bool _skipContextAlmostFullWarningForSession = false;

  static const String _firstLoadDoneKey = 'first_time_setup_done_v2';
  static const String _activeModelIdKey = 'active_model_id_v2';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _firstLoadModelsFuture = _categorizeModels();
    unawaited(_generationSettings.load());
    unawaited(_bootstrap());
  }

  void _triggerBorderShine() {
  }

  /// Entry point function for isolate-based document extraction.
  /// This runs in a separate isolate and receives filePath via ReceivePort.
  static void _extractDocumentIsolateEntryPoint(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((dynamic message) async {
      if (message is List && message.length == 3) {
        final filePath = message[0] as String;
        final resultPort = message[1] as SendPort;
        final rootToken = message[2] as RootIsolateToken;

        // Allow plugin/method-channel calls from this background isolate.
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

        try {
          final file = File(filePath);
          if (!await file.exists()) {
            resultPort.send('[File not found]');
            receivePort.close();
            return;
          }

          final extractedText = await ExtractText.fromFile(filePath);
          resultPort.send(extractedText);
          receivePort.close();
        } catch (e) {
          resultPort.send('[File extraction error: $e]');
          receivePort.close();
        }
      }
    });
  }

  /// Wrapper that runs document extraction in an isolate with timeout protection.
  /// If extraction hangs or crashes, the isolate failure is isolated from main UI.
  Future<String> _extractWithIsolateAndTimeout(
    String filePath, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final rootToken = RootIsolateToken.instance;
      if (rootToken == null) {
        return '[File extraction unavailable: isolate token missing]';
      }

      final receivePort = ReceivePort();
      final resultPort = ReceivePort();

      // Spawn isolate with entry point
      await Isolate.spawn(
        _extractDocumentIsolateEntryPoint,
        receivePort.sendPort,
        onExit: receivePort.sendPort,
        onError: receivePort.sendPort,
      );

      // Get the isolate's send port
      final isolateSendPort = await receivePort.first as SendPort;

      // Send filePath, resultPort, and root token to isolate
      isolateSendPort.send([filePath, resultPort.sendPort, rootToken]);

      // Wait for response with timeout
      final result = await resultPort.first.timeout(
        timeout,
        onTimeout: () => '[File extraction timed out - might be corrupted]',
      );

      receivePort.close();
      resultPort.close();

      return result is String ? result : '[File extraction failed]';
    } catch (e) {
      // Isolate spawn or communication failed - graceful fallback
      return '[File extraction not supported on this device]';
    }
  }

  Future<String> _extractTextFromPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = sfpdf.PdfDocument(inputBytes: bytes);
    try {
      return sfpdf.PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chatScrollController.dispose();
    _historySaveTimer?.cancel();
    _ai.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final conversations = await _historyService.loadConversations();
    if (!mounted) return;

    setState(() {
      _conversations
        ..clear()
        ..addAll(conversations);
      // Start with new chat (blank page) instead of loading last conversation
    });
  }

  Future<Map<String, List<ModelCatalogEntry>>> _categorizeModels() async {
    final downloaded = <ModelCatalogEntry>[];
    final available = <ModelCatalogEntry>[];

    for (final model in ModelCatalog.models) {
      final exists = await _modelManager.modelExists(model.filename);
      if (exists) {
        downloaded.add(model);
      } else {
        available.add(model);
      }
    }

    return {
      'downloaded': downloaded,
      'available': available,
    };
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLoadDone = prefs.getBool(_firstLoadDoneKey) ?? false;
    final activeModelId = prefs.getString(_activeModelIdKey) ?? ModelCatalog.defaultModelId;
    final activeModel = ModelCatalog.byId(activeModelId);

    if (!mounted) return;
    unawaited(_loadHistory());

    if (!firstLoadDone) {
      if (!mounted) return;
      setState(() {
        _showFirstLoadScreen = true;
        _firstLoadProgress = null;
        _firstLoadStatus = 'Select a model to install.';
        _firstLoadErrorText = null;
        _firstLoadModelsFuture = _categorizeModels();
      });
      return;
    }

    if (!mounted) return;
    final initialized = await _initModel(
      model: activeModel,
      isFirstLoad: false,
    );

    if (!mounted) return;
    if (mounted) {
      setState(() {
        _showFirstLoadScreen = !initialized;
      });
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      try {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // If animation fails, jump directly to bottom
        _chatScrollController.jumpTo(
          _chatScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _loadConversation(ChatConversation conversation) {
    if (_isGenerating) return;

    unawaited(_saveCurrentConversation());

    // Reset scroll position immediately
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(0);
    }

    _closeSidebar();

    setState(() {
      _activeConversationId = conversation.id;
      _messages = List<ChatMessage>.from(conversation.messages);
      _errorText = null;
    });

    _scrollChatToBottom();
  }

  void _startNewChat() {
    if (_isGenerating) return;

    _historySaveTimer?.cancel();
    unawaited(_saveCurrentConversation());

    // Reset scroll position
    if (_chatScrollController.hasClients) {
      _chatScrollController.jumpTo(0);
    }

    _closeSidebar();

    setState(() {
      _activeConversationId = null;
      _messages = [];
      _errorText = null;
      _triggerBorderShine();
    });
  }

  Future<void> _deleteConversation(String conversationId) async {
    await _historyService.deleteConversation(_conversations, conversationId);

    // Reset scroll position if deleting active conversation
    if (_activeConversationId == conversationId && _chatScrollController.hasClients) {
      _chatScrollController.jumpTo(0);
    }

    _closeSidebar();

    setState(() {
      _conversations.removeWhere((item) => item.id == conversationId);
      if (_activeConversationId == conversationId) {
        _activeConversationId = null;
        _messages = [];
        _errorText = null;
        _triggerBorderShine();
      }
    });
  }

  Future<void> _persistActiveModelByName(String modelName) async {
    final selectedModel = ModelCatalog.models.firstWhere(
      (model) => model.name == modelName,
      orElse: () => ModelCatalog.defaultModel,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeModelIdKey, selectedModel.id);
  }

  Future<void> _switchModelByName(String modelName) async {
    if (_isGenerating) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stop generation before switching models.'),
        ),
      );
      return;
    }

    final selectedModel = ModelCatalog.models.firstWhere(
      (model) => model.name == modelName,
      orElse: () => ModelCatalog.defaultModel,
    );

    final initialized = await _initModel(
      model: selectedModel,
      isFirstLoad: false,
    );

    if (!initialized || !mounted) return;

    await _persistActiveModelByName(modelName);
    if (!mounted) return;

    setState(() {
      _isModelSelectorOpen = false;
    });
  }

  void _closeSidebar() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isSidebarOpen) return;
    setState(() => _isSidebarOpen = false);
  }

  String _createConversationId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  void _scheduleHistorySave({bool immediate = false}) {
    if (_messages.isEmpty) return;

    _historySaveTimer?.cancel();

    if (immediate) {
      unawaited(_saveCurrentConversation());
      return;
    }

    _historySaveTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveCurrentConversation());
    });
  }

  Future<void> _saveCurrentConversation() async {
    final conversationId = _activeConversationId;
    if (conversationId == null || _messages.isEmpty) return;

    if (_isHistorySaveInProgress) {
      _isHistorySaveQueued = true;
      return;
    }

    _isHistorySaveInProgress = true;

    try {
      do {
        _isHistorySaveQueued = false;

        final snapshot = ChatConversation(
          id: conversationId,
          title: _historyService.buildTitleFromMessages(_messages),
          updatedAt: DateTime.now(),
          messages: List<ChatMessage>.from(_messages),
        );

        final index = _conversations.indexWhere((item) => item.id == conversationId);
        if (index >= 0) {
          _conversations[index] = snapshot;
        } else {
          _conversations.insert(0, snapshot);
        }
        _conversations.sort(
          (left, right) => right.updatedAt.compareTo(left.updatedAt),
        );

        await _historyService.saveConversations(_conversations);
      } while (_isHistorySaveQueued);
    } finally {
      _isHistorySaveInProgress = false;
    }
  }

  Future<bool> _initModel({
    required ModelCatalogEntry model,
    required bool isFirstLoad,
  }) async {
    setState(() {
      _isInitializing = true;
      _errorText = null;
      if (isFirstLoad) {
        _firstLoadStatus = 'Preparing ${model.name}...';
        _firstLoadProgress = null;
        _firstLoadErrorText = null;
      }
    });

    try {
      await _ai.initialize(
        modelName: model.filename,
        modelUrl: model.url,
        onProgress: isFirstLoad
            ? (received, total) {
                if (!mounted) return;
                final hasTotal = total > 0;
                final value = hasTotal
                    ? (received / total).clamp(0.0, 1.0)
                    : null;
                final percent = hasTotal ? ((value! * 100).round()) : null;

                setState(() {
                  _firstLoadProgress = value;
                  _firstLoadStatus = percent == null
                      ? 'Downloading ${model.name}...'
                      : 'Downloading ${model.name}... $percent%';
                  _firstLoadErrorText = null;
                });
              }
            : null,
      );
      if (!mounted) return false;
      setState(() {
        _isInitializing = false;
        _currentModel = model.name;
        _triggerBorderShine();
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isInitializing = false;
        _errorText = 'Init failed: $e';
        _triggerBorderShine();
        if (isFirstLoad) {
          _firstLoadErrorText =
              'Failed to load ${model.name}. Please check your internet connection and try again.';
          _firstLoadStatus = 'Setup failed.';
        }
      });
      return false;
    }
  }

  Future<void> _installSelectedModels(List<ModelCatalogEntry> selectedModels) async {
    if (selectedModels.isEmpty || _isFirstLoadInstalling) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Clear any previous cancellation state
    _modelManager.clearCancellationState();

    setState(() {
      _isFirstLoadInstalling = true;
      _firstLoadErrorText = null;
      _firstLoadProgress = null;
      _firstLoadStatus = 'Preparing selected model(s)...';
    });

    try {
      for (final model in selectedModels) {
        final exists = await _modelManager.modelExists(model.filename);
        if (exists) {
          if (!mounted) return;
          setState(() {
            _firstLoadStatus = '${model.name} is ready.';
          });
          continue;
        }

        if (!mounted) return;
        setState(() {
          _firstLoadProgress = null;
          _firstLoadStatus = 'Downloading ${model.name}...';
        });

        await _modelManager.downloadModel(
          model.filename,
          model.url,
          onProgress: (received, total) {
            if (!mounted) return;
            final hasTotal = total > 0;
            final value = hasTotal ? (received / total).clamp(0.0, 1.0) : null;
            final percent = hasTotal ? ((value! * 100).round()) : null;

            setState(() {
              _firstLoadProgress = value;
              _firstLoadStatus = percent == null
                  ? 'Downloading ${model.name}...'
                  : 'Downloading ${model.name}... $percent%';
            });
          },
        );
      }

      final primaryModel = selectedModels.first;
      await prefs.setString(_activeModelIdKey, primaryModel.id);
      final initialized = await _initModel(
        model: primaryModel,
        isFirstLoad: true,
      );

      if (!initialized) {
        throw Exception('Initialization failed');
      }

      await prefs.setBool(_firstLoadDoneKey, true);
      if (!mounted) return;

      setState(() {
        _showFirstLoadScreen = false;
        _firstLoadProgress = null;
        _firstLoadErrorText = null;
      });

      _firstLoadModelsFuture = _categorizeModels();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isFirstLoadInstalling = false;
        _firstLoadProgress = null;
        _firstLoadStatus = 'Setup failed.';
        _firstLoadErrorText =
            'Failed to install the selected model(s). Please try again.';
        _triggerBorderShine();
        _firstLoadModelsFuture = _categorizeModels();
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isFirstLoadInstalling = false;
    });
  }

  Future<void> _cancelFirstLoadSetup() async {
    if (!_isFirstLoadInstalling) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final subtitleColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        title: const Text(
          'CANCEL DOWNLOAD?',
          style: TextStyle(
            fontFamily: 'Courier',
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will stop all downloads and delete any partially downloaded files.',
          style: TextStyle(
            fontFamily: 'Courier',
            color: subtitleColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'NO',
              style: TextStyle(
                fontFamily: 'Courier',
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performCancel();
            },
            child: const Text(
              'YES',
              style: TextStyle(
                fontFamily: 'Courier',
                color: nothingRed,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancel() async {
    // Cancel all downloads
    await _modelManager.cancelAllDownloads();

    if (!mounted) return;

    setState(() {
      _isFirstLoadInstalling = false;
      _firstLoadProgress = null;
      _firstLoadStatus = 'Select a model to install.';
      _firstLoadErrorText = null;
      _firstLoadModelsFuture = _categorizeModels();
    });

    // Clear cancellation state for next attempt
    _modelManager.clearCancellationState();
  }

  String _systemInstruction(ModelCatalogEntry model) {
    return 'You are a helpful conversational assistant. Your name is ${model.name}. When asked for your name, reply with ${model.name}. You are reconfigured and integrated by Hertz. Your base model is ${model.baseModelName}, originally by its real creator/company. Keep a warm, natural chat tone. For simple greetings like hi/hello/how are you, give a short friendly one-sentence reply. Do not prepend your model name unless explicitly asked. Do not mention being a language model, AI system, program, or that you do not have feelings unless the user directly asks about that. Never output control tokens, role tags, or separators such as <|...|>, <start_of_turn>, or standalone pipes. Keep answers concise unless the user asks for detail. Do not write both sides of a conversation. Do not invent another user question.';
  }

  String _sanitizeAssistantText(String text) {
    var out = text.trimRight();
    final markers = <String>[
      '<|user|>',
      '<|user',
      '<|assistant|>',
      '<|assistant',
      '<|end|>',
      '<|end|',
      '<|end',
      '<start_of_turn>user',
      '<start_of_turn>model',
      '<|im_start|>user',
      '<|im_start|>assistant',
    ];

    bool removed = true;
    while (removed) {
      removed = false;
      for (final marker in markers) {
        if (out.endsWith(marker)) {
          out = out.substring(0, out.length - marker.length).trimRight();
          removed = true;
        }
      }
    }

    out = out.replaceFirst(RegExp(r'(\s*\|\s*)+$'), '').trimRight();
    return out;
  }

  List<Map<String, String>> _recentTurnsWithCurrentUser(
    String userPrompt, {
    required bool includeHistory,
  }) {
    final turns = <Map<String, String>>[];

    if (includeHistory) {
      for (final message in _messages) {
        final content = message.text.trim();
        if (content.isEmpty) continue;
        turns.add({
          'role': message.isUser ? 'user' : 'assistant',
          'content': content,
        });
      }
    }

    final currentUserText = userPrompt.trim();
    if (currentUserText.isNotEmpty) {
      turns.add({'role': 'user', 'content': currentUserText});
    }

    const maxTurns = 12;
    if (turns.length > maxTurns) {
      return turns.sublist(turns.length - maxTurns);
    }

    return turns;
  }

  String _buildInferencePrompt(String userPrompt, {bool includeHistory = true}) {
    final model = ModelCatalog.byName(_currentModel);
    final system = _systemInstruction(model);
    final turns = _recentTurnsWithCurrentUser(
      userPrompt,
      includeHistory: includeHistory,
    );

    if (model.id.contains('tinyllama')) {
      final prompt = StringBuffer('<|system|>\n$system<|end|>\n');
      for (final turn in turns) {
        if (turn['role'] == 'user') {
          prompt.write('<|user|>\n${turn['content']}<|end|>\n');
        } else {
          prompt.write('<|assistant|>\n${turn['content']}<|end|>\n');
        }
      }
      prompt.write('<|assistant|>\n');
      return prompt.toString();
    }

    if (model.id.contains('llama_3_2')) {
      final prompt = StringBuffer(
        '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n$system<|eot_id|>',
      );
      for (final turn in turns) {
        if (turn['role'] == 'user') {
          prompt.write('<|start_header_id|>user<|end_header_id|>\n${turn['content']}<|eot_id|>');
        } else {
          prompt.write('<|start_header_id|>assistant<|end_header_id|>\n${turn['content']}<|eot_id|>');
        }
      }
      prompt.write('<|start_header_id|>assistant<|end_header_id|>\n');
      return prompt.toString();
    }

    if (model.id.contains('qwen')) {
      final prompt = StringBuffer('<|im_start|>system\n$system<|im_end|>\n');
      for (final turn in turns) {
        if (turn['role'] == 'user') {
          prompt.write('<|im_start|>user\n${turn['content']}<|im_end|>\n');
        } else {
          prompt.write('<|im_start|>assistant\n${turn['content']}<|im_end|>\n');
        }
      }
      prompt.write('<|im_start|>assistant\n');
      return prompt.toString();
    }

    if (model.id.contains('gemma')) {
      final prompt = StringBuffer('<start_of_turn>system\n$system<end_of_turn>\n');
      for (final turn in turns) {
        if (turn['role'] == 'user') {
          prompt.write('<start_of_turn>user\n${turn['content']}<end_of_turn>\n');
        } else {
          prompt.write('<start_of_turn>model\n${turn['content']}<end_of_turn>\n');
        }
      }
      prompt.write('<start_of_turn>model\n');
      return prompt.toString();
    }

    if (model.id.contains('phi_3_5')) {
      final prompt = StringBuffer('<|system|>\n$system<|end|>\n');
      for (final turn in turns) {
        if (turn['role'] == 'user') {
          prompt.write('<|user|>\n${turn['content']}<|end|>\n');
        } else {
          prompt.write('<|assistant|>\n${turn['content']}<|end|>\n');
        }
      }
      prompt.write('<|assistant|>\n');
      return prompt.toString();
    }

    final prompt = StringBuffer('System: $system\n');
    for (final turn in turns) {
      if (turn['role'] == 'user') {
        prompt.write('User: ${turn['content']}\n');
      } else {
        prompt.write('Assistant: ${turn['content']}\n');
      }
    }
    prompt.write('Assistant:');
    return prompt.toString();
  }

  int _maxTokensForCurrentModel() {
    final model = ModelCatalog.byName(_currentModel);

    if (model.id == ModelCatalog.defaultModelId ||
        model.id.contains('llama_3_2_1b')) {
      return 120;
    }

    if (model.id.contains('qwen2_5_7b') ||
        model.id.contains('qwen2_5_coder_7b')) {
      return 220;
    }

    return 180;
  }

  void _handleImagesSelected(List<XFile> images) {
    if (images.isEmpty) return;
    setState(() {
      _pendingImages.addAll(images);
      _isFileUploadOpen = false;
    });

    unawaited(_showQueuedAttachmentContextSnackBar());
  }

  void _handleFilesSelected(List<XFile> files) {
    if (files.isEmpty) return;
    setState(() {
      _pendingFiles.addAll(files);
      _isFileUploadOpen = false;
    });

    unawaited(_showQueuedAttachmentContextSnackBar());
  }

  void _openImageViewer(List<String> imagePaths, int initialIndex) {
    if (imagePaths.isEmpty) return;

    final startIndex = initialIndex.clamp(0, imagePaths.length - 1);
    final pageController = PageController(initialPage: startIndex);
    var currentPage = startIndex;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      controller: pageController,
                      onPageChanged: (index) {
                        setModalState(() {
                          currentPage = index;
                        });
                      },
                      itemCount: imagePaths.length,
                      itemBuilder: (context, index) {
                        final path = imagePaths[index];
                        return Center(
                          child: InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.file(
                              File(path),
                              fit: BoxFit.contain,
                              cacheWidth: 2048,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (imagePaths.length > 1)
                    Positioned(
                      bottom: 28,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imagePaths.length, (index) {
                          final isActive = index == currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: isActive ? 18 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  Positioned(
                    top: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _extractTextFromImages(List<XFile> images) async {
    if (images.isEmpty) return '';

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final extractedChunks = <String>[];

    try {
      for (var i = 0; i < images.length; i++) {
        final imageFile = File(images[i].path);
        if (!await imageFile.exists()) continue;

        final imageSize = await imageFile.length();
        if (imageSize > _maxImageOcrBytes) {
          extractedChunks.add(
            'Image ${i + 1} (${images[i].name}) is too large to OCR safely on-device.',
          );
          continue;
        }

        final inputImage = InputImage.fromFilePath(images[i].path);
        final result = await recognizer.processImage(inputImage);
        final text = result.text.trim();
        if (text.isNotEmpty) {
          final clipped = text.length > _maxExtractedChunkChars
              ? '${text.substring(0, _maxExtractedChunkChars)}\n\n[Image text truncated due to size.]'
              : text;
          extractedChunks.add('Image ${i + 1} text:\n$clipped');
        }
      }
    } catch (_) {
      // Ignore OCR failures for individual images and continue with what we have.
    } finally {
      await recognizer.close();
    }

    return extractedChunks.join('\n\n').trim();
  }

  Future<String> _extractTextFromFiles(List<XFile> files) async {
    if (files.isEmpty) return '';

    final extractedChunks = <String>[];
    const plainTextExtensions = {
      'txt',
      'md',
      'csv',
      'json',
      'xml',
      'html',
      'htm',
      'log',
      'rtf',
    };
    const binaryExtensions = {'pdf', 'doc', 'docx'};

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final extension = file.path.split('.').last.toLowerCase();
      String? extractedText;
      final sourceFile = File(file.path);

      if (!await sourceFile.exists()) {
        continue;
      }

      final fileSize = await sourceFile.length();

      try {
        if (plainTextExtensions.contains(extension)) {
          // Plain text: simple UTF-8 streaming
          final bytesToRead = fileSize > _maxTextPreviewBytes
              ? _maxTextPreviewBytes
              : fileSize;
          extractedText = await sourceFile
              .openRead(0, bytesToRead)
              .transform(const Utf8Decoder(allowMalformed: true))
              .join();
          if (fileSize > _maxTextPreviewBytes) {
            extractedText = '${extractedText.trimRight()}\n\n[Preview truncated: file is too large for full in-app extraction.]';
          }
        } else if (extension == 'pdf') {
          if (fileSize > _maxBinaryExtractBytes) {
            extractedChunks.add(
              'File ${i + 1} (${file.name}) is too large for safe PDF text extraction. Max supported size is 8 MB.',
            );
            continue;
          }

          extractedText = await _extractTextFromPdf(file.path);
          if (extractedText.trim().isEmpty) {
            extractedChunks.add(
              'File ${i + 1} (${file.name}) appears to be image-only or has no selectable text. OCR for PDF images is not enabled, so the model will not see text from this file.',
            );
            continue;
          }
        } else if (binaryExtensions.contains(extension)) {
          // DOC/DOCX: use isolate with timeout
          // If extraction hangs or crashes, the isolate failure is isolated from main UI
          if (fileSize > _maxBinaryExtractBytes) {
            extractedChunks.add(
              'File ${i + 1} (${file.name}) is too large for safe in-app extraction. Max supported size is 8 MB for this format.',
            );
            continue;
          }

          extractedText = await _extractWithIsolateAndTimeout(
            file.path,
            timeout: const Duration(seconds: 15),
          );

          if (extension == 'doc' && extractedText.trim().isEmpty) {
            extractedChunks.add(
              'File ${i + 1} (${file.name}) is a legacy .doc file and may not be extractable on-device. Try converting it to .docx or .pdf for better results.',
            );
            continue;
          }
        } else {
          extractedChunks.add(
            'File ${i + 1} (${file.name}) was attached, but text extraction is not supported for this format.',
          );
          continue;
        }
      } catch (_) {
        extractedText = null;
      }

      final clean = extractedText?.trim() ?? '';
      if (clean.isNotEmpty) {
        final clipped = clean.length > _maxExtractedChunkChars
            ? '${clean.substring(0, _maxExtractedChunkChars)}\n\n[File text truncated due to size.]'
            : clean;
        extractedChunks.add('File ${i + 1} (${file.name}) text:\n$clipped');
      }
    }

    return extractedChunks.join('\n\n').trim();
  }

  Future<void> _sendPrompt(String prompt) async {
    if (_isGenerating || _isInitializing) return;

    final userText = prompt.trim();
    final attachedImages = List<XFile>.from(_pendingImages);
    final attachedFiles = List<XFile>.from(_pendingFiles);
    if (userText.isEmpty && attachedImages.isEmpty && attachedFiles.isEmpty) return;

    // Check if user prompt is too long (conservative to prevent crashes)
    if (userText.length > _maxUserPromptChars) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Your prompt is too long (${userText.length} chars). Max is $_maxUserPromptChars chars. Please shorten it or remove attachments.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      return;
    }

    final imagesForExtraction = attachedImages
      .take(_maxAttachmentItemsForExtraction)
      .toList();
    final filesForExtraction = attachedFiles
      .take(_maxAttachmentItemsForExtraction)
      .toList();

    final extractedImageText = await _extractTextFromImages(imagesForExtraction);
    final extractedFileText = await _extractTextFromFiles(filesForExtraction);

    final promptBuffer = StringBuffer();
    if (userText.isNotEmpty) {
      promptBuffer.writeln(userText);
    }

    if (attachedImages.length > imagesForExtraction.length ||
        attachedFiles.length > filesForExtraction.length) {
      if (promptBuffer.isNotEmpty) promptBuffer.writeln();
      promptBuffer.writeln(
        'Note: Only the first $_maxAttachmentItemsForExtraction image(s) and first $_maxAttachmentItemsForExtraction file(s) were processed to keep the app stable.',
      );
    }

    if (extractedImageText.trim().isNotEmpty) {
      if (promptBuffer.isNotEmpty) promptBuffer.writeln();
      promptBuffer.writeln('Attached image OCR text:');
      promptBuffer.writeln(extractedImageText.trim());
    }

    if (extractedFileText.trim().isNotEmpty) {
      if (promptBuffer.isNotEmpty) promptBuffer.writeln();
      promptBuffer.writeln('Attached file text:');
      promptBuffer.writeln(extractedFileText.trim());
    }

    var combinedPrompt = promptBuffer.toString().trim();
    if (combinedPrompt.length > _maxCombinedAttachmentChars) {
      combinedPrompt =
          '${combinedPrompt.substring(0, _maxCombinedAttachmentChars)}\n\n[Attachment context truncated due to size.]';
    }
    final promptForChecks = combinedPrompt.isEmpty ? userText : combinedPrompt;
    final currentPromptChars = _buildInferencePrompt(
      promptForChecks,
      includeHistory: false,
    ).length;
    final totalContextChars = _buildInferencePrompt(promptForChecks).length;

    if (totalContextChars > _totalContextWarningChars) {
      if (!mounted) return;
      if (!_skipContextAlmostFullWarningForSession) {
        final confirmed = await _confirmContextAlmostFullGeneration(totalContextChars);
        if (!confirmed) return;
      }
    } else if (currentPromptChars > _currentPromptWarningChars) {
      if (!mounted) return;
      final confirmed = await _confirmLargeCurrentPromptGeneration(currentPromptChars);
      if (!confirmed) return;
    }

    final now = DateTime.now();
    final conversationId = _activeConversationId ?? _createConversationId();
    final activeModel = ModelCatalog.byName(_currentModel);
    final maxTokens = _maxTokensForCurrentModel();
    final userMessageText = userText.isEmpty && (attachedImages.isNotEmpty || attachedFiles.isNotEmpty)
        ? '${[
            if (attachedImages.isNotEmpty)
              'Sent ${attachedImages.length} image${attachedImages.length > 1 ? 's' : ''}'
            else
              null,
            if (attachedFiles.isNotEmpty)
              'Sent ${attachedFiles.length} file${attachedFiles.length > 1 ? 's' : ''}'
            else
              null,
          ].whereType<String>().join(' and ')}.'
        : userText;
    final imagePaths = attachedImages.map((image) => image.path).toList();
    final filePaths = attachedFiles.map((file) => file.path).toList();

    setState(() {
      _activeConversationId = conversationId;
      _messages = [
        ..._messages,
        ChatMessage(
          text: userMessageText,
          isUser: true,
          timestamp: now,
          imagePaths: imagePaths,
          filePaths: filePaths,
        ),
        ChatMessage(
          text: '',
          isUser: false,
          timestamp: now,
        ),
      ];
      _pendingImages.clear();
      _pendingFiles.clear();
      _isGenerating = true;
      _errorText = null;
      _triggerBorderShine();
    });
    _scrollChatToBottom();
    _scheduleHistorySave();

    try {
      var combinedPrompt = promptBuffer.toString().trim();
      if (combinedPrompt.length > _maxCombinedAttachmentChars) {
        combinedPrompt =
            '${combinedPrompt.substring(0, _maxCombinedAttachmentChars)}\n\n[Attachment context truncated due to size.]';
      }
      final inferencePrompt = _buildInferencePrompt(
        combinedPrompt.isEmpty ? userText : combinedPrompt,
      );

      final settings = _generationSettings.current;
      final maxInferencePromptChars = settings.contextChars <= 0
          ? _defaultMaxInferencePromptChars
          : settings.contextChars;

      // Safety check before inference to prevent model crashes from oversized context
      if (inferencePrompt.length > maxInferencePromptChars) {
        if (!mounted) return;
        setState(() {
          _errorText =
              'Context too large for safe generation (limit: $maxInferencePromptChars chars). Please use a shorter prompt or fewer attachments.';
          _messages.removeLast(); // Remove the empty assistant message we added
          _isGenerating = false;
          _triggerBorderShine();
        });
        return;
      }

      await for (final token in _ai.sendMessage(
        inferencePrompt,
        maxTokens: maxTokens,
        temperature: settings.temperature,
        topP: settings.topP,
        topK: settings.topK,
        minP: settings.minP,
        repeatPenalty: settings.repeatPenalty,
      )) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          var tokenChunk = token;

          // Gemma 2B often starts with a newline token, which creates a blank row.
          if (activeModel.id.contains('gemma_2_2b_it') && last.text.isEmpty) {
            tokenChunk = tokenChunk.replaceFirst(RegExp(r'^[\r\n]+'), '');
            if (tokenChunk.isEmpty) {
              return;
            }
          }

          _messages[_messages.length - 1] = ChatMessage(
            text: last.text + tokenChunk,
            isUser: false,
            timestamp: DateTime.now(),
          );
        });
        _scrollChatToBottom();
        _scheduleHistorySave();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Generation failed: $e';
        _triggerBorderShine();
      });
    } finally {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && !_messages.last.isUser) {
            final last = _messages.last;
            _messages[_messages.length - 1] = last.copyWith(
              text: _sanitizeAssistantText(last.text),
              timestamp: DateTime.now(),
            );
          }
          _isGenerating = false;
        });
        _scheduleHistorySave(immediate: true);
        _scrollChatToBottom();
      }
    }
  }

  void _stopGenerating() {
    if (!_isGenerating) return;
    _ai.stopGenerating();
    if (!mounted) return;
    setState(() {
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        final last = _messages.last;
        _messages[_messages.length - 1] = last.copyWith(
          text: _sanitizeAssistantText(last.text),
          timestamp: DateTime.now(),
        );
      }
      _isGenerating = false;
    });
    _scheduleHistorySave(immediate: true);
  }

  void _handleBlockedBack(bool keyboardOpen) {
    if (_showFirstLoadScreen) {
      return;
    }

    if (keyboardOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }

    if (_isModelSelectorOpen) {
      setState(() => _isModelSelectorOpen = false);
      return;
    }

    if (_isFileUploadOpen) {
      setState(() => _isFileUploadOpen = false);
      return;
    }

    if (_isSidebarOpen) {
      _closeSidebar();
    }
  }

  void _showCurrentModelInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.black;

    final model = ModelCatalog.byName(_currentModel);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: borderColor),
        ),
        title: Text(
          'MODEL INFO',
          style: TextStyle(
            fontFamily: 'Courier',
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: textColor,
          ),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.name,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                model.description,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 11,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 14),
              _buildModelInfoRow('Base Model', model.baseModelName, textColor, subtitleColor),
              _buildModelInfoRow('Model Size', model.modelSize, textColor, subtitleColor),
              _buildModelInfoRow('Quantization', model.quantization, textColor, subtitleColor),
              _buildModelInfoRow('Parameters', model.parameters, textColor, subtitleColor),
              _buildModelInfoRow('Context Tokens', model.contextTokens, textColor, subtitleColor),
              _buildModelInfoRow('Recommended RAM', model.recommendedRam, textColor, subtitleColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                fontFamily: 'Courier',
                color: nothingRed,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelInfoRow(
    String label,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final canPopRoute =
        !(_showFirstLoadScreen ||
            keyboardOpen ||
            _isModelSelectorOpen ||
            _isFileUploadOpen ||
            _isSidebarOpen);

    return PopScope(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBlockedBack(keyboardOpen);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: bg,
        body: SafeArea(
          child: Stack(
            children: [
            Column(
              children: [
                TopBar(
                  onOpenSidebar: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _isSidebarOpen = true);
                  },
                  onOpenModelSelector: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _isModelSelectorOpen = true);
                  },
                  onOpenModelInfo: _showCurrentModelInfo,
                  currentModel: _currentModel,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: DotPatternPainter(isDark: isDark),
                        ),
                      ),
                      Center(
                        child: _messages.isEmpty
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '(>_)',
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                      letterSpacing: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _isInitializing
                                        ? 'LOADING MODEL...'
                                        : (_isGenerating
                                            ? 'GENERATING...'
                                            : 'SYSTEM READY'),
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 320),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF3F3F46)
                                            : const Color(0xFFD1D5DB),
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Text(
                                      _errorText != null
                                          ? 'An error occurred. Please try again.'
                                          : (_isInitializing
                                              ? 'DOWNLOADING / INITIALIZING MODEL...'
                                              : 'TYPE A MESSAGE AND PRESS SEND.'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFF71717A)
                                            : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: ListView.builder(
                                  controller: _chatScrollController,
                                  itemCount:
                                      _messages.length + (_errorText == null ? 0 : 1),
                                  itemBuilder: (context, index) {
                                    if (_errorText != null &&
                                        index == _messages.length) {
                                      return _buildErrorBubble(
                                        isDark,
                                        _errorText!,
                                      );
                                    }

                                    final message = _messages[index];
                                    final animateGenerating =
                                        _isGenerating &&
                                        !message.isUser &&
                                        message.text.isEmpty &&
                                        index == _messages.length - 1;
                                    return _buildMessageBubble(
                                      isDark,
                                      message,
                                      animateGenerating: animateGenerating,
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 140), //searchbar and keyboard animations
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ChatInputBar(
                    onOpenFileUpload: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => _isFileUploadOpen = true);
                    },
                    onSend: _sendPrompt,
                    onStop: _stopGenerating,
                    pendingImages: _pendingImages,
                    pendingFiles: _pendingFiles,
                    onRemovePendingImage: (index) {
                      if (index < 0 || index >= _pendingImages.length) return;
                      setState(() {
                        _pendingImages.removeAt(index);
                      });
                    },
                    onRemovePendingFile: (index) {
                      if (index < 0 || index >= _pendingFiles.length) return;
                      setState(() {
                        _pendingFiles.removeAt(index);
                      });
                    },
                    isInputEnabled: !_isInitializing,
                    areActionsEnabled: !_isInitializing && !_isGenerating,
                    isGenerating: _isGenerating,
                  ),
                ),
              ],
            ),
            SidebarWidget(
              isOpen: _isSidebarOpen,
              isBusy: _isGenerating || _isInitializing,
              onClose: _closeSidebar,
              onNewChat: _startNewChat,
              onSelectConversation: (conversationId) {
                final conversation = _conversations.firstWhere(
                  (item) => item.id == conversationId,
                );
                _loadConversation(conversation);
              },
              onDeleteConversation: _deleteConversation,
              onOpenSettings: () {
                _closeSidebar();
                widget.onNavigateSettings();
              },
              conversations: _conversations,
              selectedConversationId: _activeConversationId,
            ),
            FileUploadOverlay(
              isOpen: _isFileUploadOpen,
              onClose: () => setState(() => _isFileUploadOpen = false),
              onImagesSelected: _handleImagesSelected,
              onFilesSelected: _handleFilesSelected,
            ),
            ModelSelectorOverlay(
              isOpen: _isModelSelectorOpen,
              onClose: () => setState(() => _isModelSelectorOpen = false),
              currentModel: _currentModel,
              onSelectModel: (model) {
                unawaited(_switchModelByName(model));
              },
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showFirstLoadScreen,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 360),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: slide,
                        child: child,
                      ),
                    );
                  },
                  child: _showFirstLoadScreen
                      ? KeyedSubtree(
                          key: const ValueKey('first-load-screen'),
                          child: _buildFirstLoadScreen(isDark),
                        )
                      : const SizedBox.expand(
                          key: ValueKey('first-load-hidden'),
                        ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFirstLoadScreen(bool isDark) {
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);
    final borderColor = isDark ? const Color(0xFF3F3F46) : Colors.black;

    return ColoredBox(
      color: bg,
      child: Center(
        child: Container(
          width: 420,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FutureBuilder<Map<String, List<ModelCatalogEntry>>>(
            future: _firstLoadModelsFuture,
            builder: (context, snapshot) {
              final availableModels = snapshot.data?['available'] ?? [];
              final selectedModels = availableModels
                  .where((model) => _selectedFirstLoadModelIds.contains(model.id))
                  .toList();

              final selectedCount = selectedModels.length;
              final canInstall = selectedCount > 0 && !_isFirstLoadInstalling;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FIRST TIME SETUP',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select one or more models to install. Installed models are ready to use immediately.',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_firstLoadErrorText != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A1215)
                            : const Color(0xFFFFE4E6),
                        border: Border.all(color: const Color(0xFFEF4444)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        _firstLoadErrorText!,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isFirstLoadInstalling) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _firstLoadProgress,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE5E7EB),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(nothingRed),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _firstLoadStatus,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: !snapshot.hasData
                        ? Center(
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (availableModels.isNotEmpty) ...[
                                    _buildSetupSectionHeader(
                                      'AVAILABLE',
                                      subtitleColor,
                                    ),
                                    const SizedBox(height: 8),
                                    ...availableModels.map(
                                      (model) => _buildSetupModelCard(
                                        model,
                                        isDark: isDark,
                                        subtitleColor: subtitleColor,
                                        borderColor: borderColor,
                                        selected: _selectedFirstLoadModelIds
                                            .contains(model.id),
                                        enabled: !_isFirstLoadInstalling,
                                        onTap: () {
                                          setState(() {
                                            if (_selectedFirstLoadModelIds
                                                .contains(model.id)) {
                                              _selectedFirstLoadModelIds
                                                  .remove(model.id);
                                            } else {
                                              _selectedFirstLoadModelIds
                                                  .add(model.id);
                                            }
                                            _triggerBorderShine();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                  if (availableModels.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Text(
                                        'No models are configured yet.',
                                        style: TextStyle(
                                          fontFamily: 'Courier',
                                          fontSize: 12,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      selectedCount == 1
                          ? '1 model will be installed'
                          : '$selectedCount models will be installed',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canInstall
                          ? () {
                              unawaited(_installSelectedModels(selectedModels));
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nothingRed,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: nothingRed.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      child: Text(
                        _isFirstLoadInstalling
                            ? 'INSTALLING...'
                            : 'INSTALL SELECTED',
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  if (_isFirstLoadInstalling) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelFirstLoadSetup,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nothingRed,
                          side: const BorderSide(color: nothingRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSetupSectionHeader(String title, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: subtitleColor,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildSetupModelCard(
    ModelCatalogEntry model, {
    required bool isDark,
    required Color subtitleColor,
    required Color borderColor,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final foregroundColor = isDark ? Colors.white : Colors.black;
    final accentColor = selected ? nothingRed : borderColor;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: accentColor),
          borderRadius: BorderRadius.circular(2),
          color: selected
              ? (isDark ? const Color(0xFF1C1A1A) : const Color(0xFFFFF7F7))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? nothingRed : foregroundColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? nothingRed : Colors.transparent,
                border: Border.all(color: selected ? nothingRed : accentColor),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    bool isDark,
    ChatMessage message, {
    bool animateGenerating = false,
  }) {
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final userBubbleBg =
      isDark ? const Color(0xFF7F1D1D) : const Color(0xFFEF4444);
    final userBubbleBorder =
      isDark ? const Color(0xFFB91C1C) : const Color(0xFFEF4444);
    final userBubbleText =
      isDark ? const Color(0xFFFFF1F2) : Colors.white;

    final bgColor = message.isUser
      ? userBubbleBg
      : (isDark ? const Color(0xFF18181B) : const Color(0xFFF3F4F6));
    final textColor = message.isUser
      ? userBubbleText
      : (isDark ? Colors.white : Colors.black);

    if (animateGenerating && message.text.isEmpty) {
      return Align(
        alignment: align,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulseController.value);
            final scale = 0.985 + (t * 0.03);
            return Transform.scale(
              scale: scale,
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 330),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3F3F46)
                        : const Color(0xFFD1D5DB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.04 + (t * 0.06)),
                      blurRadius: 10 + (8 * t),
                      spreadRadius: 0.5 + t,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Generating',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypingDots(
                      progress: _pulseController.value,
                      color: textColor,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Align(
      alignment: align,
      child: GestureDetector(
        onLongPress: message.text.trim().isEmpty
            ? null
            : () => _copyMessageToClipboard(message.text),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 330),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: message.isUser
                  ? userBubbleBorder
                  : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.imagePaths.isNotEmpty)
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: message.imagePaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = message.imagePaths[index];
                      return GestureDetector(
                        onTap: () => _openImageViewer(message.imagePaths, index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 78,
                            height: 78,
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              cacheWidth: 240,
                              cacheHeight: 240,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark
                                    ? const Color(0xFF27272A)
                                    : const Color(0xFFE5E7EB),
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (message.filePaths.isNotEmpty)
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: message.filePaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = message.filePaths[index];
                      final fileName = path.split('\\').last.split('/').last;
                      final extension = fileName.contains('.')
                          ? fileName.split('.').last.toUpperCase()
                          : 'FILE';
                      return Container(
                        width: 78,
                        height: 90,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: message.isUser
                                ? userBubbleBorder
                                : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: textColor,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              extension,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fileName,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 8,
                                color: textColor.withValues(alpha: 0.9),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if ((message.imagePaths.isNotEmpty || message.filePaths.isNotEmpty) &&
                  message.text.trim().isNotEmpty)
                const SizedBox(height: 8),
              if (message.text.trim().isNotEmpty ||
                  (message.imagePaths.isEmpty && message.filePaths.isEmpty))
                message.text.isEmpty
                    ? Text(
                        '...',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 13,
                          color: textColor,
                        ),
                      )
                    : _buildRichMessageText(
                        message.text,
                        textColor,
                        isDark: isDark,
                      ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichMessageText(
    String text,
    Color textColor, {
    required bool isDark,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 13,
          color: textColor,
          height: 1.35,
        ),
        children: _parseInlineSpans(text, textColor, isDark),
      ),
    );
  }

  List<TextSpan> _parseInlineSpans(
    String input,
    Color textColor,
    bool isDark,
  ) {
    final spans = <TextSpan>[];
    final matches = RegExp(
      r'(\*\*[^\n*]+\*\*|__[^\n_]+__|`[^\n`]+`|\[[^\]]+\]\([^\)]+\)|https?://[^\s]+|\*[^\n*]+\*|_[^\n_]+_)',
    ).allMatches(input);

    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, match.start)));
      }

      final token = match.group(0) ?? '';
      spans.add(_spanForToken(token, textColor, isDark));
      cursor = match.end;
    }

    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }

    return spans;
  }

  TextSpan _spanForToken(String token, Color textColor, bool isDark) {
    final linkColor = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF2563EB);
    final codeBg = isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB);

    if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
      return TextSpan(
        text: token.substring(2, token.length - 2),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    if (token.startsWith('__') && token.endsWith('__') && token.length > 4) {
      return TextSpan(
        text: token.substring(2, token.length - 2),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    if (token.startsWith('`') && token.endsWith('`') && token.length > 2) {
      return TextSpan(
        text: token.substring(1, token.length - 1),
        style: TextStyle(
          fontFamily: 'Courier',
          backgroundColor: codeBg,
          color: textColor,
        ),
      );
    }

    if (token.startsWith('[') && token.contains('](') && token.endsWith(')')) {
      final closingBracket = token.indexOf('](');
      if (closingBracket > 1) {
        return TextSpan(
          text: token.substring(1, closingBracket),
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        );
      }
    }

    if (token.startsWith('http://') || token.startsWith('https://')) {
      return TextSpan(
        text: token,
        style: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      );
    }

    if (token.startsWith('*') && token.endsWith('*') && token.length > 2) {
      return TextSpan(
        text: token.substring(1, token.length - 1),
        style: const TextStyle(fontStyle: FontStyle.italic),
      );
    }

    if (token.startsWith('_') && token.endsWith('_') && token.length > 2) {
      return TextSpan(
        text: token.substring(1, token.length - 1),
        style: const TextStyle(fontStyle: FontStyle.italic),
      );
    }

    return TextSpan(text: token);
  }

  Future<void> _copyMessageToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Message copied'),
          duration: Duration(milliseconds: 1200),
        ),
      );
  }

  Widget _buildErrorBubble(bool isDark, String text) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1215) : const Color(0xFFFFE4E6),
          border: Border.all(color: const Color(0xFFEF4444)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 12,
            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmLargeCurrentPromptGeneration(int currentChars) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final subtitleColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);

    final shouldGenerate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        title: const Text(
          'LARGE CURRENT INPUT DETECTED',
          style: TextStyle(
            fontFamily: 'Courier',
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Your current prompt content is $currentChars characters (limit: $_currentPromptWarningChars). This may be unstable or crash the app. Continue anyway?',
          style: TextStyle(
            fontFamily: 'Courier',
            color: subtitleColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'Courier',
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CONTINUE',
              style: TextStyle(
                fontFamily: 'Courier',
                color: nothingRed,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldGenerate ?? false;
  }

  Future<bool> _confirmContextAlmostFullGeneration(int totalChars) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final subtitleColor =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);

    var dontShowAgainThisSession = false;

    final shouldGenerate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: bg,
          title: const Text(
            'CONTEXT IS ALMOST FULL',
            style: TextStyle(
              fontFamily: 'Courier',
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your total prompt context is $totalChars characters (limit: $_totalContextWarningChars). This may be unstable or crash the app. Continue anyway?',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: dontShowAgainThisSession,
                    onChanged: (value) {
                      setStateDialog(() {
                        dontShowAgainThisSession = value ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Don\'t show again for this session',
                      style: TextStyle(fontFamily: 'Courier', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: Colors.grey,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (dontShowAgainThisSession) {
                  _skipContextAlmostFullWarningForSession = true;
                }
                Navigator.pop(context, true);
              },
              child: const Text(
                'CONTINUE',
                style: TextStyle(
                  fontFamily: 'Courier',
                  color: nothingRed,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return shouldGenerate ?? false;
  }

  Future<void> _showQueuedAttachmentContextSnackBar() async {
    if (!mounted) return;

    final imagesForExtraction = List<XFile>.from(_pendingImages)
        .take(_maxAttachmentItemsForExtraction)
        .toList();
    final filesForExtraction = List<XFile>.from(_pendingFiles)
        .take(_maxAttachmentItemsForExtraction)
        .toList();

    final extractedImageText = await _extractTextFromImages(imagesForExtraction);
    final extractedFileText = await _extractTextFromFiles(filesForExtraction);

    final combinedText = [
      extractedImageText.trim(),
      extractedFileText.trim(),
    ].where((text) => text.isNotEmpty).join(' ');

    if (!mounted) return;

    final currentPromptChars = _buildInferencePrompt(
      combinedText,
      includeHistory: false,
    ).length;
    final hasQueue = _pendingImages.isNotEmpty || _pendingFiles.isNotEmpty;
    if (!hasQueue || currentPromptChars <= _currentPromptWarningChars) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('App might crash or be unstable due to long context.'),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

class _TypingDots extends StatelessWidget {
  final double progress;
  final Color color;

  const _TypingDots({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    final values = [0.0, 0.22, 0.44];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final offset in values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _dot(offset),
          ),
      ],
    );
  }

  Widget _dot(double offset) {
    final phase = (progress - offset + 1.0) % 1.0;
    final intensity = 1.0 - (phase - 0.5).abs() * 2;
    final clamped = intensity.clamp(0.2, 1.0);

    return Transform.translate(
      offset: Offset(0, -1.5 * clamped),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35 + (0.65 * clamped)),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  final bool isDark;
  DotPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.2 : 0.1)
      ..style = PaintingStyle.fill;

    const spacing = 16.0;
    const radius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
