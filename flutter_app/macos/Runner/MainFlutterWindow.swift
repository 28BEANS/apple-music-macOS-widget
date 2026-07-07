import Cocoa
import FlutterMacOS
import Foundation
import desktop_multi_window
import WidgetKit

class MainFlutterWindow: NSWindow {
  var bridge: AppleMusicBridge?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // Initialize our native bridge with the main window's messenger
    self.bridge = AppleMusicBridge(messenger: flutterViewController.engine.binaryMessenger)

    // Set up Callback for desktop_multi_window plugin
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { [weak self] controller in
        RegisterGeneratedPlugins(registry: controller)
        // Also register the bridge on the new window's binary messenger
        if let self = self {
            self.bridge?.registerMessenger(controller.engine.binaryMessenger)
        }
    }

    super.awakeFromNib()
  }
}

class AppleMusicBridge: NSObject {
    private var channels: [FlutterMethodChannel] = []
    
    init(messenger: FlutterBinaryMessenger) {
        super.init()
        registerMessenger(messenger)
        startObserving()
        
        // Initial state population
        updateTrackInfo()
    }
    
    func registerMessenger(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.example.music_widget/bridge", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        }
        channels.append(channel)
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "playPause":
            playPause()
            updateTrackInfo()
            result(nil)
        case "nextTrack":
            nextTrack()
            updateTrackInfo()
            result(nil)
        case "previousTrack":
            previousTrack()
            updateTrackInfo()
            result(nil)
        case "setVolume":
            if let args = call.arguments as? [String: Any], let volume = args["volume"] as? Int {
                setVolume(volume)
                updateTrackInfo()
            }
            result(nil)
        case "seek":
            if let args = call.arguments as? [String: Any], let position = args["position"] as? Double {
                seekTo(position)
                updateTrackInfo()
            }
            result(nil)
        case "getPlaybackState":
            result(getPlaybackState())
        case "triggerUpdate":
            updateTrackInfo()
            result(nil)
        case "getArtworkPath":
            result(getSharedContainerURL()?.appendingPathComponent("artwork.jpg").path)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Distributed Notifications Observer
    
    private func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playerInfoChanged(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfoChanged"),
            object: nil
        )
    }
    
    @objc private func playerInfoChanged(_ notification: Notification) {
        updateTrackInfo()
    }
    
    private func updateTrackInfo() {
        let json = getPlaybackState()
        updateSharedDefaults(jsonString: json)
        saveArtwork()
        
        // Invalidate and reload WidgetKit timelines
        if #available(macOS 11.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        // Broadcast track update to all active Flutter window engines
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for channel in self.channels {
                channel.invokeMethod("trackChanged", arguments: json)
            }
        }
    }
    
    // MARK: - AppleScript Execution
    
    private func getPlaybackState() -> String {
        let source = #"""
        tell application "Music"
            if it is running then
                set currentState to player state as string
                if currentState is not "stopped" then
                    set currentTrack to current track
                    set trackName to name of currentTrack
                    set artistName to artist of currentTrack
                    set albumName to album of currentTrack
                    set trackDuration to duration of currentTrack
                    set playerPosition to player position
                    set trackId to persistent ID of currentTrack
                    set currentVolume to sound volume
                    
                    set trackNameEscaped to my replaceText(trackName, "\"", "\\\"")
                    set artistNameEscaped to my replaceText(artistName, "\"", "\\\"")
                    set albumNameEscaped to my replaceText(albumName, "\"", "\\\"")
                    
                    return "{\"status\":\"success\", \"playerState\":\"" & currentState & "\", \"name\":\"" & trackNameEscaped & "\", \"artist\":\"" & artistNameEscaped & "\", \"album\":\"" & albumNameEscaped & "\", \"duration\":" & trackDuration & ", \"position\":" & playerPosition & ", \"trackId\":\"" & trackId & "\", \"volume\":" & currentVolume & "}"
                else
                    return "{\"status\":\"stopped\"}"
                end if
            else
                return "{\"status\":\"not_running\"}"
            end if
        end tell

        on replaceText(theText, searchString, replaceString)
            set OldDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to searchString
            set theItems to every text item of theText
            set AppleScript's text item delimiters to replaceString
            set theText to theItems as string
            set AppleScript's text item delimiters to OldDelims
            return theText
        end replaceText
        """#
        
        guard let script = NSAppleScript(source: source) else {
            return "{\"status\":\"error\", \"message\":\"Failed to create script\"}"
        }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            print("AppleScript Metadata Error: \(error)")
            return "{\"status\":\"error\", \"message\":\"AppleScript error\"}"
        }
        return descriptor.stringValue ?? "{\"status\":\"stopped\"}"
    }
    
    private func getArtworkData() -> Data? {
        let source = #"""
        tell application "Music"
            if it is running and player state is not stopped then
                tell current track
                    if exists artwork 1 then
                        return raw data of artwork 1
                    end if
                end tell
            end if
        end tell
        """#
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            print("AppleScript Artwork Error: \(error)")
            return nil
        }
        return descriptor.data
    }
    
    // MARK: - Playback Control Commands
    
    private func playPause() {
        executeSimpleScript("tell application \"Music\" to playpause")
    }
    
    private func nextTrack() {
        executeSimpleScript("tell application \"Music\" to next track")
    }
    
    private func previousTrack() {
        executeSimpleScript("tell application \"Music\" to previous track")
    }
    
    private func setVolume(_ volume: Int) {
        executeSimpleScript("tell application \"Music\" to set sound volume to \(volume)")
    }
    
    private func seekTo(_ position: Double) {
        executeSimpleScript("tell application \"Music\" to set player position to \(position)")
    }
    
    private func executeSimpleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else { return }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            print("AppleScript Command Error: \(error)")
        }
    }
    
    // MARK: - Persistence & Assets
    
    private func getSharedContainerURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let container = home.appendingPathComponent("Library/Containers/com.example.musicWidget.WidgetExtension/Data")
        do {
            try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true, attributes: nil)
            return container
        } catch {
            print("Failed to resolve/create Widget container URL: \(error). Falling back to cache directory.")
            if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let appCacheURL = cacheURL.appendingPathComponent("com.example.musicWidget")
                try? FileManager.default.createDirectory(at: appCacheURL, withIntermediateDirectories: true, attributes: nil)
                return appCacheURL
            }
            return nil
        }
    }
    
    private func saveArtwork() {
        guard let containerURL = getSharedContainerURL() else { return }
        let artworkURL = containerURL.appendingPathComponent("artwork.jpg")
        if let data = getArtworkData() {
            do {
                try data.write(to: artworkURL, options: .atomic)
            } catch {
                print("Failed to save artwork image: \(error)")
            }
        } else {
            try? FileManager.default.removeItem(at: artworkURL)
        }
    }
    
    private func updateSharedDefaults(jsonString: String) {
        guard let containerURL = getSharedContainerURL() else { return }
        let stateURL = containerURL.appendingPathComponent("state.json")
        do {
            try jsonString.write(to: stateURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save state.json: \(error)")
        }
        
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return
        }
        
        let defaults = UserDefaults(suiteName: "group.com.example.musicWidget") ?? UserDefaults.standard
        
        if let status = dict["status"] as? String, status == "success" {
            defaults.set(dict["name"] as? String, forKey: "trackName")
            defaults.set(dict["artist"] as? String, forKey: "artistName")
            defaults.set(dict["album"] as? String, forKey: "albumName")
            defaults.set(dict["duration"] as? Double ?? 0.0, forKey: "trackDuration")
            defaults.set(dict["position"] as? Double ?? 0.0, forKey: "playerPosition")
            defaults.set(dict["playerState"] as? String, forKey: "playerState")
            defaults.set(dict["volume"] as? Int ?? 50, forKey: "playerVolume")
            defaults.set(dict["trackId"] as? String, forKey: "trackId")
            defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdated")
        } else {
            defaults.set(nil, forKey: "trackName")
            defaults.set(nil, forKey: "artistName")
            defaults.set(nil, forKey: "albumName")
            defaults.set(0.0, forKey: "trackDuration")
            defaults.set(0.0, forKey: "playerPosition")
            defaults.set(dict["playerState"] as? String ?? "stopped", forKey: "playerState")
            defaults.set(Date().timeIntervalSince1970, forKey: "lastUpdated")
        }
        defaults.synchronize()
    }
}
