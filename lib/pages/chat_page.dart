import 'package:flutter/material.dart';
import '../widgets/top_bar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/file_upload_overlay.dart';
import '../widgets/model_selector_overlay.dart';

class ChatPage extends StatefulWidget {
  final VoidCallback onNavigateSettings;

  const ChatPage({super.key, required this.onNavigateSettings});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isSidebarOpen = false;
  bool _isFileUploadOpen = false;
  bool _isModelSelectorOpen = false;
  String _currentModel = 'GPT-4o';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Column(
            children: [
              TopBar(
                onOpenSidebar: () =>
                    setState(() => _isSidebarOpen = true),
                onOpenModelSelector: () =>
                    setState(() => _isModelSelectorOpen = true),
                currentModel: _currentModel,
              ),
              // Main Chat Area
              Expanded(
                child: Stack(
                  children: [
                    // Dot matrix background
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DotPatternPainter(isDark: isDark),
                      ),
                    ),
                    Center(
                      child: Column(
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
                            'SYSTEM READY',
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
                                const BoxConstraints(maxWidth: 280),
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
                              'AWAITING INPUT...',
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
                      ),
                    ),
                  ],
                ),
              ),
              ChatInputBar(
                onOpenFileUpload: () =>
                    setState(() => _isFileUploadOpen = true),
              ),
            ],
          ),

          // Overlays
          SidebarWidget(
            isOpen: _isSidebarOpen,
            onClose: () => setState(() => _isSidebarOpen = false),
            onOpenSettings: () {
              setState(() => _isSidebarOpen = false);
              widget.onNavigateSettings();
            },
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
        ],
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
          .withOpacity(isDark ? 0.2 : 0.1)
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
