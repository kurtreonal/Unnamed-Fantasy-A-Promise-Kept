"""Snapshot existing player saves and soundtrack hashes before isolated verification."""
import hashlib, json, os, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BACKUP=ROOT/'.godot/redesign-backup'
def main():
    BACKUP.mkdir(parents=True,exist_ok=True)
    music={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.file_digest(p.open('rb'),'sha256').hexdigest() for p in (ROOT/'BGM').glob('*.mp3')}
    manifest=BACKUP/'music-sha256.json'
    if manifest.exists():
        assert json.loads(manifest.read_text())==music,'Existing soundtrack changed'
    else: manifest.write_text(json.dumps(music,indent=2))
    public_manifest=ROOT/'Game/Art/MUSIC_MANIFEST.json'
    public_manifest.parent.mkdir(parents=True,exist_ok=True)
    public_manifest.write_text(json.dumps(music,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    saves=Path(os.environ['APPDATA'])/'Godot/app_userdata/Living Together with my Childhood Friend- Fantasy Monochrome'
    for p in saves.rglob('*.json'):
        target=BACKUP/'saves'/p.relative_to(saves)
        if not target.exists(): target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,target)
    print('Verified',len(music),'original music files; legacy save backup preserved.')
if __name__=='__main__':main()
