import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'x_models/track_model.dart';
import 'x_services/music_service.dart';
import 'x_services/window_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route to secondary window if started with 'multi_window' argument
  if (args.firstOrNull == 'multi_window') {
    final windowId = int.parse(args[1]);
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
class PlayerDashboard extends StatelessWidget {
  const PlayerDashboard({super.key});

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
                            child: FutureBuilder<String?>(
                              future: MusicService.instance.getArtworkPath(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  final file = File(snapshot.data!);
                                  if (file.existsSync()) {
                                    try {
                                      final bytes = file.readAsBytesSync();
                                      if (bytes.isNotEmpty) {
                                        return Image.memory(bytes, fit: BoxFit.cover);
                                      }
                                    } catch (_) {}
                                  }
                                }
                                return Container(
                                  color: const Color(0x10FFFFFF),
                                  child: const Icon(
                                    CupertinoIcons.music_note, 
                                    size: 54, 
                                    color: Colors.white30
                                  ),
                                );
                              },
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
                                    _formatDuration(track.position),
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
                                        value: track.position <= track.duration ? track.position : 0.0,
                                        onChanged: (val) {},
                                        onChangeEnd: (val) {
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
  final int windowId;
  final Map<String, dynamic> arguments;

  const SecondaryWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<SecondaryWindowApp> createState() => _SecondaryWindowAppState();
}

class _SecondaryWindowAppState extends State<SecondaryWindowApp> {
  @override
  void initState() {
    super.initState();
    _initSubWindow();
  }

  Future<void> _initSubWindow() async {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(450, 300));
    await windowManager.setTitle("Floating Lyrics Overlay");
    await windowManager.center();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent, // Fully transparent back for frosted effect
        body: GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.chat_bubble_2, color: Color(0xFFFC3C44), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Multi-Window Engine Active',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              ValueListenableBuilder<TrackModel>(
                valueListenable: MusicService.instance.currentTrack,
                builder: (context, track, _) {
                  return Column(
                    children: [
                      Text(
                        track.name.isNotEmpty ? track.name : 'No Song Playing',
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.artist.isNotEmpty ? track.artist : 'Select a track in Apple Music',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Window ID: ${widget.windowId}',
                style: const TextStyle(fontSize: 10, color: Colors.white30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
