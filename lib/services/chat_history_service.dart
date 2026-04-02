import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

class ChatConversation {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  ChatConversation copyWith({
    String? id,
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final messageList = (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();

    return ChatConversation(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'New Chat',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
              DateTime.now(),
      messages: messageList,
    );
  }

  String get previewText {
    for (int i = messages.length - 1; i >= 0; i--) {
      final text = messages[i].text.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return 'No messages yet';
  }
}

class ChatHistoryService {
  static const _storageKey = 'chat_history_v1';

  Future<List<ChatConversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final conversations = decoded
          .whereType<Map<String, dynamic>>()
          .map(ChatConversation.fromJson)
          .toList();
      conversations.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
      return conversations;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConversations(List<ChatConversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      conversations
          .map((conversation) => conversation.toJson())
          .toList(),
    );
    await prefs.setString(_storageKey, payload);
  }

  Future<void> upsertConversation(
    List<ChatConversation> conversations,
    ChatConversation conversation,
  ) async {
    final updated = [...conversations];
    final index = updated.indexWhere((item) => item.id == conversation.id);
    if (index >= 0) {
      updated[index] = conversation;
    } else {
      updated.insert(0, conversation);
    }
    updated.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    await saveConversations(updated);
  }

  Future<void> deleteConversation(
    List<ChatConversation> conversations,
    String conversationId,
  ) async {
    final updated = conversations
        .where((conversation) => conversation.id != conversationId)
        .toList();
    await saveConversations(updated);
  }

  String buildTitleFromMessages(List<ChatMessage> messages) {
    for (final message in messages) {
      if (!message.isUser) continue;
      final clean = message.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (clean.isEmpty) continue;
      return _truncate(clean, 36);
    }
    return 'New Chat';
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength).trimRight()}...';
  }
}
