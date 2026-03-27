import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _mockChats = [
  {'id': '1', 'title': 'REACT NATIVE VS FLUTTER', 'date': 'TODAY'},
  {'id': '2', 'title': 'EXPLAIN QUANTUM COMPUTING', 'date': 'TODAY'},
  {
    'id': '3',
    'title': 'DINNER RECIPES WITH CHICKEN',
    'date': 'YESTERDAY'
  },
  {
    'id': '4',
    'title': 'WRITE A PYTHON SCRIPT FOR SCRAPING',
    'date': 'YESTERDAY'
  },
  {'id': '5', 'title': 'HOW TO CENTER A DIV', 'date': 'PREVIOUS 7 DAYS'},
  {
    'id': '6',
    'title': 'BEST SCI-FI MOVIES OF 2023',
    'date': 'PREVIOUS 7 DAYS'
  },
  {
    'id': '7',
    'title': 'DEBUG THIS TAILWIND CSS ISSUE',
    'date': 'PREVIOUS 7 DAYS'
  },
  {
    'id': '8',
    'title': 'TRANSLATE ENGLISH TO JAPANESE',
    'date': 'PREVIOUS 30 DAYS'
  },
];

class SidebarWidget extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  const SidebarWidget({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onOpenSettings,
  });

  Map<String, List<Map<String, String>>> get _groupedChats {
    final Map<String, List<Map<String, String>>> grouped = {};
    for (final chat in _mockChats) {
      final date = chat['date']!;
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(chat);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final chatTextColor =
        isDark ? const Color(0xFFD4D4D8) : Colors.black;
    final dotBg =
        isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB);
    final dottedLine =
        isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB);
    final inputBorder =
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

        // Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          left: isOpen ? 0 : -320,
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
                    border:
                        Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Column(
                    children: [
                      // New Chat button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add,
                              size: 18, color: Colors.white),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search input
                      TextField(
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
                          prefixIcon: Icon(Icons.search,
                              size: 16, color: textColor),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: inputBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: inputBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: nothingRed),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat list
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _groupedChats.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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
                                    entry.key,
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
                                      margin: const EdgeInsets.only(
                                          left: 3),
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
                                        children: entry.value
                                            .map((chat) => InkWell(
                                                  onTap: () {},
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(2),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      vertical: 8,
                                                      horizontal: 8,
                                                    ),
                                                    child: Align(
                                                      alignment:
                                                          Alignment
                                                              .centerLeft,
                                                      child: Text(
                                                        chat['title']!,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'Courier',
                                                          fontSize: 12,
                                                          color:
                                                              chatTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
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
                    onTap: onOpenSettings,
                    borderRadius: BorderRadius.circular(2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined,
                              color: textColor, size: 20),
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
