# Lyrics Backend Service

This is a lightweight Node.js/Express service that resolves timed (synced) and plain text lyrics for the Apple Music Widget+.

## Features

- **LRCLIB Integration:** Resolves timed (synced LRC) and plain lyrics directly.
- **Genius Fallback Scraper:** Automatically falls back to querying Genius API and scraping the webpage HTML if lyrics are not in LRCLIB.
- **In-Memory Caching:** Automatically caches lyric lookups to optimize performance and prevent rate limiting.

## Setup

1. Make sure you have your API keys in the `.env` file at the root workspace directory:
   ```env
   GENIUS_API_KEY=your_genius_api_key_here
   ```
2. Install dependencies:
   ```bash
   pnpm install
   ```
3. Run the development server:
   ```bash
   npm run dev
   ```
   The backend will be running at `http://localhost:8000`.

## API Endpoints

### `GET /api/lyrics`

Resolves the lyrics for the specified track.

#### Query Parameters

- `artist` (required): The track's artist name (e.g. `Justin Bieber`).
- `track` (required): The track title (e.g. `Peaches`).
- `album` (optional): The album title.
- `duration` (optional): The track duration in seconds.

#### Example Request

```http
GET http://localhost:8000/api/lyrics?artist=Justin+Bieber&track=Peaches&duration=198
```

#### Example Response

```json
{
  "success": true,
  "artist": "Justin Bieber",
  "track": "Peaches",
  "album": "",
  "plainLyrics": "[Chorus: Justin Bieber]\nI got my peaches out in Georgia...",
  "syncedLyrics": "[00:09.12][Chorus: Justin Bieber]\n[00:10.15]I got my peaches out in Georgia...",
  "source": "LRCLIB"
}
```
