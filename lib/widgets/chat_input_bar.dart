import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final VoidCallback onOpenFileUpload;

  const ChatInputBar({super.key, required this.onOpenFileUpload});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? const Color(0xFF3F3F46) : Colors.black;
    final topBorderColor =
        isDark ? const Color(0xFF27272A) : Colors.black;
    final placeholderColor =
        isDark ? const Color(0xFF52525B) : const Color(0xFF9CA3AF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border:
            Border(top: BorderSide(color: topBorderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Plus button
          GestureDetector(
            onTap: widget.onOpenFileUpload,
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
                color: Colors.transparent,
              ),
              child: Icon(Icons.add, color: textColor, size: 20),
            ),
          ),
          const SizedBox(width: 8),

          // Text input
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 52),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _hasText ? nothingRed : borderColor,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: TextField(
                controller: _controller,
                maxLines: null,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 13,
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: 'TYPE MESSAGE...',
                  hintStyle: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 13,
                    color: placeholderColor,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: _hasText ? () {} : null,
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hasText ? nothingRed : Colors.transparent,
                border: Border.all(
                  color: _hasText
                      ? nothingRed
                      : (isDark
                          ? const Color(0xFF3F3F46)
                          : Colors.black),
                ),
              ),
              child: Icon(
                Icons.send,
                size: 18,
                color: _hasText
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF52525B)
                        : const Color(0xFF9CA3AF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
