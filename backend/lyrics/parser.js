import * as cheerio from 'cheerio';

/**
 * Extracts plain text lyrics from a Genius song page HTML.
 * @param {string} html - The HTML response from Genius.com.
 * @returns {string} The cleaned plain text lyrics.
 */
export function extractLyrics(html) {
  const $ = cheerio.load(html);
  let lyrics = '';

  // 1. Modern Genius layout: elements with data-lyrics-container="true"
  const containers = $('div[data-lyrics-container="true"]');
  if (containers.length > 0) {
    containers.each((_, container) => {
      const elem = $(container);
      
      // Replace <br> tags with newlines before extracting text
      elem.find('br').replaceWith('\n');
      
      // Inject spacing for paragraphs or nested divs to preserve line breaks
      elem.find('p, div').prepend('\n').append('\n');
      
      lyrics += elem.text() + '\n';
    });
  }

  // 2. Legacy Genius layout: element with class "lyrics"
  if (!lyrics.trim()) {
    const legacyContainer = $('.lyrics');
    if (legacyContainer.length > 0) {
      legacyContainer.find('br').replaceWith('\n');
      lyrics = legacyContainer.text();
    }
  }

  // 3. Alternate/fallback Genius layout: classes prefixed with Lyrics__Container
  if (!lyrics.trim()) {
    $('[class*="Lyrics__Container"]').each((_, container) => {
      const elem = $(container);
      elem.find('br').replaceWith('\n');
      lyrics += elem.text() + '\n';
    });
  }

  return cleanLyrics(lyrics);
}

/**
 * Cleans extracted lyric text (removing multiple newlines, trimming lines).
 * @param {string} lyrics - Raw lyric text.
 * @returns {string} Cleaned lyric text.
 */
function cleanLyrics(lyrics) {
  if (!lyrics) return '';
  return lyrics
    .split('\n')
    .map(line => line.trim())
    // Remove lyrics page headers like "Lyrics", "About", "1 Contributor"
    .filter(line => !/^\d+\s+Contributor(s)?$/i.test(line))
    .filter(line => !/^You\s+may\s+also\s+like$/i.test(line))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n') // Collapse excessive newlines down to max 2
    .trim();
}
