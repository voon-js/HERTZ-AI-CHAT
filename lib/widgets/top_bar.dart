import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  final VoidCallback onOpenSidebar;
  final VoidCallback onOpenModelSelector;
  final VoidCallback onOpenModelInfo;
  final String currentModel;

  const TopBar({
    super.key,
    required this.onOpenSidebar,
    required this.onOpenModelSelector,
    required this.onOpenModelInfo,
    required this.currentModel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? const Color(0xFF27272A) : Colors.black;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onOpenSidebar,
            borderRadius: BorderRadius.circular(2),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.menu, color: textColor, size: 24),
            ),
          ),
          InkWell(
            onTap: onOpenModelSelector,
            borderRadius: BorderRadius.circular(2),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    currentModel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down,
                      color: textColor, size: 18),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onOpenModelInfo,
            borderRadius: BorderRadius.circular(2),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.info_outline, color: textColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
