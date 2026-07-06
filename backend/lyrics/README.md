# Lyrics Backend Service (Python)

This is a lightweight FastAPI-based service that resolves timed (synced) and plain text lyrics for the Apple Music Widget+.

## Features

- **LRCLIB Integration:** Resolves timed (synced LRC) and plain lyrics directly.
- **Genius Fallback Scraper:** Automatically falls back to querying Genius API and scraping the webpage HTML if lyrics are not in LRCLIB.
- **In-Memory Caching:** Automatically caches lyric lookups to optimize performance and prevent rate limiting.

## Setup & Local Run (Standalone)

1. Make sure you have your API keys in the `.env` file at the root workspace directory:
   ```env
   GENIUS_API_KEY=your_genius_api_key_here
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Start the server:
   ```bash
   python main.py
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
