import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';

class WindowService {
  static final WindowService instance = WindowService._();
  WindowService._();

  String? _subWindowId;

  String? get subWindowId => _subWindowId;

  Future<void> openLyricsWindow() async {
    if (_subWindowId != null) {
      try {
        final controller = WindowController.fromWindowId(_subWindowId!);
        await controller.show();
        return;
      } catch (e) {
        _subWindowId = null;
      }
    }

    try {
      // Spawn secondary window with configuration
      final controller = await WindowController.create(
        WindowConfiguration(
          arguments: jsonEncode({
            'type': 'lyrics_overlay',
          }),
        ),
      );
      _subWindowId = controller.windowId;
      await controller.show();
    } catch (e) {
      debugPrint("Error opening multi window: $e");
    }
  }

  Future<void> closeLyricsWindow() async {
    if (_subWindowId == null) return;
    try {
      final controller = WindowController.fromWindowId(_subWindowId!);
      await controller.hide();
      _subWindowId = null;
    } catch (e) {
      debugPrint("Error closing multi window: $e");
      _subWindowId = null;
    }
  }
}
