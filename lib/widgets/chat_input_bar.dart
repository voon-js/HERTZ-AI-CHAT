import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final VoidCallback onOpenFileUpload;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final List<XFile> pendingImages;
  final List<XFile> pendingFiles;
  final ValueChanged<int> onRemovePendingImage;
  final ValueChanged<int> onRemovePendingFile;
  final bool isInputEnabled;
  final bool areActionsEnabled;
  final bool isGenerating;

  const ChatInputBar({
    super.key,
    required this.onOpenFileUpload,
    required this.onSend,
    required this.onStop,
    required this.pendingImages,
    required this.pendingFiles,
    required this.onRemovePendingImage,
    required this.onRemovePendingFile,
    this.isInputEnabled = true,
    this.areActionsEnabled = true,
    this.isGenerating = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  void _submit() {
    if (!widget.areActionsEnabled || widget.isGenerating) return;
    final text = _controller.text.trim();
    if (text.isEmpty && widget.pendingImages.isEmpty && widget.pendingFiles.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
  }

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
    final hasAttachments = widget.pendingImages.isNotEmpty || widget.pendingFiles.isNotEmpty;
    final canSend = (_hasText || hasAttachments) &&
        widget.areActionsEnabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border:
            Border(top: BorderSide(color: topBorderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasAttachments)
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.pendingImages.length + widget.pendingFiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isImage = index < widget.pendingImages.length;
                  if (isImage) {
                    final image = widget.pendingImages[index];
                    return Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.file(
                              File(image.path),
                              fit: BoxFit.cover,
                              cacheWidth: 220,
                              cacheHeight: 220,
                              filterQuality: FilterQuality.low,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.broken_image_outlined,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: GestureDetector(
                            onTap: () => widget.onRemovePendingImage(index),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final file = widget.pendingFiles[index - widget.pendingImages.length];
                  final fileName = file.name;
                  final extension = fileName.contains('.')
                      ? fileName.split('.').last.toUpperCase()
                      : 'FILE';
                  return Stack(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, color: textColor, size: 22),
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
                          ],
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => widget.onRemovePendingFile(index - widget.pendingImages.length),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (hasAttachments)
            const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Plus button
              GestureDetector(
                onTap: widget.areActionsEnabled ? widget.onOpenFileUpload : null,
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
                  constraints: const BoxConstraints(minHeight: 52, maxHeight: 132),
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
                    enabled: widget.isInputEnabled,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textAlignVertical: TextAlignVertical.center,
                    onSubmitted: (_) => _submit(),
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
                onTap: widget.isGenerating
                    ? widget.onStop
                    : (canSend ? _submit : null),
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isGenerating
                        ? nothingRed
                        : canSend
                            ? nothingRed
                            : Colors.transparent,
                    border: Border.all(
                      color: widget.isGenerating
                          ? nothingRed
                          : canSend
                              ? nothingRed
                              : (isDark
                                  ? const Color(0xFF3F3F46)
                                  : Colors.black),
                    ),
                  ),
                  child: Icon(
                    widget.isGenerating ? Icons.stop : Icons.send,
                    size: 18,
                    color: widget.isGenerating
                        ? Colors.white
                        : canSend
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF52525B)
                                : const Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
