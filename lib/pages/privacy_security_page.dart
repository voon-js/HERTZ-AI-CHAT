import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrivacySecurityPage extends StatelessWidget {
  final bool isDark;

  const PrivacySecurityPage({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(2),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back, color: textColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PRIVACY & SECURITY',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      label: 'YOUR DATA',
                      dotColor: isDark ? const Color(0xFF52525B) : Colors.black,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      borderColor: borderColor,
                      backgroundColor: cardBg,
                      titleColor: textColor,
                      bodyColor: subtitleColor,
                      children: const [
                        'Chats are stored locally on this device using SharedPreferences.',
                        'No account is required to use the app.',
                        'Conversation history stays on your phone unless you remove it manually.',
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      label: 'SECURITY NOTES',
                      dotColor: nothingRed,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      borderColor: borderColor,
                      backgroundColor: cardBg,
                      titleColor: textColor,
                      bodyColor: subtitleColor,
                      children: const [
                        'The AI model runs locally, which keeps prompts off a remote server.',
                        'Use the app lock provided by your device if you want another layer of protection.',
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color dotColor;
  final Color subtitleColor;

  const _SectionHeader({
    required this.label,
    required this.dotColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: subtitleColor,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color borderColor;
  final Color backgroundColor;
  final Color titleColor;
  final Color bodyColor;
  final List<String> children;

  const _InfoCard({
    required this.borderColor,
    required this.backgroundColor,
    required this.titleColor,
    required this.bodyColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: bodyColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        height: 1.5,
                        color: bodyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
