import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _models = [
  {
    'id': 'gpt-4o',
    'name': 'GPT-4o',
    'description': 'Most capable model, great for complex tasks'
  },
  {
    'id': 'gpt-4o-mini',
    'name': 'GPT-4o Mini',
    'description': 'Fast and efficient for everyday tasks'
  },
  {
    'id': 'claude-3-5',
    'name': 'Claude 3.5 Sonnet',
    'description': 'Excellent at coding and reasoning'
  },
  {
    'id': 'claude-3-haiku',
    'name': 'Claude 3 Haiku',
    'description': 'Lightning fast responses'
  },
  {
    'id': 'gemini-1-5',
    'name': 'Gemini 1.5 Pro',
    'description': 'Large context window'
  },
  {
    'id': 'llama-3',
    'name': 'Llama 3.1',
    'description': 'Open source powerhouse'
  },
];

class ModelSelectorOverlay extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String currentModel;
  final ValueChanged<String> onSelectModel;

  const ModelSelectorOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.currentModel,
    required this.onSelectModel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final handleColor =
        isDark ? const Color(0xFF3F3F46) : Colors.black;
    final radioInactiveBorder =
        isDark ? const Color(0xFF52525B) : Colors.black;

    return Stack(
      children: [
        // Backdrop
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isOpen ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isOpen,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ),
        ),

        // Bottom sheet
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: isOpen ? 0 : -600,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(top: 16, bottom: 16),
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SELECT MODEL',
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),

                // Model list
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      children: _models.map((model) {
                        final isSelected =
                            currentModel == model['name'];
                        return GestureDetector(
                          onTap: () {
                            onSelectModel(model['name']!);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? nothingRed
                                    : Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        model['name']!.toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'Courier',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? nothingRed
                                              : textColor,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        model['description']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? nothingRed
                                          : radioInactiveBorder,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration:
                                                const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: nothingRed,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
