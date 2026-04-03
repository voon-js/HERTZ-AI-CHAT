import 'dart:async';

import 'package:flutter/material.dart';

import '../services/model_catalog.dart';
import '../services/model_manager.dart';
import '../theme/app_theme.dart';

class ModelSelectorOverlay extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String currentModel;
  final ValueChanged<String> onSelectModel;

  const ModelSelectorOverlay({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.currentModel,
    required this.onSelectModel,
  });

  @override
  State<ModelSelectorOverlay> createState() => _ModelSelectorOverlayState();
}

class _ModelSelectorOverlayState extends State<ModelSelectorOverlay> {
  final ModelManager _modelManager = ModelManager();
  late Future<Map<String, List<ModelCatalogEntry>>> _modelsFuture;
  final Set<String> _downloadingModelIds = {};
  final Map<String, double?> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _modelsFuture = _categorizeModels();
  }

  @override
  void didUpdateWidget(covariant ModelSelectorOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      setState(() {
        _modelsFuture = _categorizeModels();
      });
    }
  }

  Future<Map<String, List<ModelCatalogEntry>>> _categorizeModels() async {
    final downloaded = <ModelCatalogEntry>[];
    final available = <ModelCatalogEntry>[];

    for (final model in ModelCatalog.models) {
      final exists = await _modelManager.modelExists(model.filename);
      if (exists) {
        downloaded.add(model);
      } else {
        available.add(model);
      }
    }

    return {
      'downloaded': downloaded,
      'available': available,
    };
  }

  Future<void> _confirmAndDownloadModel(
    ModelCatalogEntry model,
    bool isDark,
    Color subtitleColor,
    Color bg,
  ) async {
    if (_downloadingModelIds.contains(model.id)) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bg,
        title: const Text(
          'DOWNLOAD MODEL?',
          style: TextStyle(
            fontFamily: 'Courier',
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Do you want to download ${model.name}?',
          style: TextStyle(
            fontFamily: 'Courier',
            color: subtitleColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'NO',
              style: TextStyle(
                fontFamily: 'Courier',
                color: Colors.grey,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(_startModelDownload(model));
            },
            child: const Text(
              'YES',
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

  Future<void> _startModelDownload(ModelCatalogEntry model) async {
    if (_downloadingModelIds.contains(model.id)) return;

    if (!mounted) return;
    setState(() {
      _downloadingModelIds.add(model.id);
      _downloadProgress[model.id] = null;
    });

    try {
      await _modelManager.downloadModel(
        model.filename,
        model.url,
        onProgress: (received, total) {
          if (!mounted) return;
          final hasTotal = total > 0;
          final value = hasTotal ? (received / total).clamp(0.0, 1.0) : null;
          final percent = hasTotal ? ((value! * 100).round()) : null;

          setState(() {
            _downloadProgress[model.id] = value;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _downloadingModelIds.remove(model.id);
        _downloadProgress.remove(model.id);
        _modelsFuture = _categorizeModels();
      });

      widget.onSelectModel(model.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingModelIds.remove(model.id);
        _downloadProgress.remove(model.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download ${model.name}. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? const Color(0xFF27272A) : Colors.black;
    final subtitleColor =
        isDark ? const Color(0xFF71717A) : const Color(0xFF6B7280);
    final handleColor = isDark ? const Color(0xFF3F3F46) : Colors.black;

    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: widget.isOpen ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !widget.isOpen,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                offset: widget.isOpen ? Offset.zero : const Offset(0, 1.05),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: widget.isOpen ? 1.0 : 0.0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 4,
                            margin: const EdgeInsets.only(top: 16, bottom: 16),
                            decoration: BoxDecoration(
                              color: handleColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: borderColor),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'SELECT MODEL',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              child: FutureBuilder<Map<String, List<ModelCatalogEntry>>>(
                                future: _modelsFuture,
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    );
                                  }

                                  final models = snapshot.data!;
                                  final downloadedModels = models['downloaded'] ?? [];
                                  final availableModels = models['available'] ?? [];

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (downloadedModels.isNotEmpty) ...[
                                        _buildSectionHeader(
                                          'DOWNLOADED',
                                          subtitleColor,
                                        ),
                                        const SizedBox(height: 8),
                                        ...downloadedModels.map(
                                          (model) => _buildModelCard(
                                            model,
                                            isDark: isDark,
                                            subtitleColor: subtitleColor,
                                            borderColor: borderColor,
                                            selected: widget.currentModel == model.name,
                                            enabled: true,
                                            isDownloading: false,
                                            progressValue: null,
                                            onTap: () {
                                              widget.onSelectModel(model.name);
                                              widget.onClose();
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      if (availableModels.isNotEmpty) ...[
                                        _buildSectionHeader(
                                          'AVAILABLE',
                                          subtitleColor,
                                        ),
                                        const SizedBox(height: 8),
                                        ...availableModels.map(
                                          (model) => _buildModelCard(
                                            model,
                                            isDark: isDark,
                                            subtitleColor: subtitleColor,
                                            borderColor: borderColor,
                                            selected: false,
                                            enabled: true,
                                            isDownloading:
                                                _downloadingModelIds.contains(model.id),
                                            progressValue: _downloadProgress[model.id],
                                            onTap: () => _confirmAndDownloadModel(
                                              model,
                                              isDark,
                                              subtitleColor,
                                              bg,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (downloadedModels.isEmpty &&
                                          availableModels.isEmpty)
                                        Text(
                                          'No models available.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtitleColor,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Courier',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: subtitleColor,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildModelCard(
    ModelCatalogEntry model, {
    required bool isDark,
    required Color subtitleColor,
    required Color borderColor,
    required bool selected,
    required bool enabled,
    required bool isDownloading,
    required double? progressValue,
    required VoidCallback onTap,
  }) {
    final foregroundColor = isDark ? Colors.white : Colors.black;
    final accentColor = (selected || isDownloading) ? nothingRed : borderColor;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: accentColor),
          borderRadius: BorderRadius.circular(2),
          color: selected
              ? (isDark ? const Color(0xFF1C1A1A) : const Color(0xFFFFF7F7))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: (selected || isDownloading)
                              ? nothingRed
                              : foregroundColor,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                      if (model.badgeLabel != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: nothingRed),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            model.badgeLabel!,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: nothingRed,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isDownloading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(nothingRed),
                    ),
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? nothingRed : Colors.transparent,
                      border: Border.all(color: selected ? nothingRed : accentColor),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(nothingRed),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
