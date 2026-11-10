"""Validate release art presence, transparency, age direction, and provenance."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Game/Art/Illustrations'
def main():
    expressions=['calm','happy','sad','worried','surprised','thoughtful','touched','determined','tired','laughing']
    names=['portrait_'+prefix+expression for prefix in ['', 'blue_'] for expression in expressions]
    names+=['rin_'+pose for pose in ['seated','standing','conversation']]
    names+=['event_'+scene for scene in ['promise','atlas','greenhouse','lanterns']]
    names+=['npc_'+npc for npc in ['healer','merchant','archivist']]
    entries=[]
    for name in names:
        file=ART/(name+'.png');metadata=ART/(name+'.json')
        assert file.is_file() and metadata.is_file(),f'Missing final art: {name}'
        with Image.open(file) as image:
            image.verify()
        data=json.loads(metadata.read_text(encoding='utf8'))
        assert data['provider']=='Local AUTOMATIC1111'
        assert data['checkpoint_sha256']=='5493a0ec491f5961dbdc1c861404088a6ae9bd4007f6a3a7c5dee8789cdc1361'
        if name.startswith(('portrait_','rin_')):
            assert '17-year-old high school student' in data['prompt'],f'Superseded character direction in {name}'
            assert 'adult woman' not in data['prompt'] and '22 years old' not in data['prompt']
            with Image.open(file) as image:
                assert image.mode=='RGBA' and image.getchannel('A').getextrema()[0]==0,f'{name} needs actual transparency'
        entries.append({'file':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
    (ART/'release-art-manifest.json').write_text(json.dumps(entries,indent=2)+'\n')
    assert not (ART/'rin_cooking.png').exists(),'The withdrawn cooking pose must not ship'
    print('PASS:',len(names),'local AOM3 assets, transparent character PNGs, 17-year-old design, and generation provenance')
if __name__=='__main__':main()
