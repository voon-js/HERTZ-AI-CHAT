import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

    return Positioned.fill(
      child: ClipRect(
        child: Stack(
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
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),

            // Bottom sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                offset: isOpen ? Offset.zero : const Offset(0, 1.05),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: isOpen ? 1.0 : 0.0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: SafeArea(
                      top: false,
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
                              border: Border(
                                bottom: BorderSide(color: borderColor),
                              ),
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
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'CURRENT MODEL',
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: subtitleColor,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: onClose,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: nothingRed),
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
                                                  currentModel.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontFamily: 'Courier',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: nothingRed,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Installed on-device model',
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
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: nothingRed,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No other placeholder models are configured yet.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
