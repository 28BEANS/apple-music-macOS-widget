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
                  : _activeNavIndex == 1
                      ? const WidgetConfiguratorPage()
                      : PlaceholderView(title: ['Listening Statistics', 'Settings'][_activeNavIndex - 2]),
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

// -----------------------------------------------------------------------------
// WIDGET CONFIGURATOR / GALLERY
// -----------------------------------------------------------------------------
class WidgetConfiguratorPage extends StatefulWidget {
  const WidgetConfiguratorPage({super.key});

  @override
  State<WidgetConfiguratorPage> createState() => _WidgetConfiguratorPageState();
}

class _WidgetConfiguratorPageState extends State<WidgetConfiguratorPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _widgetData = [
    {
      'title': 'Apple Music Widget+',
      'description': 'Display and control current Apple Music playback.',
    },
    {
      'title': 'Pins',
      'description': 'Quickly access your pinned items.',
    },
    {
      'title': 'Recently Played',
      'description': 'Find all your recently played music, and see what\'s currently playing.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper to build beautiful gradient artwork thumbnails
  Widget _buildMockArtwork(String text, List<Color> colors, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.18),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text.isNotEmpty ? text[0].toUpperCase() : 'M',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const SizedBox(height: 8),
          const Text(
            'Widget Configurator',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select and add widgets directly to your macOS Notification Center',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 32),

          // Main iOS-style Widget sheet card container
          Expanded(
            child: Center(
              child: Container(
                width: 440,
                height: 420,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top header: "Music", Icon, Close "X"
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFC3C44),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              CupertinoIcons.music_note,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Music',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            CupertinoIcons.xmark,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 16,
                          ),
                        ],
                      ),
                    ),

                    // Titles & Description block (synchronized with PageView)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            _widgetData[_currentPage]['title']!,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 32,
                            child: Text(
                              _widgetData[_currentPage]['description']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Carousel Area
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            children: [
                              _buildMediumWidgetPreview(),
                              _buildPinsWidgetPreview(),
                              _buildRecentlyPlayedWidgetPreview(),
                            ],
                          ),
                          // Arrow Left
                          if (_currentPage > 0)
                            Positioned(
                              left: 12,
                              child: IconButton(
                                icon: const Icon(CupertinoIcons.chevron_left, color: Colors.white60),
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          // Arrow Right
                          if (_currentPage < 2)
                            Positioned(
                              right: 12,
                              child: IconButton(
                                icon: const Icon(CupertinoIcons.chevron_right, color: Colors.white60),
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Dots Indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(10, (index) {
                          // The first 3 dots represent the widgets, the others are extra pagination page indicators to look like iOS Widget Gallery
                          final bool isWidgetDot = index < 3;
                          final bool isActive = index == _currentPage;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? Colors.white
                                  : isWidgetDot
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.1),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Add Widget Button
                    Padding(
                      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: () {
                            // Non-functional mock feedback
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${_widgetData[_currentPage]['title']} Widget to desktop'),
                                backgroundColor: const Color(0xFFFC3C44),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFFC3C44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.add, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Add Widget',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Previews:
  // 1. Medium Widget View Preview
  Widget _buildMediumWidgetPreview() {
    return Center(
      child: Container(
        width: 320,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2C2C2E),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Artwork
            _buildMockArtwork(
              'Isolation',
              [const Color(0xFF3F51B5), const Color(0xFFE91E63)],
              size: 85,
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Isolation',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kali Uchis — Isolation',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 12),
                  // Mock slider
                  Row(
                    children: [
                      Text(
                        '1:24',
                        style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1.5),
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 45,
                              height: 3,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1.5),
                                color: const Color(0xFFFC3C44),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '3:47',
                        style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Mock controls
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.backward_fill, size: 12, color: Colors.white70),
                      SizedBox(width: 16),
                      Icon(CupertinoIcons.pause_fill, size: 14, color: Colors.white),
                      SizedBox(width: 16),
                      Icon(CupertinoIcons.forward_fill, size: 12, color: Colors.white70),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Pins Widget (Large square) Preview
  Widget _buildPinsWidgetPreview() {
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2C2C2E),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Pins',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                Icon(CupertinoIcons.music_note, size: 9, color: Colors.white.withValues(alpha: 0.6)),
              ],
            ),
            const SizedBox(height: 8),
            // Grid 3x2
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 4,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.72,
                children: [
                  _buildPinGridItem('Cherry Bomb', [const Color(0xFFFF7B90), const Color(0xFFFFB07C)]),
                  _buildPinGridItem('DON\'T TAP...', [const Color(0xFFE5E5E5), const Color(0xFF9E9E9E)]),
                  _buildPinGridItem('CHROM...', [const Color(0xFF4A5D4E), const Color(0xFF1E2620)]),
                  _buildPinGridItem('Wolf', [const Color(0xFF7CC6FE), const Color(0xFFCBEBFF)]),
                  _buildPinGridItem('CALL ME...', [const Color(0xFFE6BA80), const Color(0xFF8BA5B5)]),
                  _buildPinGridItem('Goblin', [const Color(0xFF2C4A44), const Color(0xFF131D1B)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinGridItem(String title, List<Color> colors) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: 6, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // 3. Recently Played Widget (Large square) Preview
  Widget _buildRecentlyPlayedWidgetPreview() {
    return Center(
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF2C2C2E),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: hero
            Row(
              children: [
                _buildMockArtwork(
                  'Isolation',
                  [const Color(0xFF3F51B5), const Color(0xFFE91E63)],
                  size: 40,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Isolation',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Kali Uchis',
                        style: TextStyle(fontSize: 6, color: Colors.white.withValues(alpha: 0.5)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Mock play button pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.play_fill, size: 4, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Play',
                              style: TextStyle(fontSize: 5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'RECENTLY PLAYED',
              style: TextStyle(fontSize: 5, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            // 3 rows list
            _buildRecentListRow('This Is How Tomorrow Moves', 'beabadoobee', [const Color(0xFFF48FB1), const Color(0xFFFFD54F)]),
            _buildRecentListRow('?', 'beans', [const Color(0xFFFFD54F), const Color(0xFF000000)]),
            _buildRecentListRow('Do That Again', 'Malcolm Todd', [const Color(0xFFFF5252), const Color(0xFFFF7A00)]),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentListRow(String title, String artist, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  artist,
                  style: TextStyle(fontSize: 5, color: Colors.white.withValues(alpha: 0.5)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: const Center(
              child: Icon(CupertinoIcons.play_fill, size: 5, color: Colors.white60),
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
