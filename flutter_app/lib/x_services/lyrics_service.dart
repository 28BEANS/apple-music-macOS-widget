import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LyricsService {
  static final LyricsService instance = LyricsService._();
  LyricsService._();

  // Point to the local backend lyrics proxy
  static const String _backendUrl = 'http://127.0.0.1:8000';

  /// Fetches lyrics for the given song parameters.
  /// Returns a map with `plainLyrics`, `syncedLyrics`, and `source` if successful, or null on error.
  Future<Map<String, dynamic>?> fetchLyrics({
    required String track,
    required String artist,
    String? album,
    double? duration,
  }) async {
    if (track.isEmpty || artist.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse('$_backendUrl/api/lyrics').replace(
        queryParameters: {
          'track': track,
          'artist': artist,
          if (album != null && album.isNotEmpty) 'album': album,
          if (duration != null && duration > 0) 'duration': duration.toString(),
        },
      );

      debugPrint('Fetching lyrics from: $uri');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'plainLyrics': data['plainLyrics'] as String? ?? '',
            'syncedLyrics': data['syncedLyrics'] as String? ?? '',
            'source': data['source'] as String? ?? 'Unknown',
          };
        }
      } else if (response.statusCode == 404) {
        debugPrint('Lyrics not found for track: $artist - $track');
        return {
          'plainLyrics': '',
          'syncedLyrics': '',
          'source': 'None',
        };
      } else {
        debugPrint('Error status code from lyrics server: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Exception while fetching lyrics: $e');
    }
    return null;
  }
}
