import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  final bool isDark;

  const NotificationSettingsPage({super.key, required this.isDark});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = true;
  bool _downloadsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled =
        await _notificationService.areDownloadNotificationsEnabled();
    if (!mounted) return;

    setState(() {
      _downloadsEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _onToggleDownloads(bool value) async {
    if (!mounted) return;

    setState(() {
      _downloadsEnabled = value;
    });

    if (value) {
      final granted = await _notificationService.requestPermissionIfNeeded();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _downloadsEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission is required to enable this.'),
          ),
        );
        return;
      }
    }

    await _notificationService.setDownloadNotificationsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);

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
                    'NOTIFICATIONS',
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
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            label: 'MODEL DOWNLOADS',
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
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.downloading_outlined,
                                    color: textColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DOWNLOAD PROGRESS',
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Show model download progress in Android notification center.',
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            fontSize: 11,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _NothingToggle(
                                    value: _downloadsEnabled,
                                    onChanged: _onToggleDownloads,
                                  ),
                                ],
                              ),
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
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
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
