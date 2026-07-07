import WidgetKit
import SwiftUI
import AppIntents

// -----------------------------------------------------------------------------
// WIDGET ENTRY & TIMELINE PROVIDER
// -----------------------------------------------------------------------------

struct MusicWidgetEntry: TimelineEntry {
    let date: Date
    let trackName: String
    let artistName: String
    let albumName: String
    let duration: Double
    let position: Double
    let playerState: String
    let volume: Int
    let trackId: String
    let artwork: NSImage?
}

struct MusicWidgetProvider: TimelineProvider {
    typealias Entry = MusicWidgetEntry
    
    func placeholder(in context: Context) -> MusicWidgetEntry {
        MusicWidgetEntry(
            date: Date(),
            trackName: "Not Playing",
            artistName: "No Artist",
            albumName: "",
            duration: 1.0,
            position: 0.0,
            playerState: "stopped",
            volume: 50,
            trackId: "",
            artwork: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MusicWidgetEntry) -> ()) {
        let entry = readCurrentTrack()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readCurrentTrack()
        
        // Define timeline policy: refresh when song is expected to end,
        // or in 5 minutes as a standard polling fallback.
        let refreshDate: Date
        if entry.playerState == "playing" && entry.duration > entry.position {
            let remaining = entry.duration - entry.position
            refreshDate = Date().addingTimeInterval(max(remaining, 3.0))
        } else {
            refreshDate = Date().addingTimeInterval(300.0)
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func readCurrentTrack() -> MusicWidgetEntry {
        let containerPath = NSHomeDirectory()
        let containerURL = URL(fileURLWithPath: containerPath)
        let stateURL = containerURL.appendingPathComponent("state.json")
        let artworkURL = containerURL.appendingPathComponent("artwork.jpg")
        
        var trackName = ""
        var artistName = ""
        var albumName = ""
        var duration = 1.0
        var position = 0.0
        var playerState = "stopped"
        var volume = 50
        var trackId = ""
        
        if let data = try? Data(contentsOf: stateURL),
           let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let status = dict["status"] as? String, status == "success" {
                trackName = dict["name"] as? String ?? ""
                artistName = dict["artist"] as? String ?? ""
                albumName = dict["album"] as? String ?? ""
                duration = dict["duration"] as? Double ?? 1.0
                position = dict["position"] as? Double ?? 0.0
                playerState = dict["playerState"] as? String ?? "stopped"
                volume = dict["volume"] as? Int ?? 50
                trackId = dict["trackId"] as? String ?? ""
            } else if let pState = dict["playerState"] as? String {
                playerState = pState
            }
        }
        
        var artworkImage: NSImage? = nil
        if FileManager.default.fileExists(atPath: artworkURL.path) {
            artworkImage = NSImage(contentsOf: artworkURL)
        }
        
        return MusicWidgetEntry(
            date: Date(),
            trackName: trackName,
            artistName: artistName,
            albumName: albumName,
            duration: duration,
            position: position,
            playerState: playerState,
            volume: volume,
            trackId: trackId,
            artwork: artworkImage
        )
    }
}

// -----------------------------------------------------------------------------
// INTERACTIVE CONTROL INTENTS (macOS 14+)
// -----------------------------------------------------------------------------

private func callBackend(endpoint: String) {
    guard let url = URL(string: "http://127.0.0.1:8000/api/\(endpoint)") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.dataTask(with: request) { _, _, _ in
        semaphore.signal()
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 1.2)
}

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause"
    static var description = IntentDescription("Toggles Apple Music play/pause state.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        callBackend(endpoint: "playpause")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skips to the next track in Apple Music.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        callBackend(endpoint: "next")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Skips to the previous track in Apple Music.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        callBackend(endpoint: "previous")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// -----------------------------------------------------------------------------
// WIDGET VIEWS
// -----------------------------------------------------------------------------

struct SmallWidgetView: View {
    var entry: MusicWidgetProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.trackName.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 26))
                        .foregroundColor(.red)
                    Text("Not Playing")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Open Music app")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
            } else {
                if let artwork = entry.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.4))
                        )
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.trackName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(entry.artistName)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MediumWidgetView: View {
    var entry: MusicWidgetProvider.Entry
    
    private var playbackDateRange: ClosedRange<Date>? {
        guard entry.playerState == "playing", entry.duration > 0, entry.position >= 0 else { return nil }
        let now = Date()
        let start = now.addingTimeInterval(-entry.position)
        let end = start.addingTimeInterval(entry.duration)
        return start < end ? start...end : nil
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        if seconds.isNaN || seconds.isInfinite || seconds <= 0 { return "0:00" }
        let totalSecs = Int(seconds)
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Artwork on Left
            if let artwork = entry.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 105, height: 105)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 105, height: 105)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.35))
                    )
            }
            
            // Metadata & Controls on Right
            VStack(alignment: .leading, spacing: 0) {
                if entry.trackName.isEmpty {
                    Text("No Track Playing")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Select a song in Apple Music")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 4)
                } else {
                    Text(entry.trackName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(entry.artistName) — \(entry.albumName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .padding(.top, 2)
                    
                    // Live Ticking Progress Bar
                    VStack(spacing: 3) {
                        if let range = playbackDateRange {
                            ProgressView(timerInterval: range, countsDown: false)
                                .tint(Color(red: 0.99, green: 0.24, blue: 0.27)) // Apple Music Red
                        } else {
                            ProgressView(value: min(entry.position, entry.duration), total: max(entry.duration, 1.0))
                                .tint(Color.white.opacity(0.4))
                        }
                        
                        HStack {
                            if entry.playerState == "playing" {
                                Text(Date(timeIntervalSinceNow: -entry.position), style: .timer)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            } else {
                                Text(formatDuration(entry.position))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            
                            Spacer()
                            
                            Text(formatDuration(entry.duration))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.top, 10)
                    
                    // Transport Buttons
                    HStack(spacing: 16) {
                        Button(intent: PreviousTrackIntent()) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: PlayPauseIntent()) {
                            Image(systemName: entry.playerState == "playing" ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color(red: 0.99, green: 0.24, blue: 0.27))
                                .clipShape(Circle())
                                .shadow(color: Color(red: 0.99, green: 0.24, blue: 0.27).opacity(0.3), radius: 4, x: 0, y: 1.5)
                        }
                        .buttonStyle(.plain)
                        
                        Button(intent: NextTrackIntent()) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 28, height: 28)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
    }
}

struct WidgetBackgroundView: View {
    var entry: MusicWidgetProvider.Entry
    
    var body: some View {
        ZStack {
            if let artwork = entry.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 28)
                    .opacity(0.35)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.12, blue: 0.15), Color(red: 0.06, green: 0.06, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            Color.black.opacity(0.52)
        }
    }
}

struct MusicWidgetEntryView: View {
    var entry: MusicWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
    }
}

// -----------------------------------------------------------------------------
// WIDGET CONFIGURATION
// -----------------------------------------------------------------------------

struct MusicWidget: Widget {
    let kind: String = "com.example.musicWidget.WidgetExtension"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicWidgetProvider()) { entry in
            MusicWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(entry: entry)
                }
        }
        .configurationDisplayName("Apple Music Widget+")
        .description("Display and control current Apple Music playback.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusicWidget()
    }
}
