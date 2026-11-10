"""Local, masked anatomy corrections. Face pixels must remain unchanged."""
import argparse,base64,hashlib,importlib.util,io,json,shutil
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
spec=importlib.util.spec_from_file_location('art',str(Path(__file__).with_name('generate_character_art.py')))
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)
QA=art.PRIVATE/'anatomy-review'
REGIONS={
 'rin_seated':((180,265,335,365),'two small natural hands resting gently together on the lap, left hand resting on top of right hand, relaxed distinct fingers, believable wrists, modest school uniform sleeves'),
}

def face_hash(image):
    return hashlib.sha256(image.convert('RGB').crop((150,0,365,200)).tobytes()).hexdigest()

def stage(start_index=0):
    QA.mkdir(parents=True,exist_ok=True)
    for name,(region,prompt) in REGIONS.items():
        original=Image.open(art.PRIVATE/(name+'-original.png')).convert('RGB')
        mask=Image.new('L',original.size,0);ImageDraw.Draw(mask).rectangle(region,fill=255)
        for candidate in range(start_index,start_index+2):
            output=QA/(name+'-'+str(candidate)+'.png')
            if output.exists():continue
            payload={'init_images':[art.encoded(original)],'mask':art.encoded(mask),'prompt':prompt+', '+art.STYLE,'negative_prompt':art.NEGATIVE+', extra hands, extra fingers, fused fingers, missing fingers, malformed hands, oversized hands, dislocated wrists, phone, mobile phone, duplicate books','seed':171100+candidate,'sampler_name':'DPM++ 2M','scheduler':'Karras','steps':32,'cfg_scale':6.0,'width':512,'height':512,'batch_size':1,'n_iter':1,'denoising_strength':0.65,'inpainting_fill':1,'inpaint_full_res':True,'inpaint_full_res_padding':80,'mask_blur':5,'save_images':False}
            print('Repairing',name,'candidate',candidate,flush=True)
            response=art.request('/sdapi/v1/img2img',payload)
            image=Image.open(io.BytesIO(base64.b64decode(response['images'][0]))).convert('RGB')
            assert face_hash(image)==face_hash(original),'Inpainting changed approved face pixels'
            image.save(output)
            metadata={'region':region,'seed':payload['seed'],'prompt':payload['prompt'],'negative_prompt':payload['negative_prompt'],'face_pixels_unchanged':True,'face_sha256':face_hash(original),'generation_info':json.loads(response.get('info','{}'))}
            output.with_suffix('.json').write_text(json.dumps(metadata,indent=2)+'\n')
    contact=Image.new('RGB',(1200,960),'#d8d4c8');draw=ImageDraw.Draw(contact)
    for row,(name,(region,prompt)) in enumerate(REGIONS.items()):
        for candidate in range(start_index,start_index+2):
            image=Image.open(QA/(name+'-'+str(candidate)+'.png'))
            region=tuple(region);crop=image.crop(region);crop.thumbnail((550,270))
            crop=crop.resize((min(550,crop.width*2),min(270,crop.height*2)))
            x=(candidate-start_index)*600+25;y=row*320+35
            contact.paste(crop,(x,y));draw.text((x,y-22),name+' candidate '+str(candidate),fill='black')
    contact.save(QA/'candidate-hands.png')
    print('REVIEW',QA/'candidate-hands.png',flush=True)

def apply(choices):
    for name,candidate in choices.items():
        if name not in REGIONS: raise ValueError('This action pose was withdrawn from the simplified home design')
        selected=QA/(name+'-'+str(candidate)+'.png')
        image=Image.open(selected)
        art.remove_background(image).save(art.OUT/(name+'.png'))
        shutil.copy2(selected,art.PRIVATE/(name+'-original.png'))
        metadata=json.loads((art.OUT/(name+'.json')).read_text())
        metadata['anatomy_correction']=json.loads(selected.with_suffix('.json').read_text())
        (art.OUT/(name+'.json')).write_text(json.dumps(metadata,indent=2)+'\n')
        print('Applied reviewed correction',name,candidate,flush=True)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--apply',type=str);args=parser.parse_args()
    if args.apply:apply(json.loads(args.apply))
    else:stage()
if __name__=='__main__':main()
