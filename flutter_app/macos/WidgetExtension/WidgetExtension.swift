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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "4P3L9J4NCH.group.com.vinceevangelista.musicWidget") else {
            return MusicWidgetEntry(
                date: Date(),
                trackName: "",
                artistName: "",
                albumName: "",
                duration: 1.0,
                position: 0.0,
                playerState: "stopped",
                volume: 50,
                trackId: "",
                artwork: nil
            )
        }
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
// PINS WIDGET DATA & TIMELINE PROVIDER
// -----------------------------------------------------------------------------

struct PinItem {
    let trackName: String
    let artistName: String
    let albumName: String
    let artwork: NSImage?
}

struct PinsWidgetEntry: TimelineEntry {
    let date: Date
    let pins: [PinItem]
}

struct PinsWidgetProvider: TimelineProvider {
    typealias Entry = PinsWidgetEntry
    
    func placeholder(in context: Context) -> PinsWidgetEntry {
        PinsWidgetEntry(
            date: Date(),
            pins: (0..<6).map { i in
                PinItem(trackName: "Album \(i + 1)", artistName: "Artist", albumName: "Album", artwork: nil)
            }
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PinsWidgetEntry) -> ()) {
        let entry = readPins()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readPins()
        let refreshDate = Date().addingTimeInterval(600.0) // Refresh every 10 minutes
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func readPins() -> PinsWidgetEntry {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "4P3L9J4NCH.group.com.vinceevangelista.musicWidget") else {
            return PinsWidgetEntry(date: Date(), pins: mockPins())
        }
        
        let pinsURL = containerURL.appendingPathComponent("pins.json")
        
        if let data = try? Data(contentsOf: pinsURL),
           let array = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            var items: [PinItem] = []
            for dict in array.prefix(6) {
                let name = dict["name"] as? String ?? ""
                let artist = dict["artist"] as? String ?? ""
                let album = dict["album"] as? String ?? ""
                var artwork: NSImage? = nil
                if let artPath = dict["artworkPath"] as? String {
                    let artURL = containerURL.appendingPathComponent(artPath)
                    if FileManager.default.fileExists(atPath: artURL.path) {
                        artwork = NSImage(contentsOf: artURL)
                    }
                }
                items.append(PinItem(trackName: name, artistName: artist, albumName: album, artwork: artwork))
            }
            if !items.isEmpty {
                return PinsWidgetEntry(date: Date(), pins: items)
            }
        }
        
        // Fallback to mock data when no pins.json exists
        return PinsWidgetEntry(date: Date(), pins: mockPins())
    }
    
    private func mockPins() -> [PinItem] {
        let names = ["Cherry Bomb", "DON'T TAP THE GLASS", "CHROMAKOPIA+", "Wolf", "CALL ME IF YOU GET LOST: Th...", "Goblin"]
        return names.map { name in
            PinItem(trackName: name, artistName: "", albumName: name, artwork: nil)
        }
    }
}

// -----------------------------------------------------------------------------
// RECENTLY PLAYED WIDGET DATA & TIMELINE PROVIDER
// -----------------------------------------------------------------------------

struct RecentItem {
    let trackName: String
    let artistName: String
    let artwork: NSImage?
}

struct RecentlyPlayedWidgetEntry: TimelineEntry {
    let date: Date
    let currentTrackName: String
    let currentArtistName: String
    let currentAlbumName: String
    let playerState: String
    let currentArtwork: NSImage?
    let recentItems: [RecentItem]
}

struct RecentlyPlayedWidgetProvider: TimelineProvider {
    typealias Entry = RecentlyPlayedWidgetEntry
    
    func placeholder(in context: Context) -> RecentlyPlayedWidgetEntry {
        RecentlyPlayedWidgetEntry(
            date: Date(),
            currentTrackName: "Isolation",
            currentArtistName: "Kali Uchis",
            currentAlbumName: "Isolation",
            playerState: "playing",
            currentArtwork: nil,
            recentItems: [
                RecentItem(trackName: "This Is How Tomorrow Moves", artistName: "", artwork: nil),
                RecentItem(trackName: "?", artistName: "beans", artwork: nil),
                RecentItem(trackName: "Do That Again", artistName: "Malcolm Todd", artwork: nil)
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RecentlyPlayedWidgetEntry) -> ()) {
        let entry = readRecentlyPlayed()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readRecentlyPlayed()
        let refreshDate: Date
        if entry.playerState == "playing" {
            refreshDate = Date().addingTimeInterval(30.0) // Refresh more frequently when playing
        } else {
            refreshDate = Date().addingTimeInterval(300.0)
        }
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func readRecentlyPlayed() -> RecentlyPlayedWidgetEntry {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "4P3L9J4NCH.group.com.vinceevangelista.musicWidget") else {
            return mockEntry()
        }
        
        // Read current track from state.json (same as MusicWidgetProvider)
        let stateURL = containerURL.appendingPathComponent("state.json")
        let artworkURL = containerURL.appendingPathComponent("artwork.jpg")
        let recentsURL = containerURL.appendingPathComponent("recents.json")
        
        var currentTrackName = ""
        var currentArtistName = ""
        var currentAlbumName = ""
        var playerState = "stopped"
        
        if let data = try? Data(contentsOf: stateURL),
           let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let status = dict["status"] as? String, status == "success" {
                currentTrackName = dict["name"] as? String ?? ""
                currentArtistName = dict["artist"] as? String ?? ""
                currentAlbumName = dict["album"] as? String ?? ""
                playerState = dict["playerState"] as? String ?? "stopped"
            }
        }
        
        var currentArtwork: NSImage? = nil
        if FileManager.default.fileExists(atPath: artworkURL.path) {
            currentArtwork = NSImage(contentsOf: artworkURL)
        }
        
        // Read recent items from recents.json
        var recentItems: [RecentItem] = []
        if let data = try? Data(contentsOf: recentsURL),
           let array = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            for dict in array.prefix(3) {
                let name = dict["name"] as? String ?? ""
                let artist = dict["artist"] as? String ?? ""
                var artwork: NSImage? = nil
                if let artPath = dict["artworkPath"] as? String {
                    let artURL = containerURL.appendingPathComponent(artPath)
                    if FileManager.default.fileExists(atPath: artURL.path) {
                        artwork = NSImage(contentsOf: artURL)
                    }
                }
                recentItems.append(RecentItem(trackName: name, artistName: artist, artwork: artwork))
            }
        }
        
        // Use mock recent items if none found
        if recentItems.isEmpty {
            recentItems = mockRecentItems()
        }
        
        // If no current track, use mock
        if currentTrackName.isEmpty {
            return mockEntry()
        }
        
        return RecentlyPlayedWidgetEntry(
            date: Date(),
            currentTrackName: currentTrackName,
            currentArtistName: currentArtistName,
            currentAlbumName: currentAlbumName,
            playerState: playerState,
            currentArtwork: currentArtwork,
            recentItems: recentItems
        )
    }
    
    private func mockEntry() -> RecentlyPlayedWidgetEntry {
        return RecentlyPlayedWidgetEntry(
            date: Date(),
            currentTrackName: "Isolation",
            currentArtistName: "Kali Uchis",
            currentAlbumName: "Isolation",
            playerState: "paused",
            currentArtwork: nil,
            recentItems: mockRecentItems()
        )
    }
    
    private func mockRecentItems() -> [RecentItem] {
        return [
            RecentItem(trackName: "This Is How Tomorrow Moves", artistName: "", artwork: nil),
            RecentItem(trackName: "?", artistName: "beans", artwork: nil),
            RecentItem(trackName: "Do That Again", artistName: "Malcolm Todd", artwork: nil)
        ]
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

// -----------------------------------------------------------------------------
// PINS WIDGET VIEW
// -----------------------------------------------------------------------------

struct PinsWidgetView: View {
    var entry: PinsWidgetProvider.Entry
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: "Pins" label + music note icon
            HStack {
                Text("Pins")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "music.note")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // 3×2 Grid of album artworks
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<min(entry.pins.count, 6), id: \.self) { index in
                    let pin = entry.pins[index]
                    VStack(spacing: 4) {
                        if let artwork = pin.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                        
                        Text(pin.trackName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

// -----------------------------------------------------------------------------
// RECENTLY PLAYED WIDGET VIEW
// -----------------------------------------------------------------------------

struct RecentlyPlayedWidgetView: View {
    var entry: RecentlyPlayedWidgetProvider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section: Hero current track
            HStack(spacing: 14) {
                // Large album artwork
                if let artwork = entry.currentArtwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 85, height: 85)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 85, height: 85)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.35))
                        )
                }
                
                // Track info + Play button
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        // Music note icon top-right
                        Spacer()
                        Image(systemName: "music.note")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Text(entry.currentTrackName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(entry.currentArtistName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                    
                    // Play button
                    Button(intent: PlayPauseIntent()) {
                        HStack(spacing: 5) {
                            Image(systemName: entry.playerState == "playing" ? "pause.fill" : "play.fill")
                                .font(.system(size: 9))
                            Text(entry.playerState == "playing" ? "Pause" : "Play")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 10)
            
            // "RECENTLY PLAYED" section header
            Text("RECENTLY PLAYED")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(0.8)
                .padding(.bottom, 6)
            
            // Recent items list
            VStack(spacing: 0) {
                ForEach(0..<min(entry.recentItems.count, 3), id: \.self) { index in
                    let item = entry.recentItems[index]
                    HStack(spacing: 10) {
                        // Small artwork thumbnail
                        if let artwork = item.artwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 34, height: 34)
                                .cornerRadius(6)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.3))
                                )
                        }
                        
                        // Track info
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.trackName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if !item.artistName.isEmpty {
                                Text(item.artistName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        // Play button
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

// -----------------------------------------------------------------------------
// PINS WIDGET BACKGROUND VIEW
// -----------------------------------------------------------------------------

struct PinsWidgetBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.12, blue: 0.15), Color(red: 0.06, green: 0.06, blue: 0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct RecentlyPlayedWidgetBackgroundView: View {
    var entry: RecentlyPlayedWidgetProvider.Entry
    
    var body: some View {
        ZStack {
            if let artwork = entry.currentArtwork {
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

struct PinsWidgetEntryView: View {
    var entry: PinsWidgetProvider.Entry
    
    var body: some View {
        PinsWidgetView(entry: entry)
    }
}

struct RecentlyPlayedWidgetEntryView: View {
    var entry: RecentlyPlayedWidgetProvider.Entry
    
    var body: some View {
        RecentlyPlayedWidgetView(entry: entry)
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
    let kind: String = "com.vinceevangelista.musicWidget.WidgetExtension"
    
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

struct PinsWidget: Widget {
    let kind: String = "com.vinceevangelista.musicWidget.PinsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PinsWidgetProvider()) { entry in
            PinsWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    PinsWidgetBackgroundView()
                }
        }
        .configurationDisplayName("Pins")
        .description("Quickly access your pinned items.")
        .supportedFamilies([.systemLarge])
    }
}

struct RecentlyPlayedWidget: Widget {
    let kind: String = "com.vinceevangelista.musicWidget.RecentlyPlayedWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentlyPlayedWidgetProvider()) { entry in
            RecentlyPlayedWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    RecentlyPlayedWidgetBackgroundView(entry: entry)
                }
        }
        .configurationDisplayName("Recently Played")
        .description("Find all your recently played music, and see what's currently playing.")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct MusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusicWidget()
        PinsWidget()
        RecentlyPlayedWidget()
    }
}
