import axios from 'axios';
import { extractLyrics } from './parser.js';

// Simple in-memory cache to prevent redundant API queries and scraping
const cache = new Map();

// HTTP Client configured with a reasonable timeout and User-Agent
const httpClient = axios.create({
  timeout: 8000,
  headers: {
    'User-Agent': 'AppleMusicWidgetPlus/1.0.0 (https://github.com/28BEANS/apple-music-macOS-widget)'
  }
});

/**
 * Normalizes song/artist names by stripping common noise like "feat.", "(Remastered)", etc.
 * @param {string} str - Raw input name.
 * @returns {string} Cleaned name.
 */
function cleanSearchQuery(str) {
  if (!str) return '';
  return str
    .replace(/\s*[\(\[]\s*feat(uring)?\..*?[\)\]]/gi, '')
    .replace(/\s*[\(\[]\s*with\s+.*?[\)\]]/gi, '')
    .replace(/\s*-\s*feat(uring)?\..*/gi, '')
    .replace(/\s*-\s*with\s+.*/gi, '')
    .replace(/\s*[\(\[]\s*(remastered|mono|stereo|radio edit|deluxe|version).*?[\)\]]/gi, '')
    .trim();
}

/**
 * Searches LRCLIB for lyrics.
 * @param {string} artist - Artist name.
 * @param {string} track - Track title.
 * @param {string} [album] - Album title.
 * @param {number} [duration] - Track duration in seconds.
 * @returns {Promise<object|null>} Lyric record if found, otherwise null.
 */
async function fetchFromLRCLIB(artist, track, album, duration) {
  try {
    // 1. Try exact match signature lookup if duration is available
    if (duration && duration > 0) {
      const url = `https://lrclib.net/api/get`;
      const response = await httpClient.get(url, {
        params: {
          artist_name: artist,
          track_name: track,
          album_name: album || '',
          duration: Math.round(duration)
        },
        validateStatus: (status) => status === 200 || status === 404
      });

      if (response.status === 200 && response.data && (response.data.plainLyrics || response.data.syncedLyrics)) {
        return {
          plainLyrics: response.data.plainLyrics || '',
          syncedLyrics: response.data.syncedLyrics || '',
          source: 'LRCLIB'
        };
      }
    }

    // 2. Fallback to general search query on LRCLIB
    const cleanedQuery = `${cleanSearchQuery(artist)} ${cleanSearchQuery(track)}`;
    const searchUrl = `https://lrclib.net/api/search`;
    const searchResponse = await httpClient.get(searchUrl, {
      params: { q: cleanedQuery }
    });

    if (searchResponse.status === 200 && Array.isArray(searchResponse.data) && searchResponse.data.length > 0) {
      // Find the first result with actual lyrics
      const bestMatch = searchResponse.data.find(item => item.plainLyrics || item.syncedLyrics);
      if (bestMatch) {
        return {
          plainLyrics: bestMatch.plainLyrics || '',
          syncedLyrics: bestMatch.syncedLyrics || '',
          source: 'LRCLIB'
        };
      }
    }
  } catch (error) {
    console.error('LRCLIB fetch error:', error.message);
  }
  return null;
}

/**
 * Resolves lyrics by searching Genius and scraping the song page HTML.
 * @param {string} artist - Artist name.
 * @param {string} track - Track title.
 * @returns {Promise<object|null>} Lyric record if found, otherwise null.
 */
async function fetchFromGenius(artist, track) {
  const apiKey = process.env.GENIUS_API_KEY;
  if (!apiKey || apiKey === 'your_genius_api_key_here') {
    console.warn('Genius API Key is not set or using placeholder.');
    return null;
  }

  try {
    const cleanedArtist = cleanSearchQuery(artist);
    const cleanedTrack = cleanSearchQuery(track);
    const query = `${cleanedArtist} ${cleanedTrack}`;

    // Search Genius API
    const searchUrl = `https://api.genius.com/search`;
    const searchResponse = await httpClient.get(searchUrl, {
      params: { q: query },
      headers: {
        'Authorization': `Bearer ${apiKey}`
      }
    });

    if (searchResponse.status !== 200 || !searchResponse.data.response) {
      return null;
    }

    const hits = searchResponse.data.response.hits;
    if (!hits || hits.length === 0) {
      return null;
    }

    // Select the first song type hit
    const songHit = hits.find(hit => hit.type === 'song');
    if (!songHit || !songHit.result || !songHit.result.url) {
      return null;
    }

    const songUrl = songHit.result.url;
    
    // Fetch Genius song webpage HTML
    const pageResponse = await httpClient.get(songUrl);
    if (pageResponse.status !== 200) {
      return null;
    }

    // Scrape/parse HTML using the cheerio parser
    const lyricsText = extractLyrics(pageResponse.data);
    if (lyricsText && lyricsText.length > 0) {
      return {
        plainLyrics: lyricsText,
        syncedLyrics: '', // Genius only has plain lyrics
        source: 'Genius'
      };
    }
  } catch (error) {
    console.error('Genius fetch error:', error.message);
  }
  return null;
}

/**
 * Coordinates lyric resolution using caching, LRCLIB, and Genius fallback.
 * @param {string} artist - Artist name.
 * @param {string} track - Track title.
 * @param {string} [album] - Album name.
 * @param {number} [duration] - Track duration in seconds.
 * @returns {Promise<object>} The resolved lyrics result.
 */
export async function getLyrics(artist, track, album = '', duration = 0) {
  if (!artist || !track) {
    throw new Error('Artist and track parameters are required.');
  }

  const cacheKey = `${artist.trim()} - ${track.trim()}`.toLowerCase();
  if (cache.has(cacheKey)) {
    console.log(`[Cache Hit] ${artist} - ${track}`);
    return cache.get(cacheKey);
  }

  console.log(`[Resolution Init] ${artist} - ${track}`);

  // Step 1: Query LRCLIB
  let result = await fetchFromLRCLIB(artist, track, album, duration);

  // Step 2: Fallback to Genius if LRCLIB returns empty
  if (!result) {
    console.log(`[Genius Fallback] ${artist} - ${track}`);
    result = await fetchFromGenius(artist, track);
  }

  // Step 3: Return result or final not found status
  if (result) {
    cache.set(cacheKey, result);
    return result;
  }

  const notFoundResult = {
    plainLyrics: '',
    syncedLyrics: '',
    source: 'None'
  };
  // Cache not found results as well to prevent spamming
  cache.set(cacheKey, notFoundResult);
  return notFoundResult;
}
