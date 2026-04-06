import 'package:flutter/material.dart';
import '../services/generation_settings.dart';
import '../theme/app_theme.dart';

class GenerationSettingsPage extends StatefulWidget {
  final bool isDark;

  const GenerationSettingsPage({super.key, required this.isDark});

  @override
  State<GenerationSettingsPage> createState() => _GenerationSettingsPageState();
}

class _GenerationSettingsPageState extends State<GenerationSettingsPage> {
  late GenerationSettingsService _settingsService;
  late GenerationSettings _settings;
  late GenerationSettings _workingSettings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _settingsService = GenerationSettingsService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.load();
    setState(() {
      _settings = _settingsService.current;
      _workingSettings = _settings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings(GenerationSettings newSettings) async {
    await _settingsService.save(newSettings);
    setState(() {
      _settings = newSettings;
      _workingSettings = newSettings;
    });
  }

  Future<void> _resetToDefaults() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: widget.isDark ? Colors.black : Colors.white,
        title: const Text(
          'RESET TO DEFAULTS?',
          style: TextStyle(
            fontFamily: 'Courier',
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Restore all generation settings to balanced defaults?',
          style: TextStyle(fontFamily: 'Courier', fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'Courier',
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _settingsService.resetToDefaults().then((_) {
                _loadSettings();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to defaults'),
                    duration: Duration(seconds: 2),
                  ),
                );
              });
            },
            child: const Text(
              'RESET',
              style: TextStyle(
                fontFamily: 'Courier',
                color: nothingRed,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? Colors.black : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black;
    final borderColor = widget.isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor = widget.isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(
            color: widget.isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

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
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(2),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back, color: textColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GENERATION',
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
                    // Presets
                    _SectionHeader(label: 'PRESETS', subtitleColor: subtitleColor),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: GenerationSettings.presets.entries
                            .map((entry) {
                          final isActive = _workingSettings.temperature ==
                              entry.value.temperature;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _workingSettings = entry.value);
                                _saveSettings(entry.value);
                              },
                              child: Container(
                                width: 110,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isActive ? nothingRed : borderColor,
                                    width: isActive ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                  color: isActive
                                      ? (widget.isDark
                                          ? const Color(0xFF1C1A1A)
                                          : const Color(0xFFFFF7F7))
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      entry.key.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? nothingRed : textColor,
                                        letterSpacing: 1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Temp: ${entry.value.temperature.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        fontSize: 9,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Manual Tuning
                    _SectionHeader(label: 'MANUAL TUNING', subtitleColor: subtitleColor),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SliderSetting(
                              label: 'Temperature',
                              value: _workingSettings.temperature,
                              min: 0.0,
                              max: 2.0,
                              divisions: 40,
                              onChanged: (v) {
                                setState(
                                  () => _workingSettings =
                                      _workingSettings.copyWith(temperature: v),
                                );
                              },
                              onSave: () => _saveSettings(_workingSettings),
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              isDark: widget.isDark,
                              hint: '0.0 = deterministic, 1.0 = normal, 2.0+ = very creative',
                            ),
                            const SizedBox(height: 20),
                            _SliderSetting(
                              label: 'Top-P (Nucleus Sampling)',
                              value: _workingSettings.topP,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              onChanged: (v) {
                                setState(
                                  () => _workingSettings =
                                      _workingSettings.copyWith(topP: v),
                                );
                              },
                              onSave: () => _saveSettings(_workingSettings),
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              isDark: widget.isDark,
                              hint: 'Cumulative probability. Lower = more focused.',
                            ),
                            const SizedBox(height: 20),
                            _SliderSetting(
                              label: 'Top-K',
                              value: _workingSettings.topK.toDouble(),
                              min: 1.0,
                              max: 100.0,
                              divisions: 99,
                              onChanged: (v) {
                                setState(
                                  () => _workingSettings = _workingSettings
                                      .copyWith(topK: v.toInt()),
                                );
                              },
                              onSave: () => _saveSettings(_workingSettings),
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              isDark: widget.isDark,
                              hint: 'Keep top-K tokens. Lower = more focused.',
                            ),
                            const SizedBox(height: 20),
                            _SliderSetting(
                              label: 'Min-P',
                              value: _workingSettings.minP,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              onChanged: (v) {
                                setState(
                                  () => _workingSettings =
                                      _workingSettings.copyWith(minP: v),
                                );
                              },
                              onSave: () => _saveSettings(_workingSettings),
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              isDark: widget.isDark,
                              hint: 'Minimum probability threshold.',
                            ),
                            const SizedBox(height: 20),
                            _SliderSetting(
                              label: 'Repetition Penalty',
                              value: _workingSettings.repeatPenalty,
                              min: 1.0,
                              max: 2.0,
                              divisions: 20,
                              onChanged: (v) {
                                setState(
                                  () => _workingSettings = _workingSettings
                                      .copyWith(repeatPenalty: v),
                                );
                              },
                              onSave: () => _saveSettings(_workingSettings),
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              isDark: widget.isDark,
                              hint: '1.0 = no penalty, 1.2+ = strong penalty.',
                            ),
                            const SizedBox(height: 20),
                            _SliderSetting(
                              label: 'Max Tokens',
                              value: _workingSettings.maxTokens.toDouble(),
                              min: 50.0,
                              max: 500.0,
                              divisions: 45,
                              onChanged: (v) {
                                setState(
                                  () => _workingSettings = _workingSettings
                                      .copyWith(maxTokens: v.toInt()),
                                );
                              },
                              onSave: () => _saveSettings(_workingSettings),
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              isDark: widget.isDark,
                              hint: 'Maximum response length in tokens.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _resetToDefaults,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nothingRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        child: const Text(
                          'RESET ALL TO DEFAULTS',
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
  final Color subtitleColor;

  const _SectionHeader({
    required this.label,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: nothingRed,
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

class _SliderSetting extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final VoidCallback onSave;
  final Color textColor;
  final Color subtitleColor;
  final bool isDark;
  final String hint;

  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onSave,
    required this.textColor,
    required this.subtitleColor,
    required this.isDark,
    required this.hint,
  });

  @override
  State<_SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<_SliderSetting> {
  late double _tempValue;

  @override
  void initState() {
    super.initState();
    _tempValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SliderSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _tempValue != widget.value) {
      _tempValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.textColor,
                letterSpacing: 1,
              ),
            ),
            Text(
              _tempValue.toStringAsFixed(2),
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: nothingRed,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _tempValue,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          activeColor: nothingRed,
          inactiveColor: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          onChanged: (v) {
            setState(() => _tempValue = v);
            widget.onChanged(v);
          },
          onChangeEnd: (_) => widget.onSave(),
        ),
        const SizedBox(height: 6),
        Text(
          widget.hint,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 10,
            color: widget.subtitleColor,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
