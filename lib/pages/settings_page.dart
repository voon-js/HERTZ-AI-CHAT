import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'about_page.dart';
import 'notification_settings_page.dart';
import 'privacy_security_page.dart';

class SettingsPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onBack;

  const SettingsPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final hoverBg =
        isDark ? const Color(0xFF18181B) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
          // Header
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(2),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back,
                        color: textColor, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SETTINGS',
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

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appearance Section
                  _SectionHeader(
                    label: 'APPEARANCE',
                    dotColor: nothingRed,
                    subtitleColor: subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDark
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                                color: textColor,
                                size: 20,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'DARK MODE',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          _NothingToggle(
                            value: isDark,
                            onChanged: (_) => onToggleTheme(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // General Section
                  _SectionHeader(
                    label: 'GENERAL',
                    dotColor: isDark
                        ? const Color(0xFF52525B)
                        : Colors.black,
                    subtitleColor: subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Column(
                      children: [
                        _SettingsRow(
                          icon: Icons.notifications_outlined,
                          label: 'NOTIFICATIONS',
                          description:
                              'Alerts, sounds, and future reminder controls.',
                          textColor: textColor,
                          hoverBg: hoverBg,
                          borderColor: borderColor,
                          showDivider: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NotificationSettingsPage(isDark: isDark),
                              ),
                            );
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.shield_outlined,
                          label: 'PRIVACY & SECURITY',
                          description:
                              'Local storage, device access, and model privacy.',
                          textColor: textColor,
                          hoverBg: hoverBg,
                          borderColor: borderColor,
                          showDivider: true,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PrivacySecurityPage(isDark: isDark),
                              ),
                            );
                          },
                        ),
                        _SettingsRow(
                          icon: Icons.info_outline,
                          label: 'ABOUT',
                          description:
                              'Build details, app purpose, and local AI notes.',
                          textColor: textColor,
                          hoverBg: hoverBg,
                          borderColor: borderColor,
                          showDivider: false,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AboutPage(isDark: isDark),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final Color textColor;
  final Color hoverBg;
  final Color borderColor;
  final bool showDivider;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.description,
    required this.textColor,
    required this.hoverBg,
    required this.borderColor,
    required this.showDivider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          hoverColor: hoverBg,
          splashColor: hoverBg.withValues(alpha: 0.35),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 2,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: textColor, size: 20),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: borderColor),
      ],
    );
  }
}

class _NothingToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NothingToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 48,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? nothingRed : Colors.black,
            width: 1,
          ),
          color: Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment:
                value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? nothingRed : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
