import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/chat_history_service.dart';
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
    unawaited(_bootstrap());
  }

  void _triggerBorderShine() {
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

  Future<void> _sendPrompt(String prompt) async {
    if (_isGenerating || _isInitializing) return;

    final now = DateTime.now();
    final conversationId = _activeConversationId ?? _createConversationId();
    setState(() {
      _activeConversationId = conversationId;
      _messages = [
        ..._messages,
        ChatMessage(
          text: prompt,
          isUser: true,
          timestamp: now,
        ),
        ChatMessage(
          text: '',
          isUser: false,
          timestamp: now,
        ),
      ];
      _isGenerating = true;
      _errorText = null;
      _triggerBorderShine();
    });
    _scrollChatToBottom();
    _scheduleHistorySave();

    try {
      await for (final token in _ai.sendMessage(prompt, maxTokens: 180)) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = ChatMessage(
            text: last.text + token,
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
                  onOpenModelSelector: () =>
                      setState(() => _isModelSelectorOpen = true),
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
                  if (!snapshot.hasData)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    )
                  else ...[
                    if (availableModels.isNotEmpty) ...[
                      _buildSetupSectionHeader('AVAILABLE', subtitleColor),
                      const SizedBox(height: 8),
                      ...availableModels.map(
                        (model) => _buildSetupModelCard(
                          model,
                          isDark: isDark,
                          subtitleColor: subtitleColor,
                          borderColor: borderColor,
                          selected: _selectedFirstLoadModelIds.contains(model.id),
                          enabled: !_isFirstLoadInstalling,
                          onTap: () {
                            setState(() {
                              if (_selectedFirstLoadModelIds.contains(model.id)) {
                                _selectedFirstLoadModelIds.remove(model.id);
                              } else {
                                _selectedFirstLoadModelIds.add(model.id);
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
          child: Text(
            message.text.isEmpty ? '...' : message.text,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              color: textColor,
            ),
          ),
        ),
      ),
    );
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
