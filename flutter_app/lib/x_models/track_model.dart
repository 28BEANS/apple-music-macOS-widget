import 'dart:convert';

class TrackModel {
  final String status;
  final String playerState; // "playing", "paused", "stopped"
  final String name;
  final String artist;
  final String album;
  final double duration; // in seconds
  final double position; // in seconds
  final String trackId;
  final int volume; // 0-100

  TrackModel({
    required this.status,
    required this.playerState,
    required this.name,
    required this.artist,
    required this.album,
    required this.duration,
    required this.position,
    required this.trackId,
    required this.volume,
  });

  factory TrackModel.empty() {
    return TrackModel(
      status: 'stopped',
      playerState: 'stopped',
      name: '',
      artist: '',
      album: '',
      duration: 0.0,
      position: 0.0,
      trackId: '',
      volume: 50,
    );
  }

  factory TrackModel.fromJsonString(String jsonStr) {
    try {
      final Map<String, dynamic> data = json.decode(jsonStr);
      final status = data['status'] as String? ?? 'stopped';
      if (status == 'success') {
        return TrackModel(
          status: status,
          playerState: data['playerState'] as String? ?? 'stopped',
          name: data['name'] as String? ?? 'Unknown Title',
          artist: data['artist'] as String? ?? 'Unknown Artist',
          album: data['album'] as String? ?? 'Unknown Album',
          duration: (data['duration'] as num?)?.toDouble() ?? 0.0,
          position: (data['position'] as num?)?.toDouble() ?? 0.0,
          trackId: data['trackId'] as String? ?? '',
          volume: (data['volume'] as num?)?.toInt() ?? 50,
        );
      } else {
        return TrackModel(
          status: status,
          playerState: data['playerState'] as String? ?? 'stopped',
          name: '',
          artist: '',
          album: '',
          duration: 0.0,
          position: 0.0,
          trackId: '',
          volume: 50,
        );
      }
    } catch (e) {
      return TrackModel.empty();
    }
  }

  bool get isPlaying => playerState == 'playing';

  @override
  String toString() {
    return 'TrackModel(name: $name, artist: $artist, playerState: $playerState)';
  }
}
