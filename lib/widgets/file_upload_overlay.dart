import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class FileUploadOverlay extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(List<XFile>)? onImagesSelected;
  final Function(List<XFile>)? onFilesSelected;

  const FileUploadOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.onImagesSelected,
    this.onFilesSelected,
  });

  static const _options = [
    {'icon': 'camera', 'label': 'CAMERA'},
    {'icon': 'photos', 'label': 'PHOTOS'},
    {'icon': 'files', 'label': 'FILES'},
  ];

  IconData _iconFor(String key) {
    switch (key) {
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'photos':
        return Icons.image_outlined;
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
                color: Colors.black.withValues(alpha: 0.4),
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
                  padding: const EdgeInsets.fromLTRB(35, 0, 35, 40),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_options.length, (index) {
                          final opt = _options[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == _options.length - 1 ? 0 : 24,
                            ),
                            child: _UploadOption(
                              icon: _iconFor(opt['icon']!),
                              label: opt['label']!,
                              optionKey: opt['icon']!,
                              circleIconColor: circleIconColor,
                              labelColor: labelColor,
                              borderColor: borderColor,
                              isDark: isDark,
                              onImagesSelected: onImagesSelected,
                              onFilesSelected: onFilesSelected,
                              onClose: onClose,
                            ),
                          );
                        }),
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
  final String optionKey;
  final Color circleIconColor;
  final Color labelColor;
  final Color borderColor;
  final bool isDark;
  final Function(List<XFile>)? onImagesSelected;
  final Function(List<XFile>)? onFilesSelected;
  final VoidCallback? onClose;

  const _UploadOption({
    required this.icon,
    required this.label,
    required this.optionKey,
    required this.circleIconColor,
    required this.labelColor,
    required this.borderColor,
    required this.isDark,
    this.onImagesSelected,
    this.onFilesSelected,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (optionKey == 'camera') {
          final picker = ImagePicker();
          final image = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85,
          );
          if (image != null) {
            onImagesSelected?.call([image]);
            onClose?.call();
          }
        } else if (optionKey == 'photos') {
          final picker = ImagePicker();
          final images = await picker.pickMultiImage();
          if (images.isNotEmpty) {
            onImagesSelected?.call(images);
            onClose?.call();
          }
        } else if (optionKey == 'files') {
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            type: FileType.custom,
            allowedExtensions: const [
              'pdf',
              'docx',
              'txt',
              'md',
              'csv',
              'json',
              'xml',
              'html',
              'htm',
              'log',
              'rtf',
            ],
          );
          final files = result?.xFiles ?? const <XFile>[];
          if (files.isNotEmpty) {
            onFilesSelected?.call(files);
            onClose?.call();
          }
        }
      },
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
