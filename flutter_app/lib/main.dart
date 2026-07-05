import 'dart:convert';
import 'dart:io';
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
        scaffoldBackgroundColor: const Color(0xFF121214),
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
      body: Row(
        children: [
          // Sidebar Menu
          Container(
            width: 220,
            color: const Color(0xFF18181C),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Logo
                Row(
                  children: [
                    const Icon(Icons.music_video_rounded, color: Color(0xFFFC3C44), size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'MusicWidget+',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: double.infinity, height: 40),
                
                // Sidebar items
                _buildSidebarButton(0, Icons.dashboard_rounded, 'Player Controller'),
                _buildSidebarButton(1, Icons.tune_rounded, 'Widget Configurator'),
                _buildSidebarButton(2, Icons.analytics_outlined, 'Listening Insights'),
                _buildSidebarButton(3, Icons.settings_rounded, 'Settings'),
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
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _isLyricsWindowOpen 
                          ? const Color(0xFFFC3C44).withValues(alpha: 0.15)
                          : const Color(0xFF26262B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isLyricsWindowOpen ? const Color(0xFFFC3C44) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isLyricsWindowOpen ? Icons.layers_clear_rounded : Icons.picture_in_picture_alt_rounded,
                          color: _isLyricsWindowOpen ? const Color(0xFFFC3C44) : Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLyricsWindowOpen ? 'Close Floating' : 'Lyrics Floating Window',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isLyricsWindowOpen ? const Color(0xFFFC3C44) : Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
    );
  }

  Widget _buildSidebarButton(int index, IconData icon, String title) {
    final bool isActive = _activeNavIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => setState(() => _activeNavIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFC3C44).withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? const Color(0xFFFC3C44) : Colors.white.withValues(alpha: 0.55), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.7),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard header
          Text(
            'Aesthetic Companion Controller',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Asynchronous bridge telemetry connected directly to macOS Music.app',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 32),

          // Player Card Enclosure (Glassmorphism layout)
          Expanded(
            child: Center(
              child: ValueListenableBuilder<TrackModel>(
                valueListenable: MusicService.instance.currentTrack,
                builder: (context, track, _) {
                  return Container(
                    constraints: const BoxConstraints(
                      maxWidth: 550,
                      maxHeight: 280,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        // Artwork Container
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 180,
                            height: 180,
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
                                  color: const Color(0xFF26262B),
                                  child: const Icon(Icons.music_note_rounded, size: 54, color: Colors.white30),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),

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
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              
                              // Artist / Album
                              Text(
                                track.artist.isNotEmpty 
                                    ? '${track.artist} — ${track.album}' 
                                    : 'Open Apple Music and select a song',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),

                              // Playback Duration Slider
                              Row(
                                children: [
                                  Text(
                                    _formatDuration(track.position),
                                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        activeTrackColor: const Color(0xFFFC3C44),
                                        inactiveTrackColor: Colors.white10,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Control Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous_rounded, size: 28),
                                    onPressed: () => MusicService.instance.previous(),
                                  ),
                                  const SizedBox(width: 12),
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: const Color(0xFFFC3C44),
                                    child: IconButton(
                                      icon: Icon(
                                        track.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: () => MusicService.instance.playPause(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, size: 28),
                                    onPressed: () => MusicService.instance.next(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Volume Control
                              Row(
                                children: [
                                  Icon(Icons.volume_down_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 2,
                                        activeTrackColor: Colors.white70,
                                        inactiveTrackColor: Colors.white10,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
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
                                  Icon(Icons.volume_up_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
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
          Icon(Icons.lock_clock_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Target view for future phases of application roadmap.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
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
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        backgroundColor: const Color(0xBB000000), // Transparent black
        body: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.subtitles_rounded, color: Color(0xFFFC3C44), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Multi-Window Engine Active',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
