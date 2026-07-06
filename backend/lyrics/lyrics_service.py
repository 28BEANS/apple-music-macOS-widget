import os
import re
import requests
from typing import Dict, Any, Optional
from parser import extract_lyrics

# Simple in-memory cache to prevent spamming APIs and scrapers
cache: Dict[str, Dict[str, Any]] = {}

# Session configured with timeout and custom User-Agent
session = requests.Session()
session.headers.update({
    'User-Agent': 'AppleMusicWidgetPlus/1.0.0 (https://github.com/28BEANS/apple-music-macOS-widget)'
})

def clean_search_query(text: str) -> str:
    """
    Normalizes search terms by stripping features and metadata noise.
    """
    if not text:
        return ""
    text = re.sub(r'\s*[\(\[]\s*feat(uring)?\..*?[\)\]]', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*[\(\[]\s*with\s+.*?[\)\]]', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*-\s*feat(uring)?\..*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*-\s*with\s+.*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'\s*[\(\[]\s*(remastered|mono|stereo|radio edit|deluxe|version).*?[\)\]]', '', text, flags=re.IGNORECASE)
    return text.strip()

def fetch_from_lrclib(artist: str, track: str, album: str = "", duration: float = 0.0) -> Optional[Dict[str, Any]]:
    """
    Attempts to fetch lyrics from LRCLIB.
    """
    try:
        # 1. Exact match signature lookup
        if duration and duration > 0:
            url = "https://lrclib.net/api/get"
            response = session.get(url, params={
                "artist_name": artist,
                "track_name": track,
                "album_name": album or "",
                "duration": round(duration)
            }, timeout=8)
            if response.status_code == 200:
                data = response.json()
                if data.get("plainLyrics") or data.get("syncedLyrics"):
                    return {
                        "plainLyrics": data.get("plainLyrics") or "",
                        "syncedLyrics": data.get("syncedLyrics") or "",
                        "source": "LRCLIB"
                    }

        # 2. General search query search
        cleaned_query = f"{clean_search_query(artist)} {clean_search_query(track)}"
        search_url = "https://lrclib.net/api/search"
        response = session.get(search_url, params={"q": cleaned_query}, timeout=8)
        if response.status_code == 200:
            results = response.json()
            if isinstance(results, list) and len(results) > 0:
                for item in results:
                    if item.get("plainLyrics") or item.get("syncedLyrics"):
                        return {
                            "plainLyrics": item.get("plainLyrics") or "",
                            "syncedLyrics": item.get("syncedLyrics") or "",
                            "source": "LRCLIB"
                        }
    except Exception as e:
        print(f"LRCLIB fetch error: {e}")
    return None

def fetch_from_genius(artist: str, track: str) -> Optional[Dict[str, Any]]:
    """
    Searches Genius API and scrapes the song webpage HTML for lyrics.
    """
    api_key = os.getenv("GENIUS_API_KEY")
    if not api_key or api_key == "your_genius_api_key_here":
        print("Genius API Key is not set or using placeholder.")
        return None

    try:
        cleaned_artist = clean_search_query(artist)
        cleaned_track = clean_search_query(track)
        query = f"{cleaned_artist} {cleaned_track}"

        search_url = "https://api.genius.com/search"
        response = session.get(search_url, params={"q": query}, headers={
            "Authorization": f"Bearer {api_key}"
        }, timeout=8)

        if response.status_code != 200:
            return None

        data = response.json()
        hits = data.get("response", {}).get("hits", [])
        if not hits:
            return None

        # Extract first song result hit
        song_hit = next((hit for hit in hits if hit.get("type") == "song"), None)
        if not song_hit or not song_hit.get("result", {}).get("url"):
            return None

        song_url = song_hit["result"]["url"]
        
        # Request Genius lyrics page HTML
        page_response = session.get(song_url, timeout=8)
        if page_response.status_code != 200:
            return None

        # Parse lyrics text using BeautifulSoup scraper
        lyrics_text = extract_lyrics(page_response.text)
        if lyrics_text:
            return {
                "plainLyrics": lyrics_text,
                "syncedLyrics": "",
                "source": "Genius"
            }
    except Exception as e:
        print(f"Genius fetch error: {e}")
    return None

def get_lyrics(artist: str, track: str, album: str = "", duration: float = 0.0) -> Dict[str, Any]:
    """
    Main resolution handler with caching and fallback steps.
    """
    if not artist or not track:
        raise ValueError("Artist and track parameters are required.")

    cache_key = f"{artist.strip()} - {track.strip()}".lower()
    if cache_key in cache:
        print(f"[Cache Hit] {artist} - {track}")
        return cache[cache_key]

    print(f"[Resolution Init] {artist} - {track}")

    # Query LRCLIB first
    result = fetch_from_lrclib(artist, track, album, duration)

    # Fallback to Genius scraping
    if not result:
        print(f"[Genius Fallback] {artist} - {track}")
        result = fetch_from_genius(artist, track)

    if result:
        cache[cache_key] = result
        return result

    not_found = {
        "plainLyrics": "",
        "syncedLyrics": "",
        "source": "None"
    }
    cache[cache_key] = not_found
    return not_found
