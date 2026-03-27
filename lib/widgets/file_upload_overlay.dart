import 'package:flutter/material.dart';

class FileUploadOverlay extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const FileUploadOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  static const _options = [
    {'icon': 'camera', 'label': 'CAMERA'},
    {'icon': 'gallery', 'label': 'GALLERY'},
    {'icon': 'document', 'label': 'DOCUMENT'},
    {'icon': 'files', 'label': 'FILES'},
  ];

  IconData _iconFor(String key) {
    switch (key) {
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'gallery':
        return Icons.image_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'files':
        return Icons.folder_outlined;
      default:
        return Icons.attach_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? const Color(0xFF27272A) : Colors.black;
    final circleIconColor =
        isDark ? const Color(0xFFD4D4D8) : Colors.black;
    final labelColor =
        isDark ? const Color(0xFFA1A1AA) : Colors.black;
    final handleColor =
        isDark ? const Color(0xFF3F3F46) : Colors.black;

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
          bottom: isOpen ? 0 : -300,
          child: Container(
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
                  margin: const EdgeInsets.only(top: 16, bottom: 24),
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTACHMENT',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: _options.map((opt) {
                          return _UploadOption(
                            icon: _iconFor(opt['icon']!),
                            label: opt['label']!,
                            circleIconColor: circleIconColor,
                            labelColor: labelColor,
                            borderColor: borderColor,
                            isDark: isDark,
                          );
                        }).toList(),
                      ),
                    ],
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

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color circleIconColor;
  final Color labelColor;
  final Color borderColor;
  final bool isDark;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.circleIconColor,
    required this.labelColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
              color: Colors.transparent,
            ),
            child: Icon(icon, color: circleIconColor, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: labelColor,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}
