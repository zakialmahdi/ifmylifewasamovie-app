import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class ZineExportResult {
  final bool success;
  final String? filePath;
  final int? byteLength;
  final int? width;
  final int? height;
  final String? error;

  const ZineExportResult({
    required this.success,
    this.filePath,
    this.byteLength,
    this.width,
    this.height,
    this.error,
  });
}

class ZineExportService {
  /// Captures the widget subtree under [key] as high-resolution PNG bytes.
  /// [pixelRatio] scales up the logical resolution (default 3.0 gives ~3120x2220 print-ready resolution).
  static Future<Uint8List?> captureBoundary(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing zine boundary: $e');
      return null;
    }
  }

  /// Saves the captured PNG bytes to device storage.
  /// Prioritizes user-accessible public folders (Pictures / Download) on mobile/desktop,
  /// falling back safely to app documents directory.
  static Future<ZineExportResult> saveZinePng(
    Uint8List pngBytes, {
    String tag = 'zine',
    int? width,
    int? height,
  }) async {
    if (kIsWeb) {
      return ZineExportResult(
        success: true,
        filePath: 'if_my_life_was_a_movie_$tag.png (web download)',
        byteLength: pngBytes.length,
        width: width,
        height: height,
      );
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'if_my_life_was_a_movie_${tag}_$timestamp.png';

      final candidateDirs = <Directory>[];

      // 1. Android public directories (Pictures / Download)
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final rootPath = ext.path.split('/Android').first;
          final picturesDir = Directory('$rootPath/Pictures/IfMyLifeWasAMovie');
          try {
            if (!await picturesDir.exists()) {
              await picturesDir.create(recursive: true);
            }
            candidateDirs.add(picturesDir);
          } catch (_) {}

          final downloadDir = Directory('$rootPath/Download');
          if (await downloadDir.exists()) {
            candidateDirs.add(downloadDir);
          }
          candidateDirs.add(ext);
        }
      } catch (_) {}

      // 2. Standard Downloads directory
      try {
        final dl = await getDownloadsDirectory();
        if (dl != null) candidateDirs.add(dl);
      } catch (_) {}

      // 3. Application Documents directory
      try {
        final docs = await getApplicationDocumentsDirectory();
        candidateDirs.add(docs);
      } catch (_) {}

      // Attempt writing to candidate directories in priority order
      for (final dir in candidateDirs) {
        try {
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(pngBytes, flush: true);
          return ZineExportResult(
            success: true,
            filePath: file.path,
            byteLength: pngBytes.length,
            width: width,
            height: height,
          );
        } catch (_) {}
      }

      // Final fallback
      final docs = await getApplicationDocumentsDirectory();
      final file = File('${docs.path}/$fileName');
      await file.writeAsBytes(pngBytes, flush: true);
      return ZineExportResult(
        success: true,
        filePath: file.path,
        byteLength: pngBytes.length,
        width: width,
        height: height,
      );
    } catch (e) {
      return ZineExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}
