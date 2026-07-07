import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'x_models/track_model.dart';
import 'x_services/lyrics_service.dart';
import 'x_services/music_service.dart';
import 'x_services/window_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route to secondary window if started with 'multi_window' argument
  if (args.firstOrNull == 'multi_window') {
    final windowId = args[1];
    final Map<String, dynamic> arguments = args[2].isNotEmpty ? json.decode(args[2]) : {};
    runApp(SecondaryWindowApp(windowId: windowId, arguments: arguments));
    return;
  }

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(850, 620),
    minimumSize: Size(700, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: "Apple Music Widget+",
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MainApp());
}

// -----------------------------------------------------------------------------
// MAIN DASHBOARD APPLICATION
// -----------------------------------------------------------------------------
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Music Widget+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D11),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFC3C44), // Apple Music pink/red
          secondary: Color(0xFF303036),
          surface: Color(0xFF1E1E22),
        ),
        useMaterial3: true,
      ),
      home: const DashboardShell(),
    );
  }
}

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _activeNavIndex = 0;
  bool _isLyricsWindowOpen = false;

  @override
  void initState() {
    super.initState();
    // Trigger initial update on load
    MusicService.instance.triggerUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassmorphicBackground(
        child: Row(
          children: [
            // Sidebar Menu (Frosted glass look)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Logo
                      Row(
                        children: [
                          const Icon(CupertinoIcons.music_note_2, color: Color(0xFFFC3C44), size: 24),
                          const SizedBox(width: 10),
                          const Text(
                            'MusicWidget+',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: double.infinity, height: 44),
                      
                      // Sidebar items (Apple-style)
                      _buildSidebarButton(0, CupertinoIcons.music_house_fill, 'Player Controller'),
                      _buildSidebarButton(1, CupertinoIcons.slider_horizontal_3, 'Widget Configurator'),
                      _buildSidebarButton(2, CupertinoIcons.graph_square, 'Listening Insights'),
                      _buildSidebarButton(3, CupertinoIcons.settings, 'Settings'),
                      const Spacer(),

                      // Multi-window floating lyrics toggle
                      InkWell(
                        onTap: () async {
                          if (_isLyricsWindowOpen) {
                            await WindowService.instance.closeLyricsWindow();
                            setState(() => _isLyricsWindowOpen = false);
                          } else {
                            await WindowService.instance.openLyricsWindow();
                            setState(() => _isLyricsWindowOpen = true);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: _isLyricsWindowOpen 
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFC3C44),
                                      Color(0xFFE22D35),
                                    ],
                                  )
                                : null,
                            color: _isLyricsWindowOpen ? null : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isLyricsWindowOpen 
                                  ? const Color(0xFFFC3C44).withValues(alpha: 0.5) 
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                            boxShadow: _isLyricsWindowOpen 
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFC3C44).withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.macwindow,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isLyricsWindowOpen ? 'Close Lyrics Window' : 'Floating Lyrics Window',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Main Body
            Expanded(
              child: _activeNavIndex == 0
                  ? const PlayerDashboard()
                  : PlaceholderView(title: ['Widget Settings', 'Listening Statistics', 'Settings'][_activeNavIndex - 1]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarButton(int index, IconData icon, String title) {
    final bool isActive = _activeNavIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: InkWell(
        onTap: () => setState(() => _activeNavIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isActive 
                ? const Color(0xFFFC3C44).withValues(alpha: 0.15) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive 
                  ? const Color(0xFFFC3C44).withValues(alpha: 0.2) 
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon, 
                color: isActive ? const Color(0xFFFC3C44) : Colors.white.withValues(alpha: 0.55), 
                size: 18
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.7),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GLASSMORPHIC / AMBIENT GLOW SYSTEM
// -----------------------------------------------------------------------------
class GlassmorphicBackground extends StatelessWidget {
  final Widget child;
  const GlassmorphicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ambient Blob 1 (Red/Pink)
        Positioned(
          top: -120,
          right: -100,
          child: Container(
            width: 480,
            height: 480,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFC3C44).withValues(alpha: 0.16),
                  const Color(0xFFFC3C44).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Ambient Blob 2 (Blue/Purple)
        Positioned(
          bottom: -150,
          left: -50,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF5E5CE6).withValues(alpha: 0.12),
                  const Color(0xFF5E5CE6).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Ambient Blob 3 (Pink/Purple)
        Positioned(
          top: 200,
          left: 180,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFBF5AF2).withValues(alpha: 0.05),
                  const Color(0xFFBF5AF2).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Content
        Positioned.fill(child: child),
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.constraints,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: constraints,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 35,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PLAYER DASHBOARD
// -----------------------------------------------------------------------------
class PlayerDashboard extends StatefulWidget {
  const PlayerDashboard({super.key});

  @override
  State<PlayerDashboard> createState() => _PlayerDashboardState();
}

class _PlayerDashboardState extends State<PlayerDashboard> {
  Timer? _progressTimer;
  double _localPlaybackPosition = 0.0;
  DateTime? _lastTickTime;
  TrackModel? _lastTrack;
  Uint8List? _artworkBytes;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    MusicService.instance.currentTrack.addListener(_onTrackChanged);
    _onTrackChanged();
  }

  @override
  void dispose() {
    MusicService.instance.currentTrack.removeListener(_onTrackChanged);
    _stopProgressTimer();
    super.dispose();
  }

  void _onTrackChanged() {
    if (!mounted) return;
    final track = MusicService.instance.currentTrack.value;
    
    final songChanged = _lastTrack == null || 
                        _lastTrack!.name != track.name || 
                        _lastTrack!.artist != track.artist;
    _lastTrack = track;

    if (songChanged) {
      setState(() {
        _artworkBytes = null;
      });
      MusicService.instance.getArtworkPath().then((path) {
        if (path != null) {
          final file = File(path);
          if (file.existsSync()) {
            try {
              final bytes = file.readAsBytesSync();
              if (bytes.isNotEmpty && mounted) {
                setState(() {
                  _artworkBytes = bytes;
                });
              }
            } catch (_) {}
          }
        }
      });
    }

    setState(() {
      _localPlaybackPosition = track.position;
      _lastTickTime = DateTime.now();
      _stopProgressTimer();
      if (track.isPlaying) {
        _startProgressTimer();
      }
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_lastTickTime == null) {
        _lastTickTime = now;
        return;
      }
      final delta = now.difference(_lastTickTime!).inMilliseconds / 1000.0;
      _lastTickTime = now;

      if (_isDragging) return;

      final track = MusicService.instance.currentTrack.value;
      setState(() {
        _localPlaybackPosition = (_localPlaybackPosition + delta).clamp(0.0, track.duration);
      });
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  String _formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '0:00';
    final int totalSeconds = seconds.round();
    final int minutes = totalSeconds ~/ 60;
    final int remainingSeconds = totalSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard header
          const SizedBox(height: 8),
          const Text(
            'Aesthetic Companion Controller',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Asynchronous bridge telemetry connected directly to macOS Music.app',
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.45)
            ),
          ),
          const SizedBox(height: 48),

          // Player Card Enclosure (Liquid Glass)
          Expanded(
            child: Center(
              child: ValueListenableBuilder<TrackModel>(
                valueListenable: MusicService.instance.currentTrack,
                builder: (context, track, _) {
                  return GlassCard(
                    constraints: const BoxConstraints(
                      maxWidth: 580,
                      maxHeight: 280,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        // Artwork Container with Apple Ambient Glow
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFC3C44).withValues(alpha: 0.15),
                                blurRadius: 25,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _artworkBytes != null
                                ? Image.memory(_artworkBytes!, fit: BoxFit.cover)
                                : Container(
                                    color: const Color(0x10FFFFFF),
                                    child: const Icon(
                                      CupertinoIcons.music_note, 
                                      size: 54, 
                                      color: Colors.white30
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 28),

                        // Track Details and Controls
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Title
                              Text(
                                track.name.isNotEmpty ? track.name : 'Not Playing',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              
                              // Artist / Album
                              Text(
                                track.artist.isNotEmpty 
                                    ? '${track.artist} — ${track.album}' 
                                    : 'Select a track in Apple Music',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 24),

                              // Playback Duration Slider (Cupertino slider style)
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(_localPlaybackPosition),
                                    style: TextStyle(
                                      fontSize: 10, 
                                      fontFamily: 'monospace',
                                      color: Colors.white.withValues(alpha: 0.4)
                                    ),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        activeTrackColor: const Color(0xFFFC3C44),
                                        inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                                        thumbColor: Colors.white,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 5,
                                        ),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                      ),
                                      child: Slider(
                                        min: 0.0,
                                        max: track.duration > 0 ? track.duration : 1.0,
                                        value: _localPlaybackPosition <= track.duration ? _localPlaybackPosition : 0.0,
                                        onChanged: (val) {
                                          setState(() {
                                            _isDragging = true;
                                            _localPlaybackPosition = val;
                                          });
                                        },
                                        onChangeEnd: (val) {
                                          setState(() {
                                            _isDragging = false;
                                          });
                                          MusicService.instance.seek(val);
                                        },
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(track.duration),
                                    style: TextStyle(
                                      fontSize: 10, 
                                      fontFamily: 'monospace',
                                      color: Colors.white.withValues(alpha: 0.4)
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Control Buttons (Cupertino Symbols)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      CupertinoIcons.backward_fill, 
                                      size: 20, 
                                      color: Colors.white.withValues(alpha: 0.8)
                                    ),
                                    onPressed: () => MusicService.instance.previous(),
                                  ),
                                  const SizedBox(width: 14),
                                  
                                  // Play/Pause button
                                  InkWell(
                                    onTap: () => MusicService.instance.playPause(),
                                    borderRadius: BorderRadius.circular(100),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFFC3C44),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFC3C44).withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        track.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 14),
                                  IconButton(
                                    icon: Icon(
                                      CupertinoIcons.forward_fill, 
                                      size: 20, 
                                      color: Colors.white.withValues(alpha: 0.8)
                                    ),
                                    onPressed: () => MusicService.instance.next(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Volume Control
                              Row(
                                children: [
                                  Icon(CupertinoIcons.volume_down, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        activeTrackColor: Colors.white.withValues(alpha: 0.6),
                                        inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3.5),
                                        thumbColor: Colors.white70,
                                      ),
                                      child: Slider(
                                        min: 0.0,
                                        max: 100.0,
                                        value: track.volume.toDouble(),
                                        onChanged: (val) {
                                          MusicService.instance.setVolume(val.toInt());
                                        },
                                      ),
                                    ),
                                  ),
                                  Icon(CupertinoIcons.volume_up, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceholderView extends StatelessWidget {
  final String title;
  const PlaceholderView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.lock_fill, size: 44, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Target view for future phases of application roadmap.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FLOATING LYRICS SECONDARY WINDOW APPLICATION
// -----------------------------------------------------------------------------
class SecondaryWindowApp extends StatefulWidget {
  final String windowId;
  final Map<String, dynamic> arguments;

  const SecondaryWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<SecondaryWindowApp> createState() => _SecondaryWindowAppState();
}

class SyncedLine {
  final Duration time;
  final String text;
  SyncedLine({required this.time, required this.text});
}

class _SecondaryWindowAppState extends State<SecondaryWindowApp> {
  String _plainLyrics = '';
  String _syncedLyricsText = '';
  List<SyncedLine> _syncedLines = [];
  bool _isLoading = false;
  String _lyricsSource = '';
  TrackModel? _lastTrack;

  // Real-time local ticking playback progress for synced lyrics
  Timer? _progressTimer;
  double _localPlaybackPosition = 0.0;
  DateTime? _lastTickTime;

  // Scrolling support
  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSubWindow();
    });

    // Subscribe to track notifications
    MusicService.instance.currentTrack.addListener(_onTrackChanged);
    _onTrackChanged();
  }

  @override
  void dispose() {
    MusicService.instance.currentTrack.removeListener(_onTrackChanged);
    _stopProgressTimer();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initSubWindow() async {
    try {
      await windowManager.ensureInitialized();
      await windowManager.setSize(const Size(450, 550));
      await windowManager.setMinimumSize(const Size(350, 400));
      await windowManager.setTitle("Floating Lyrics Overlay");
      await windowManager.center();
      await windowManager.show();
    } catch (e) {
      debugPrint("Error initializing secondary window: $e");
    }
  }

  void _onTrackChanged() {
    final track = MusicService.instance.currentTrack.value;
    
    // Check if the song has actually changed
    final songChanged = _lastTrack == null || 
                        _lastTrack!.name != track.name || 
                        _lastTrack!.artist != track.artist;
                        
    _lastTrack = track;

    // Align playback state ticking
    _localPlaybackPosition = track.position;
    _lastTickTime = DateTime.now();
    _stopProgressTimer();
    if (track.isPlaying) {
      _startProgressTimer();
    }

    if (!songChanged) {
      // Just progress update, no need to refetch lyrics
      return;
    }

    if (track.name.isEmpty || track.artist.isEmpty) {
      setState(() {
        _plainLyrics = '';
        _syncedLyricsText = '';
        _syncedLines = [];
        _lyricsSource = '';
        _isLoading = false;
      });
      return;
    }

    // Refetch lyrics for the new song
    setState(() {
      _isLoading = true;
      _plainLyrics = '';
      _syncedLyricsText = '';
      _syncedLines = [];
      _lyricsSource = '';
      _lastActiveIndex = -1;
    });

    LyricsService.instance.fetchLyrics(
      track: track.name,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
    ).then((res) {
      if (!mounted) return;
      
      // Ensure the user hasn't changed tracks while we were fetching
      final current = MusicService.instance.currentTrack.value;
      if (current.name != track.name || current.artist != track.artist) {
        return;
      }

      setState(() {
        _isLoading = false;
        if (res != null) {
          _plainLyrics = res['plainLyrics'] ?? '';
          _syncedLyricsText = res['syncedLyrics'] ?? '';
          _syncedLines = _parseLrc(_syncedLyricsText);
          _lyricsSource = res['source'] ?? '';
        } else {
          _plainLyrics = '';
          _syncedLyricsText = '';
          _syncedLines = [];
          _lyricsSource = 'None';
        }
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _plainLyrics = '';
        _syncedLyricsText = '';
        _syncedLines = [];
        _lyricsSource = 'Error';
      });
    });
  }

  void _startProgressTimer() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_lastTickTime == null) {
        _lastTickTime = now;
        return;
      }
      final delta = now.difference(_lastTickTime!).inMilliseconds / 1000.0;
      _lastTickTime = now;

      final track = MusicService.instance.currentTrack.value;
      setState(() {
        _localPlaybackPosition = (_localPlaybackPosition + delta).clamp(0.0, track.duration);
      });
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  List<SyncedLine> _parseLrc(String lrcText) {
    if (lrcText.isEmpty) return [];
    final List<SyncedLine> list = [];
    final lines = lrcText.split('\n');
    final timeRegExp = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\]');
    
    for (final line in lines) {
      final matches = timeRegExp.allMatches(line);
      if (matches.isEmpty) continue;
      
      final lastMatch = matches.last;
      final text = line.substring(lastMatch.end).trim();
      
      for (final match in matches) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final msStr = match.group(3) ?? '0';
        int ms = int.parse(msStr);
        
        if (msStr.length == 2) {
          ms *= 10;
        } else if (msStr.length == 1) {
          ms *= 100;
        }
        
        final time = Duration(minutes: min, seconds: sec, milliseconds: ms);
        list.add(SyncedLine(time: time, text: text));
      }
    }
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  int _getActiveLyricsIndex() {
    if (_syncedLines.isEmpty) return -1;
    int activeIndex = -1;
    for (int i = 0; i < _syncedLines.length; i++) {
      if (_localPlaybackPosition >= _syncedLines[i].time.inMilliseconds / 1000.0) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }

  void _scrollToActiveLine(int index) {
    if (!_scrollController.hasClients || index < 0) return;
    
    // Estimate target offset (approx 48px per line)
    // Center the active line (using half of typical lyrics screen viewport height)
    const double estimatedLineHeight = 48.0;
    const double viewportCenterHeight = 180.0;
    final double targetOffset = (index * estimatedLineHeight) - viewportCenterHeight;
    
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _getActiveLyricsIndex();
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(activeIndex);
      });
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'SF Pro Display', // standard premium macOS font family name
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF0F0F11),
        body: ValueListenableBuilder<TrackModel>(
          valueListenable: MusicService.instance.currentTrack,
          builder: (context, track, _) {
            final trackPlaying = track.name.isNotEmpty;

            return GlassCard(
              borderRadius: 0, // Fill the window completely for secondary window overlays
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Windows Title Bar Metadata Area
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(CupertinoIcons.music_mic, color: Color(0xFFFC3C44), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            trackPlaying ? 'Now Resolving' : 'Standby',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (_lyricsSource.isNotEmpty && _lyricsSource != 'None')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFC3C44).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFC3C44).withValues(alpha: 0.25), width: 0.5),
                          ),
                          child: Text(
                            'Source: $_lyricsSource',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFC3C44),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Track Info Header
                  if (trackPlaying) ...[
                    Text(
                      track.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 16),
                  ],

                  // Lyrics Viewport Container
                  Expanded(
                    child: _buildLyricsContent(track),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLyricsContent(TrackModel track) {
    if (track.name.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.music_note, color: Colors.white24, size: 48),
            SizedBox(height: 16),
            Text(
              'No Track Playing',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            SizedBox(height: 6),
            Text(
              'Play a song in Apple Music to view lyrics',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 12, color: Color(0xFFFC3C44)),
            SizedBox(height: 16),
            Text(
              'Fetching lyrics...',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
      );
    }

    // Check if lyrics exist
    if (_syncedLines.isEmpty && _plainLyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.music_note_2, color: Colors.white24, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Lyrics Unavailable',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white54),
            ),
            const SizedBox(height: 6),
            Text(
              'Could not find lyrics for this song',
              style: TextStyle(fontSize: 12, color: Colors.white38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Case 1: Synced Lyrics available
    if (_syncedLines.isNotEmpty) {
      final activeIndex = _getActiveLyricsIndex();
      return ListView.builder(
        controller: _scrollController,
        itemCount: _syncedLines.length,
        padding: const EdgeInsets.symmetric(vertical: 40),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final line = _syncedLines[index];
          final isActive = index == activeIndex;

          return InkWell(
            onTap: () {
              // Seek to the selected line's time directly
              MusicService.instance.seek(line.time.inMilliseconds / 1000.0);
            },
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.white.withValues(alpha: 0.03),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                vertical: 12, 
                horizontal: isActive ? 12 : 8
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: isActive ? 18 : 15,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive 
                      ? Colors.white 
                      : Colors.white.withValues(alpha: 0.35),
                  height: 1.4,
                ),
                child: Text(
                  line.text,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          );
        },
      );
    }

    // Case 2: Plain Text Lyrics only
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: SelectionArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _plainLyrics,
              style: const TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
