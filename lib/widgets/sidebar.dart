import 'package:flutter/material.dart';

import '../services/chat_history_service.dart';
import '../theme/app_theme.dart';

class SidebarWidget extends StatefulWidget {
  final bool isOpen;
  final bool isBusy;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<String> onDeleteConversation;
  final List<ChatConversation> conversations;
  final String? selectedConversationId;

  const SidebarWidget({
    super.key,
    required this.isOpen,
    required this.isBusy,
    required this.onClose,
    required this.onOpenSettings,
    required this.onNewChat,
    required this.onSelectConversation,
    required this.onDeleteConversation,
    required this.conversations,
    required this.selectedConversationId,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _groupOrder = [
    'TODAY',
    'YESTERDAY',
    'PREVIOUS 7 DAYS',
    'PREVIOUS 30 DAYS',
    'OLDER',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatConversation> get _filteredConversations {
    final conversations = [...widget.conversations]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    if (_searchQuery.isEmpty) {
      return conversations;
    }

    return conversations.where((conversation) {
      final title = conversation.title.toLowerCase();
      final preview = conversation.previewText.toLowerCase();
      final content = conversation.messages
          .map((message) => message.text)
          .join(' ')
          .toLowerCase();
      return title.contains(_searchQuery) ||
          preview.contains(_searchQuery) ||
          content.contains(_searchQuery);
    }).toList();
  }

  Map<String, List<ChatConversation>> get _groupedConversations {
    final grouped = <String, List<ChatConversation>>{};
    for (final conversation in _filteredConversations) {
      final bucket = _bucketFor(conversation.updatedAt);
      grouped.putIfAbsent(bucket, () => []);
      grouped[bucket]!.add(conversation);
    }
    return grouped;
  }

  String _bucketFor(DateTime updatedAt) {
    final now = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(updatedAt);
    final difference = now.difference(date).inDays;

    if (difference <= 0) return 'TODAY';
    if (difference == 1) return 'YESTERDAY';
    if (difference <= 7) return 'PREVIOUS 7 DAYS';
    if (difference <= 30) return 'PREVIOUS 30 DAYS';
    return 'OLDER';
  }

  bool _isSelected(ChatConversation conversation) =>
      widget.selectedConversationId == conversation.id;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final chatTextColor = isDark ? const Color(0xFFD4D4D8) : Colors.black;
    final dotBg = isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB);
    final dottedLine = isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB);
    final inputBorder = isDark ? const Color(0xFF3F3F46) : Colors.black;
    final selectedSurface = isDark ? const Color(0xFF18181B) : const Color(0xFFF3F4F6);

    return Stack(
      children: [
        // Backdrop
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: widget.isOpen ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !widget.isOpen,
            child: GestureDetector(
              onTap: widget.onClose,
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),

        // Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          left: widget.isOpen ? 0 : -320,
          top: 0,
          bottom: 0,
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              children: [
                // Top section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.isBusy
                              ? null
                              : () {
                                  widget.onNewChat();
                                  widget.onClose();
                                },
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text(
                            'NEW CHAT',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: nothingRed,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: nothingRed.withValues(alpha: 0.45),
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        enabled: !widget.isBusy,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 12,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'SEARCH CHATS...',
                          hintStyle: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                          prefixIcon: Icon(Icons.search, size: 16, color: textColor),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: inputBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: inputBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: nothingRed),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat history
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _filteredConversations.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.conversations.isEmpty
                                      ? 'NO SAVED CHATS YET'
                                      : 'NO RESULTS FOUND',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.conversations.isEmpty
                                      ? 'Start a chat and it will appear here automatically.'
                                      : 'Try a different search term.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _groupOrder
                                .where((group) =>
                                    (_groupedConversations[group] ?? const []).isNotEmpty)
                                .map((group) {
                              final conversations = _groupedConversations[group]!;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: dotBg,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          group,
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: subtitleColor,
                                            letterSpacing: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            width: 1,
                                            margin: const EdgeInsets.only(left: 3),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: dottedLine,
                                                  width: 1,
                                                  style: BorderStyle.solid,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              children: conversations.map((conversation) {
                                                final selected = _isSelected(conversation);
                                                final preview = conversation.previewText;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: GestureDetector(
                                                    onTap: widget.isBusy
                                                        ? null
                                                        : () {
                                                            widget.onSelectConversation(conversation.id);
                                                            widget.onClose();
                                                          },
                                                    onLongPress: widget.isBusy
                                                        ? null
                                                        : () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (context) => AlertDialog(
                                                                backgroundColor: bg,
                                                                title: const Text(
                                                                  'DELETE CHAT?',
                                                                  style: TextStyle(
                                                                    fontFamily: 'Courier',
                                                                    letterSpacing: 2,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                                content: Text(
                                                                  'This cannot be undone.',
                                                                  style: TextStyle(
                                                                    fontFamily: 'Courier',
                                                                    color: subtitleColor,
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(context),
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
                                                                      Navigator.pop(context);
                                                                      widget.onDeleteConversation(conversation.id);
                                                                    },
                                                                    child: const Text(
                                                                      'DELETE',
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
                                                          },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 180),
                                                      padding: const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 10,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: selected
                                                            ? selectedSurface
                                                            : Colors.transparent,
                                                        border: Border.all(
                                                          color: selected
                                                              ? nothingRed
                                                              : Colors.transparent,
                                                        ),
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment.start,
                                                        children: [
                                                          Container(
                                                            width: 18,
                                                            height: 18,
                                                            margin: const EdgeInsets.only(top: 1),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              border: Border.all(
                                                                color: selected
                                                                    ? nothingRed
                                                                    : subtitleColor,
                                                                width: 1,
                                                              ),
                                                              color: selected
                                                                  ? nothingRed
                                                                  : Colors.transparent,
                                                            ),
                                                            child: selected
                                                                ? const Icon(
                                                                    Icons.chat_bubble_outline,
                                                                    size: 10,
                                                                    color: Colors.white,
                                                                  )
                                                                : null,
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  conversation.title.toUpperCase(),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontFamily: 'Courier',
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: selected
                                                                        ? nothingRed
                                                                        : chatTextColor,
                                                                    letterSpacing: 1.5,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                  preview,
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(
                                                                    fontFamily: 'Courier',
                                                                    fontSize: 11,
                                                                    color: subtitleColor,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),

                // Settings button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: InkWell(
                    onTap: widget.isBusy ? null : widget.onOpenSettings,
                    borderRadius: BorderRadius.circular(2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, color: textColor, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            'SETTINGS',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 13,
                              color: textColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
