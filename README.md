# 🎵 Apple Music Widget+

A modern, highly polished macOS desktop companion and interactive Widget for **Apple Music** built using Flutter, Python, and Apple Swift. It brings live track status, playback controls, real-time synced lyrics, and a native macOS Notification Center/Desktop widget into a unified premium experience.

---

## ✨ Features

- **Interactive Desktop Dashboard:** A premium glassmorphic UI displaying the active track, artist, album, live playback time, and high-resolution album artwork.
- **Synced Lyrics Panel:** A companion window displaying real-time scrolling lyrics synced directly with your Apple Music playback.
- **Native macOS Widget:** Native widget support for Notification Center and Desktop via a Swift-based `WidgetKit` extension.
- **Robust Lyrics Resolution:** Powered by a local FastAPI backend that pulls time-synced lyrics from LRCLIB with an automatic Genius scraping fallback.
- **Native AppleScript Integration:** Directly queries and controls the local macOS Apple Music app, keeping lag to a minimum.

---

## 🏗️ Project Architecture

The workspace is organized into two primary components:

1. **`flutter_app/` (Frontend & Native Widget):**
   - **Flutter Application:** Manages the main desktop controller dashboard and multi-window sync.
   - **Native Widget Extension:** Built using `WidgetKit` in Swift. Communicates securely with the host application via macOS App Groups sharing state at `4P3L9J4NCH.group.com.vinceevangelista.musicWidget`.
2. **`backend/` (Lyrics Resolution Proxy):**
   - **FastAPI / Uvicorn Server:** Runs locally at `http://localhost:8000`. Fetches lyrics from LRCLIB and Genius, processes LRC timing patterns, and provides an in-memory cache to prevent API rate limits.

---

## ⚙️ Prerequisites

To run or build the project, ensure you have:
- **macOS Sonoma (14.0)** or later.
- **Flutter SDK** (3.12.x or later).
- **Python 3.9+** (installed with virtual environment support).
- **Apple Music App** installed and running on your Mac.
- **Apple Development Certificate** in your macOS Keychain (required for manual codesigning validation of the widget extension).

---

## 🚀 Setup & Local Running

The workspace includes a premium bootstrap script `start.sh` that takes care of checking configurations, starting the FastAPI service, and launching the Flutter client.

### 1. Configure the Environment
Copy the example environment template to `.env` in the workspace root directory:
```bash
cp .env.example .env
```
Open `.env` and fill in your keys:
- `GENIUS_API_KEY`: Obtain this from the [Genius Developer Portal](https://genius.com/api-clients) to enable Genius scraping fallback when time-synced lyrics are not available.
- `BACKEND_URL`: Defaults to `http://localhost:8000`.

### 2. Launch Developer Mode
Simply grant execution permissions and run the boostrapper script at the root of the project:
```bash
chmod +x start.sh
./start.sh
```

This will automatically:
1. Verify the `.env` settings.
2. Initialize the Python virtual environment under `backend/lyrics/.venv`.
3. Install dependencies from `requirements.txt`.
4. Start the FastAPI local server.
5. Launch the Flutter macOS client targeting the local workspace context.

---

## 🎨 How to Install & Run the Native macOS Widget

Because macOS security layers (`chronod`) strictly validate third-party widget extensions, the extension must be signed and registered correctly.

### 1. Build the Release Bundle
Compile the Flutter app and its native Swift extensions:
```bash
cd flutter_app
flutter build macos --release
```

### 2. Copy and Register the Application
Run the following commands to install the release version to your user application cache and notify Launch Services:
```bash
# Copy the built production bundle
cp -R build/macos/Build/Products/Release/music_widget.app ~/Applications/

# Force Launch Services to index the application and locate the extension
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f ~/Applications/music_widget.app
```

### 3. Register and Enable the Widget Kit Extension
```bash
# Register the .appex plugin extension
pluginkit -a ~/Applications/music_widget.app/Contents/PlugIns/WidgetExtension.appex

# Enable it for system-wide layout caching
pluginkit -e use -i com.vinceevangelista.musicWidget.WidgetExtension
```

### 4. Restart System Daemons
Finally, force macOS's widget manager daemon (`chronod`) and the Notification Center to restart and discover the newly registered widget:
```bash
killall chronod && killall NotificationCenter
```

### 5. Add Widget to Desktop
1. Right-click on your macOS desktop and select **Edit Widgets...** (or open the Notification Center, scroll to the bottom, and click **Edit Widgets**).
2. Locate **music_widget** from the side-bar search panel.
3. Click or drag the interactive widget layout to place it onto your desktop or Notification Center panel!
