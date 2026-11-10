import 'dart:async';
import 'package:flutter/material.dart' hide Ink;
import 'package:flutter/services.dart';

import '../services/youtube_music_service.dart';
import '../services/zine_export_service.dart';
import '../sketch.dart';
import '../state.dart';
import 'zine_sheet.dart';

Future<void> showZineExportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (c) => const _ZineExportDialog(),
  );
}

class _ZineExportDialog extends StatefulWidget {
  const _ZineExportDialog();

  @override
  State<_ZineExportDialog> createState() => _ZineExportDialogState();
}

class _ZineExportDialogState extends State<_ZineExportDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  ZineFormat _selectedFormat = ZineFormat.story9x16;
  bool _isExporting = false;
  ZineExportResult? _exportResult;
  String? _statusMessage = 'preview ready · tap save to export';

  @override
  void initState() {
    super.initState();
    // Warm up iTunes metadata & album covers for all scenes
    for (final s in app.allScenes) {
      musicService.ensureITunesMetadata(s.song);
    }
  }

  void _onFormatChanged(ZineFormat newFormat) {
    if (_selectedFormat == newFormat) return;
    setState(() {
      _selectedFormat = newFormat;
      _exportResult = null;
      _statusMessage = 'previewing ${newFormat.label} · tap save to export';
    });
  }

  Future<void> _saveZine() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _statusMessage = 'rendering 300 DPI high-quality image...';
    });

    try {
      // Pause to ensure layout and image decodes are fully finished
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final targetW = (_selectedFormat.width * _selectedFormat.pixelRatio).round();
      final targetH = (_selectedFormat.height * _selectedFormat.pixelRatio).round();

      final pngBytes = await ZineExportService.captureBoundary(
        _boundaryKey,
        pixelRatio: _selectedFormat.pixelRatio,
      );

      if (pngBytes == null || pngBytes.isEmpty) {
        if (mounted) {
          setState(() {
            _isExporting = false;
            _statusMessage = 'could not capture preview – try again';
          });
        }
        return;
      }

      setState(() {
        _statusMessage = 'saving high-quality PNG to storage...';
      });

      final result = await ZineExportService.saveZinePng(
        pngBytes,
        tag: _selectedFormat.fileTag,
        width: targetW,
        height: targetH,
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportResult = result;
          if (result.success) {
            final kb = (result.byteLength ?? 0) ~/ 1024;
            _statusMessage = 'saved high-res PNG ($kb KB · $targetW×$targetH px) ✓';
          } else {
            _statusMessage = 'export failed: ${result.error ?? 'unknown error'}';
          }
        });
        if (result.success) {
          showNote(context, 'zine saved to storage ✓');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _statusMessage = 'error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenes = app.allScenes;
    final mq = MediaQuery.of(context);
    final dialogWidth = (mq.size.width * 0.95).clamp(320.0, 760.0);
    final dialogHeight = (mq.size.height * 0.90).clamp(480.0, 840.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Ink.paper,
          border: Border.all(color: Ink.ink, width: 2.2),
          boxShadow: const [
            BoxShadow(
              color: Ink.ink,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header Row
            Row(
              children: [
                const Icon(Icons.auto_stories_outlined, size: 20, color: Ink.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FILM ZINE EXPORT', style: T.head(18)),
                      Note(
                        'shareable across social platforms · ${scenes.length} scenes',
                        size: 13,
                      ),
                    ],
                  ),
                ),
                SketchTap(
                  onTap: () => Navigator.pop(context),
                  pressedScale: 0.85,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Ink.ink, width: 1.4),
                    ),
                    child: const Icon(Icons.close, size: 18, color: Ink.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const DashedLine(),
            const SizedBox(height: 8),

            // ── Format Selector Chips
            Row(
              children: [
                const Note('Format: ', size: 13),
                const SizedBox(width: 4),
                for (final fmt in ZineFormat.values) ...[
                  SketchChip(
                    label: fmt.label,
                    selected: _selectedFormat == fmt,
                    seed: fmt.index * 13 + 7,
                    onTap: () => _onFormatChanged(fmt),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'best for: ${_selectedFormat.subtitle}',
              style: T.body(11, c: Ink.soft),
            ),
            const SizedBox(height: 8),

            // ── Status banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: Ink.ink, width: 1.2),
                color: Ink.bg,
              ),
              child: Row(
                children: [
                  if (_isExporting) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Ink.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else if (_exportResult?.success == true) ...[
                    const Icon(Icons.check_circle_outline, size: 16, color: Ink.ink),
                    const SizedBox(width: 6),
                  ] else ...[
                    const Icon(Icons.info_outline, size: 16, color: Ink.soft),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      _statusMessage ?? '',
                      style: T.head(12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            if (_exportResult?.success == true && _exportResult?.filePath != null) ...[
              const SizedBox(height: 6),
              // File path info with copy button
              SketchTap(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _exportResult!.filePath!));
                  showNote(context, 'file path copied to clipboard ✓');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Ink.grey, width: 1.0),
                    color: Ink.paper,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open, size: 14, color: Ink.soft),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _exportResult!.filePath!,
                          style: T.body(11, c: Ink.soft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy, size: 12, color: Ink.soft),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ── Interactive Zoomable Preview Area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Ink.ink, width: 1.4),
                  color: Ink.grey.withValues(alpha: 0.25),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InteractiveViewer(
                      key: ValueKey(_selectedFormat),
                      minScale: 0.15,
                      maxScale: 3.5,
                      boundaryMargin: const EdgeInsets.all(40),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: RepaintBoundary(
                            key: _boundaryKey,
                            child: ZineSheet(
                              format: _selectedFormat,
                              scenes: scenes,
                              directorName: app.name,
                              handle: app.handle,
                              inviteCode: app.inviteCode,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Ink.paper,
                          border: Border.all(color: Ink.ink, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.zoom_in, size: 13, color: Ink.ink),
                            const SizedBox(width: 4),
                            Text('pinch to inspect details', style: T.note(11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Actions Row
            Row(
              children: [
                Expanded(
                  child: SketchTextButton(
                    'close',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SketchTextButton(
                    _isExporting ? 'saving...' : 'save ${_selectedFormat.label} png',
                    primary: true,
                    onTap: _isExporting ? () {} : () => unawaited(_saveZine()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
