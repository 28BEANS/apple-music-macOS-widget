import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../x_models/track_model.dart';

class MusicService {
  static final MusicService instance = MusicService._();
  
  MusicService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
    triggerUpdate();
  }

  final MethodChannel _channel = const MethodChannel('com.example.music_widget/bridge');
  
  final ValueNotifier<TrackModel> currentTrack = ValueNotifier<TrackModel>(TrackModel.empty());

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'trackChanged':
        final String jsonStr = call.arguments as String? ?? '{}';
        currentTrack.value = TrackModel.fromJsonString(jsonStr);
        break;
      default:
        break;
    }
  }

  Future<void> playPause() async {
    try {
      await _channel.invokeMethod('playPause');
    } on PlatformException catch (e) {
      debugPrint("Error playPause: $e");
    }
  }

  Future<void> next() async {
    try {
      await _channel.invokeMethod('nextTrack');
    } on PlatformException catch (e) {
      debugPrint("Error next: $e");
    }
  }

  Future<void> previous() async {
    try {
      await _channel.invokeMethod('previousTrack');
    } on PlatformException catch (e) {
      debugPrint("Error previous: $e");
    }
  }

  Future<void> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      debugPrint("Error setVolume: $e");
    }
  }

  Future<void> seek(double position) async {
    try {
      await _channel.invokeMethod('seek', {'position': position});
    } on PlatformException catch (e) {
      debugPrint("Error seek: $e");
    }
  }

  Future<void> triggerUpdate() async {
    try {
      await _channel.invokeMethod('triggerUpdate');
    } on PlatformException catch (e) {
      debugPrint("Error triggerUpdate: $e");
    }
  }

  Future<String?> getArtworkPath() async {
    try {
      return await _channel.invokeMethod<String>('getArtworkPath');
    } on PlatformException catch (e) {
      debugPrint("Error getArtworkPath: $e");
      return null;
    }
  }
}
