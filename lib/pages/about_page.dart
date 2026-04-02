import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  final bool isDark;

  const AboutPage({super.key, required this.isDark});

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
                    'ABOUT',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 4,
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
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HERTZ AI CHAT',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: 2.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 12,
                              color: subtitleColor,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      label: 'DEVELOPER',
                      dotColor: nothingRed,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      borderColor: borderColor,
                      backgroundColor: cardBg,
                      title: 'VOONJS',
                      titleColor: textColor,
                      bodyColor: subtitleColor,
                      lines: const [
                        'Built with Flutter + llama.cpp',
                        'local-first AI chat experience',
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      label: 'APP VERSION',
                      dotColor: isDark ? const Color(0xFF52525B) : Colors.black,
                      subtitleColor: subtitleColor,
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      borderColor: borderColor,
                      backgroundColor: cardBg,
                      title: 'CURRENT BUILD',
                      titleColor: textColor,
                      bodyColor: subtitleColor,
                      lines: const [
                        'Version: 1.0.0',
                        'Release channel: local build',
                        'Target: Android (arm64)',
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
  final String title;
  final Color titleColor;
  final Color bodyColor;
  final List<String> lines;

  const _InfoCard({
    required this.borderColor,
    required this.backgroundColor,
    required this.title,
    required this.titleColor,
    required this.bodyColor,
    required this.lines,
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
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: titleColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 12,
                  height: 1.4,
                  color: bodyColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
