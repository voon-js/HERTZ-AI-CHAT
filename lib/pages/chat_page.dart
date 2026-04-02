import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';
import '../services/chat_history_service.dart';
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
    with SingleTickerProviderStateMixin {
  bool _isSidebarOpen = false;
  bool _isFileUploadOpen = false;
  bool _isModelSelectorOpen = false;
  String _currentModel = 'TinyLlama Q4';

  final AIService _ai = AIService();
  final ChatHistoryService _historyService = ChatHistoryService();
  final List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  String? _activeConversationId;
  final ScrollController _chatScrollController = ScrollController();
  bool _isInitializing = true;
  bool _isGenerating = false;
  bool _showFirstLoadScreen = false;
  double? _firstLoadProgress;
  String _firstLoadStatus = 'Preparing TinyLlama Q4...';
  String? _errorText;
  late final AnimationController _pulseController;
  Timer? _historySaveTimer;
  bool _isHistorySaveInProgress = false;
  bool _isHistorySaveQueued = false;

  static const String _modelName = 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  static const String _modelUrl =
      'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  static const String _firstLoadDoneKey = 'tinyllama_q4_first_load_done_v1';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    unawaited(_bootstrap());
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

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLoadDone = prefs.getBool(_firstLoadDoneKey) ?? false;

    if (!mounted) return;
    setState(() {
      _showFirstLoadScreen = !firstLoadDone;
      _firstLoadProgress = null;
      _firstLoadStatus = 'Preparing TinyLlama Q4...';
    });

    unawaited(_loadHistory());

    final initialized = await _initModel(isFirstLoad: !firstLoadDone);

    if (!mounted) return;
    if (!firstLoadDone && initialized) {
      await prefs.setBool(_firstLoadDoneKey, true);
    }

    if (mounted) {
      setState(() {
        _showFirstLoadScreen = false;
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
      }
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

  Future<bool> _initModel({required bool isFirstLoad}) async {
    setState(() {
      _isInitializing = true;
      _errorText = null;
      if (isFirstLoad) {
        _firstLoadStatus = 'Preparing TinyLlama Q4...';
        _firstLoadProgress = null;
      }
    });

    try {
      await _ai.initialize(
        modelName: _modelName,
        modelUrl: _modelUrl,
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
                      ? 'Downloading TinyLlama Q4...'
                      : 'Downloading TinyLlama Q4... $percent%';
                });
              }
            : null,
      );
      if (!mounted) return false;
      setState(() {
        _isInitializing = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _isInitializing = false;
        _errorText = 'Init failed: $e';
      });
      return false;
    }
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
                                      _errorText ??
                                          (_isInitializing
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
                    isInputEnabled: !_isInitializing,
                    areActionsEnabled: !_isInitializing && !_isGenerating,
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
                setState(() {
                  _currentModel = model;
                  _isModelSelectorOpen = false;
                });
              },
            ),
            if (_showFirstLoadScreen)
              Positioned.fill(
                child: _buildFirstLoadScreen(isDark),
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
    final trackColor =
        isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB);

    return ColoredBox(
      color: bg,
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                'Loading TinyLlama Q4 model',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _firstLoadProgress,
                  minHeight: 8,
                  backgroundColor: trackColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(nothingRed),
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
            ],
          ),
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
