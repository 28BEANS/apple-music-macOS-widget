import 'dart:convert';
import 'dart:ui';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

class WindowService {
  static final WindowService instance = WindowService._();
  WindowService._();

  int? _subWindowId;

  int? get subWindowId => _subWindowId;

  Future<void> openLyricsWindow() async {
    if (_subWindowId != null) {
      try {
        final controller = WindowController.fromWindowId(_subWindowId!);
        await controller.show();
        await controller.focus();
        return;
      } catch (e) {
        _subWindowId = null;
      }
    }

    try {
      // Spawn secondary window with argument parameter
      final window = await DesktopMultiWindow.createWindow(
        jsonEncode({
          'type': 'lyrics_overlay',
        }),
      );
      _subWindowId = window.windowId;
      await window.setFrame(const Rect.fromLTWH(200, 200, 450, 400));
      await window.setTitle("Floating Lyrics Overlay");
      await window.show();
    } catch (e) {
      debugPrint("Error opening multi window: $e");
    }
  }

  Future<void> closeLyricsWindow() async {
    if (_subWindowId == null) return;
    try {
      final controller = WindowController.fromWindowId(_subWindowId!);
      await controller.close();
      _subWindowId = null;
    } catch (e) {
      debugPrint("Error closing multi window: $e");
      _subWindowId = null;
    }
  }
}
