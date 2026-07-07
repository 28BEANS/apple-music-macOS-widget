import os
from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from lyrics_service import get_lyrics

# Load .env file from root of the workspace
current_dir = os.path.dirname(os.path.abspath(__file__))
dotenv_path = os.path.join(current_dir, "../../.env")
load_dotenv(dotenv_path=dotenv_path)

app = FastAPI(title="Apple Music Widget+ Lyrics Backend")

# Enable CORS for Flutter/desktop-multi-window clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/lyrics")
def resolve_lyrics(
    artist: str = Query(..., description="Artist name"),
    track: str = Query(..., description="Track title"),
    album: str = Query("", description="Album name"),
    duration: float = Query(0.0, description="Track duration in seconds")
):
    if not artist or not track:
        raise HTTPException(status_code=400, detail="Missing required parameters: artist and track")

    try:
        lyrics_data = get_lyrics(artist, track, album, duration)
        if lyrics_data.get("plainLyrics") or lyrics_data.get("syncedLyrics"):
            return {
                "success": True,
                "artist": artist,
                "track": track,
                "album": album,
                "plainLyrics": lyrics_data.get("plainLyrics"),
                "syncedLyrics": lyrics_data.get("syncedLyrics"),
                "source": lyrics_data.get("source")
            }
        else:
            raise HTTPException(status_code=404, detail="Lyrics not found for the requested track")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        print(f"Server endpoint error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error while resolving lyrics")

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "lyrics-backend"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    print("==================================================")
    print("🎵 Apple Music Widget+ Python Lyrics Backend is Active")
    print(f"🚀 Running at: http://localhost:{port}")
    print(f"🔑 Genius API Key: {'CONFIGURED' if os.getenv('GENIUS_API_KEY') else 'MISSING'}")
    print("==================================================")
    uvicorn.run("main:app", host="0.0.0.0", port=port, log_level="info")
