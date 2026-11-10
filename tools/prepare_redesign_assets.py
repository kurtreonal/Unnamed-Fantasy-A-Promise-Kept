"""Acquire original CC0 packs; never scrape mirrors or bundle AI checkpoints."""
import hashlib, io, json, re, urllib.request, urllib.parse, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.godot' / 'redesign-downloads'
OUT = ROOT / 'Game' / 'Art' / 'Packs'

def get(url, data=None):
    req = urllib.request.Request(url, data=data, headers={'User-Agent':'PromiseKeptAssetSetup/1.0'})
    with urllib.request.urlopen(req, timeout=120) as response:
        return response.read()

def itch_download(page, wanted):
    html = get(page).decode()
    game = re.search(r'data-game_id="(\d+)"', html)
    if not game:
        game = re.search(r'"game_id":(\d+)', html)
    if not game:
        raise RuntimeError('Missing itch game id: ' + page)
    download = json.loads(get(page + '/download_url', urllib.parse.urlencode({'reward_id':'','csrf_token':re.search(r'name="csrf_token" value="([^"]+)"', html).group(1) if 'name="csrf_token"' in html else ''}).encode()))
    download_page = get(download['url']).decode()
    candidates = re.findall(r'data-upload_id="(\d+)"[\s\S]{0,1500}?<strong[^>]*>([^<]+)', download_page)
    if not candidates:
        candidates = re.findall(r'data-upload_id="(\d+)"[\s\S]{0,1500}?class="name"[^>]*>([^<]+)', download_page)
    print('Candidates', page, candidates, flush=True)
    for upload, name in candidates:
        if wanted.lower() in name.lower():
            link = json.loads(get(page+'/file/'+upload, b''))['url']
            return get(link), name
    (CACHE / (game.group(1)+'.html')).write_text(download_page, encoding='utf8')
    raise RuntimeError('No matching downloadable file: '+wanted)

def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    # Artist's own alternate host is reliable when itch rate limits the client.
    forest_archive=CACHE/'forest.zip'
    if not forest_archive.exists():
        try: forest_archive.write_bytes(get('https://opengameart.org/sites/default/files/tiny-rpg-forest-files.zip'))
        except Exception as error: print('Artist alternate host:',error,flush=True)
    try:
        page='https://opengameart.org/content/roguelikerpg-pack-1700-tiles'
        html=get(page).decode()
        links=re.findall(r'href=[\"\x27]([^\"\x27]+\.zip)[\"\x27]',html)
        if links:
            archive=CACHE/'kenney.zip'
            if not archive.exists(): archive.write_bytes(get(links[0]))
            dest=OUT/'kenney'; dest.mkdir(exist_ok=True)
            with zipfile.ZipFile(archive) as z: z.extractall(dest)
            print('Installed Kenney RPG pack',flush=True)
    except Exception as error: print('Kenney download:',error,flush=True)
    packs = [
        ('dungeon', 'https://0x72.itch.io/dungeontileset-ii', '1.7'),
        ('forest', 'https://ansimuz.itch.io/tiny-rpg-forest', 'forest'),
    ]
    manifest = []
    if (CACHE/'kenney.zip').exists(): manifest.append({'id':'kenney','source':'https://opengameart.org/content/roguelikerpg-pack-1700-tiles','license':'CC0-1.0','sha256':hashlib.sha256((CACHE/'kenney.zip').read_bytes()).hexdigest()})
    for slug, page, wanted in packs:
        try:
            archive = CACHE / (slug+'.zip')
            if archive.exists():
                payload, name = archive.read_bytes(), archive.name
            else:
                payload, name = itch_download(page, wanted)
                archive.write_bytes(payload)
            dest = OUT / slug
            dest.mkdir(exist_ok=True)
            with zipfile.ZipFile(io.BytesIO(payload)) as z:
                for entry in z.infolist():
                    if '__MACOSX' in entry.filename or Path(entry.filename).name.startswith('._'): continue
                    if entry.filename.lower().endswith(('.png','.txt','.md','.json')):
                        target = (dest / entry.filename).resolve()
                        if dest.resolve() not in target.parents:
                            raise ValueError('Unsafe archive member')
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(z.read(entry))
            manifest.append({'id':slug,'source':page,'license':'CC0-1.0','archive':name,'sha256':hashlib.sha256(payload).hexdigest()})
            print('Installed', slug, flush=True)
        except Exception as error:
            print('DOWNLOAD FAILED', slug, str(error), flush=True)
    (OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf8')

if __name__ == '__main__': main()
