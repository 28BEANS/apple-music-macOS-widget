import re
from bs4 import BeautifulSoup

def extract_lyrics(html: str) -> str:
    """
    Scrapes and extracts plain text lyrics from Genius song page HTML.
    """
    soup = BeautifulSoup(html, 'html.parser')
    lyrics = ""

    # 1. Modern Genius layout: div[data-lyrics-container="true"]
    containers = soup.find_all('div', attrs={"data-lyrics-container": "true"})
    if containers:
        for container in containers:
            # Replace <br> with newlines to preserve lines
            for br in container.find_all('br'):
                br.replace_with('\n')
            # Extract plain text
            lyrics += container.get_text() + '\n'

    # 2. Legacy Genius layout: div.lyrics
    if not lyrics.strip():
        legacy = soup.find('div', class_='lyrics')
        if legacy:
            for br in legacy.find_all('br'):
                br.replace_with('\n')
            lyrics = legacy.get_text()

    # 3. Alternate class contains "Lyrics__Container"
    if not lyrics.strip():
        for container in soup.find_all(class_=re.compile(r'Lyrics__Container')):
            for br in container.find_all('br'):
                br.replace_with('\n')
            lyrics += container.get_text() + '\n'

    return clean_lyrics(lyrics)

def clean_lyrics(lyrics: str) -> str:
    """
    Trims, cleans up metadata lines, and formats newlines in the raw lyrics.
    """
    if not lyrics:
        return ""
    
    lines = lyrics.split('\n')
    cleaned_lines = []
    
    for line in lines:
        line_stripped = line.strip()
        # Filter metadata noise
        if re.match(r'^\d+\s+Contributor(s)?$', line_stripped, re.IGNORECASE):
            continue
        if re.match(r'^You\s+may\s+also\s+like$', line_stripped, re.IGNORECASE):
            continue
        cleaned_lines.append(line_stripped)
        
    cleaned_text = '\n'.join(cleaned_lines)
    # Collapse multiple consecutive newlines down to max 2
    cleaned_text = re.sub(r'\n{3,}', '\n\n', cleaned_text)
    return cleaned_text.strip()
