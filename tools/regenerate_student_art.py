"""User-directed high-school redesign, generated only through local AOM3."""
import argparse,importlib.util,shutil
from pathlib import Path
from PIL import Image
spec=importlib.util.spec_from_file_location('production',str(Path(__file__).with_name('generate_character_art.py')))
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
art.PRIVATE=art.ROOT/'.private/art-studio/production/student'

def archive(name):
    dest=art.ROOT/'.private/art-studio/production/superseded-design';dest.mkdir(parents=True,exist_ok=True)
    for suffix in ['.png','.json']:
        source=art.OUT/(name+suffix)
        if source.exists():shutil.move(str(source),str(dest/(name+suffix)))

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--base-only',action='store_true');parser.add_argument('--prepare',action='store_true');args=parser.parse_args()
    art.OUT.mkdir(parents=True,exist_ok=True);art.PRIVATE.mkdir(parents=True,exist_ok=True)
    # Reuse the already-verified local segmentation weights.
    cache=art.ROOT/'.private/art-studio/production/segmentation-models'
    target=art.PRIVATE/'segmentation-models';target.mkdir(exist_ok=True)
    if not (target/'isnet-anime.onnx').exists():shutil.copy2(cache/'isnet-anime.onnx',target/'isnet-anime.onnx')
    if args.prepare:
        for file in list(art.OUT.glob('*.png')):
            if file.stem.startswith(('portrait_','rin_')) or file.stem in ['event_atlas','event_greenhouse','event_lanterns']:archive(file.stem)
    art.generate('portrait_calm',art.IDENTITY+', (upper body portrait:1.4), looking at viewer, calm expression, centered, plain white background, simple clean background',170917,width=512,height=640)
    if args.base_only:return
    reference=Image.open(art.PRIVATE/'portrait_calm-original.png')
    expressions={'happy':'gentle happy smile','sad':'sad downcast eyes','worried':'worried expression','surprised':'subtly surprised','thoughtful':'thoughtful gaze','touched':'moved gentle smile','determined':'quiet determination','tired':'tired but comfortable','laughing':'warm laughing smile'}
    for index,(name,expression) in enumerate(expressions.items()):art.generate('portrait_'+name,art.IDENTITY+', upper body portrait, '+expression+', white background',170917+index,width=512,height=640,reference=reference)
    blue=art.IDENTITY.replace('muted forest green cardigan','(muted blue school cardigan:1.5), blue fabric')
    art.generate('portrait_blue_calm',blue+', upper body portrait, calm expression, white background',170917,width=512,height=640,reference=reference,inpaint=True)
    blue_reference=Image.open(art.PRIVATE/'portrait_blue_calm-original.png')
    for index,(name,expression) in enumerate(expressions.items()):art.generate('portrait_blue_'+name,blue+', upper body portrait, '+expression+', white background',170917+index,width=512,height=640,reference=blue_reference)
    poses={'seated':'(sitting in a wooden chair:1.6), knees bent, chair clearly visible, hands resting on lap','standing':'standing naturally, relaxed hands at sides'}
    for pose,prompt in poses.items():
        art.generate('rin_'+pose,art.IDENTITY+', '+prompt+', white background',170917,width=768 if pose=='resting' else 512,height=448 if pose=='resting' else 768,pose=pose)
    for index,(name,prompt) in enumerate([
        ('event_atlas','a close-up of an open hand-drawn travel atlas on a weathered wooden cottage table, two cups of tea, a pressed rosemary sprig, soft window light, empty chairs, no people, no characters'),
        ('event_greenhouse','the interior of a small weathered village greenhouse, rosemary seedlings and a school notebook on a wooden workbench, gentle spring sunlight, no people, no characters'),
        ('event_lanterns','a quiet rural river at dusk with floating paper lanterns, a winding path on the near bank, distant warm village lights, peaceful hopeful atmosphere, no people, no characters'),
    ]):art.generate(name,prompt,170950+index,width=768,height=448,cutout=False)
    print('Finished user-directed high-school character redesign',flush=True)

if __name__=='__main__':main()
