"""Copy only approved reused backgrounds and maintain export provenance."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    packs=(ROOT/'Game/Art/Packs').resolve()
    removed=0
    for entry in packs.rglob('*'):
        if entry.is_file() and (entry.name.startswith('._') or '__MACOSX' in entry.parts):
            if packs not in entry.resolve().parents: raise RuntimeError('Cleanup escaped the asset directory')
            entry.unlink();removed+=1
    print('Removed',removed,'archive metadata files from the acquired asset directory.')
    out=ROOT/'Game/Art/Backgrounds';out.mkdir(parents=True,exist_ok=True)
    for folder,names in [('Noraneko_Background_Pack_1',['Sitting_Room.png','Sitting_Room_Dark.png']),('Noraneko_Backgrounds_Pack_2',['Bedroom_Day.png','Bedroom_Night.png','Livingroom_Day.png','Livingroom_Night.png'])]:
        source=ROOT/'Assets'/folder/folder
        for name in names: shutil.copy2(source/name,out/name)
        shutil.copy2(source/'ReadMe.txt',out/(folder+'-LICENSE.txt'))
    manifest=json.loads((ROOT/'Game/Art/Packs/manifest.json').read_text())
    kenney_archive=ROOT/'.godot/redesign-downloads/kenney.zip'
    if kenney_archive.exists() and not any(entry['id']=='kenney' for entry in manifest): manifest.append(dict(id='kenney',source='https://opengameart.org/content/roguelikerpg-pack-1700-tiles',license='CC0-1.0',sha256=hashlib.file_digest(kenney_archive.open('rb'),'sha256').hexdigest()))
    manifest += [dict(id='noraneko-backgrounds',source='https://noranekogames.itch.io/',license='Noraneko Games asset terms; attribution required',modifications='Selected existing backgrounds copied without pixel edits',redistribution='Only as part of the game with included terms and credit'),dict(id='kenney-ui-borders',source='https://kenney.nl/assets/fantasy-ui-borders',license='CC0-1.0',modifications='Original assets preserved; UI styling uses the same restrained border language')]
    manifest += [dict(id='rin-asami-generated-art',source='https://huggingface.co/WarriorMama777/OrangeMixs',model='AOM3A1B',license='CreativeML OpenRAIL-M; see the original model card and checkpoint variant terms',character_direction='Rin/Asami and protagonist are 17-year-old high-school classmates; non-explicit peer romance',modifications='Local AUTOMATIC1111 generation, ControlNet pose guidance, outfit inpainting, masked anatomy corrections, and transparent foreground extraction. Adjacent JSON files retain prompts and seeds.'),dict(id='app-icon',source='Game/Art/app_icon.svg',license='Original artwork for this project',modifications='Native SVG rosemary and open-book icon')]
    (ROOT/'Game/Art/ASSET_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    presets=ROOT/'export_presets.cfg'
    text=presets.read_text()
    text=text.replace('include_filter="*.dtl,*.dch"','include_filter="Game/Data/*.json,Game/Art/*.json,Game/Art/**/*.json"')
    text=text.replace('include_filter="Game/Data/*.json,Game/Art/*.json,Game/Art/**/*.json"','include_filter="Game/Data/*.json,Game/Art/*.json,Game/Art/**/*.json,Game/Timelines/*.dtl"')
    text=text.replace('build/*,.private/*,.github/*,tools/*,tests/*"','build/*,.private/*,.github/*,tools/*,tests/*,docs/*,Characters/*,Sprite Assest/*,Scenes/*,Timelines/*,Assets/*,UI_Gamepad/*,Fonts/Noto_Serif_JP/*"')
    text=text.replace('unnamed-fantasy-v0.1.0.apk','unnamed-fantasy-v0.2.0.apk').replace('version/code=1','version/code=2').replace('version/name="0.1.0"','version/name="0.2.0"')
    presets.write_text(text)
    print('Curated seven background illustrations; old AI scenes excluded from redesigned exports.')
if __name__=='__main__':main()
