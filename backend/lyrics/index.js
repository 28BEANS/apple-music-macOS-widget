import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import { getLyrics } from './lyrics_service.js';

// Resolve file paths for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env from backend/lyrics/ or fallback to root workspace .env
dotenv.config();
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const app = express();
const PORT = process.env.PORT || 8000;

// Enable CORS and JSON parsing middle-wares
app.use(cors());
app.use(express.json());

// Log incoming API queries
app.use((req, res, next) => {
  console.log(`[HTTP] ${req.method} ${req.url}`);
  next();
});

// Primary lyric resolution endpoint
app.get('/api/lyrics', async (req, res) => {
  const { artist, track, album, duration } = req.query;

  if (!artist || !track) {
    return res.status(400).json({
      success: false,
      error: 'Missing required parameters. Make sure artist and track are provided.'
    });
  }

  try {
    const parsedDuration = duration ? parseFloat(duration) : 0;
    const lyricsData = await getLyrics(artist.toString(), track.toString(), album?.toString() || '', parsedDuration);
    
    if (lyricsData.plainLyrics || lyricsData.syncedLyrics) {
      return res.json({
        success: true,
        artist,
        track,
        album: album || '',
        plainLyrics: lyricsData.plainLyrics,
        syncedLyrics: lyricsData.syncedLyrics,
        source: lyricsData.source
      });
    } else {
      return res.status(404).json({
        success: false,
        error: 'Lyrics not found for the requested track'
      });
    }
  } catch (error) {
    console.error('Server endpoint error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error while resolving lyrics'
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'lyrics-backend' });
});

// Start listening
app.listen(PORT, () => {
  console.log(`==================================================`);
  console.log(`🎵 Apple Music Widget+ Lyrics Backend is Active`);
  console.log(`🚀 Running at: http://localhost:${PORT}`);
  console.log(`🔑 Genius API Key: ${process.env.GENIUS_API_KEY ? 'CONFIGURED' : 'MISSING'}`);
  console.log(`==================================================`);
});
