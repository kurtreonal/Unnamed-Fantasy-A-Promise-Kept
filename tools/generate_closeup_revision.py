"""Generate review-only colored Rin close-ups using the user-selected local AOM3.

Never overwrites a released image. SafeTensor embedding weights and candidate
images stay private; selected images are promoted only after visual review.
"""
import argparse, base64, hashlib, importlib.util, io, json, shutil, urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=ROOT/'.private/art-studio/production/revision2'
STUDIO=ROOT/'.private/art-studio/stable-diffusion-webui'
SPEC=importlib.util.spec_from_file_location('art',str(Path(__file__).with_name('generate_character_art.py')))
art=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(art)
EMBEDDING_URL='https://huggingface.co/gsdf/Counterfeit-V3.0/resolve/main/embedding/EasyNegativeV2.safetensors'
EMBEDDING_SHA='339cc9210f70ef842b716588373d95b52351d7e6d111b858e133e3b1e3bd8088'
PROMPT=('1girl, 17-year-old high school student, youthful face, chestnut brown hair in two long braids, '
        'warm brown eyes, gentle thoughtful smile, looking at viewer, (waist-up portrait:1.35), '
        'head and shoulders fully inside frame, natural proportional shoulders and torso, '
        'standard modest school uniform, cream collared shirt, forest green buttoned cardigan fully on both shoulders, '
        'relaxed arms extending below frame, hands outside frame, centered, simple white background, '
        'soft diffuse window light, muted earthy colors, delicate clean anime visual novel illustration')
NEGATIVE=('(EasyNegativeV2:0.75), worst quality, low quality, low resolution, blurry, jpeg artifacts, '
          'bad anatomy, malformed body, unnatural body proportions, long neck, tiny head, huge head, '
          'uneven shoulders, extra arms, missing arms, disconnected limbs, duplicate person, duplicate face, '
          'deformed face, crossed eyes, asymmetrical eyes, extra fingers, fused fingers, missing fingers, '
          'cropped head, cropped hair, cut off braids, full body, distant character, '
          'off shoulder, bare shoulders, loose collar, open cardigan, exposed midriff, revealing clothes, '
          'nudity, underwear, erotic, sexual, suggestive, mature adult face, young child, '
          'monochrome, black and white, sketch, harsh outlines, neon colors, oversaturated, '
          'text, watermark, signature, logo, room background, furniture')

def prepare_embedding():
    target=STUDIO/'embeddings/EasyNegativeV2.safetensors'
    target.parent.mkdir(parents=True,exist_ok=True)
    if not target.exists():
        request=urllib.request.Request(EMBEDDING_URL,headers={'User-Agent':'PromiseKeptArtProduction/1.0'})
        with urllib.request.urlopen(request,timeout=90) as response: content=response.read()
        if hashlib.sha256(content).hexdigest()!=EMBEDDING_SHA:raise RuntimeError('Original author embedding checksum mismatch')
        target.write_bytes(content)
    if hashlib.sha256(target.read_bytes()).hexdigest()!=EMBEDDING_SHA:raise RuntimeError('Installed embedding checksum mismatch')
    # Reading SafeTensors validates the tensor-only file rather than executing pickle.
    from safetensors import safe_open
    with safe_open(str(target),framework='pt',device='cpu') as weights:
        if not list(weights.keys()):raise RuntimeError('Embedding has no tensors')
    art.request('/sdapi/v1/refresh-embeddings',{})
    loaded=art.request('/sdapi/v1/embeddings').get('loaded',{})
    if 'EasyNegativeV2' not in loaded:raise RuntimeError('AUTOMATIC1111 did not load EasyNegativeV2')
    return {'source':EMBEDDING_URL,'author':'gsdf','sha256':EMBEDDING_SHA,
            'license':'CreativeML OpenRAIL-M (Counterfeit-V3.0 repository)',
            'model_card':'https://huggingface.co/gsdf/Counterfeit-V3.0',
            'note':'The author notes no guaranteed superiority over the earlier embedding. Visual anatomy review remains necessary.'}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--candidate',type=int,default=0);parser.add_argument('--seated',action='store_true')
    parser.add_argument('--seated-source',type=Path,default=ROOT/'Game/Art/Illustrations/rin_seated.png')
    parser.add_argument('--reuse-seated-candidate',type=Path)
    args=parser.parse_args()
    PRIVATE.mkdir(parents=True,exist_ok=True)
    embedding=json.loads((PRIVATE/'rin_seated_v2.json').read_text())['negative_embedding'] if args.reuse_seated_candidate else prepare_embedding()
    if args.seated:
        seated(embedding,args.seated_source,args.reuse_seated_candidate)
        return
    source=ROOT/'Game/Art/Illustrations/rin_standing.png'
    original=Image.open(source).convert('RGBA')
    # Waist-up reference enlargement: no new hands or feet are requested.
    cut=original.crop((100,5,415,365))
    reference=Image.new('RGB',cut.size,'white');reference.paste(cut,mask=cut.getchannel('A'))
    reference=reference.resize((512,640),Image.Resampling.LANCZOS)
    reference.save(PRIVATE/'conversation-reference.png')
    seed=171100+args.candidate
    payload={'init_images':[art.encoded(reference)],'prompt':PROMPT,'negative_prompt':NEGATIVE,
             'seed':seed,'sampler_name':'DPM++ 2M','scheduler':'Karras','steps':28,'cfg_scale':6.0,
             'width':512,'height':640,'denoising_strength':0.30 if args.candidate==0 else 0.38,
             'batch_size':1,'n_iter':1,'send_images':True,'save_images':False}
    print('Generating waist-up candidate',args.candidate,flush=True)
    response=art.request('/sdapi/v1/img2img',payload)
    generated=Image.open(io.BytesIO(base64.b64decode(response['images'][0])))
    stem='rin_conversation_v2' if args.candidate==0 else 'rin_conversation_v2_candidate'+str(args.candidate)
    generated.save(PRIVATE/(stem+'-original.png'))
    art.PRIVATE=ROOT/'.private/art-studio/production/student'
    art.remove_background(generated).save(PRIVATE/(stem+'.png'))
    metadata={'file':stem+'.png','provider':'Local AUTOMATIC1111','checkpoint':'AOM3A1B_orangemixs.safetensors',
              'checkpoint_sha256':'5493a0ec491f5961dbdc1c861404088a6ae9bd4007f6a3a7c5dee8789cdc1361',
              'prompt':PROMPT,'negative_prompt':NEGATIVE,'negative_embedding':embedding,'seed':seed,
              'steps':28,'cfg_scale':6.0,'denoising_strength':payload['denoising_strength'],
              'reference':'rin_standing.png, waist-up framing, white matte for img2img',
              'reference_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
              'generation_info':json.loads(response.get('info','{}')),'review_status':'candidate, not approved'}
    (PRIVATE/(stem+'.json')).write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf8')
    (PRIVATE/'negative-prompt-library.json').write_text(json.dumps({'embedding':embedding,'negative_prompt':NEGATIVE,
        'categories':['quality','body proportions','face consistency','hands and limbs','framing','modest uniform','colored restrained style'],
        'review_required':True},indent=2)+'\n',encoding='utf8')
    print('Candidate saved:',PRIVATE/(stem+'.png'),flush=True)

def seated(embedding,source,reuse_candidate=None):
    # Start from the approved RGBA including its reviewed hand correction.
    # Never use the earlier pre-correction raw generation as the base.
    approved=Image.open(source).convert('RGBA')
    original=Image.new('RGB',approved.size,'white');original.paste(approved,mask=approved.getchannel('A'))
    mask=Image.new('L',approved.size,0);draw=ImageDraw.Draw(mask)
    draw.rectangle((132,392,174,446),fill=255)
    draw.rectangle((343,392,383,449),fill=255)
    mask.save(PRIVATE/'seated-chair-removal-mask.png')
    prompt='plain white empty background behind a seated schoolgirl, seamless white background, no furniture, clean illustration'
    payload={'init_images':[art.encoded(original)],'mask':art.encoded(mask),'prompt':prompt,
        'negative_prompt':NEGATIVE+', chair, stool, furniture, wooden bar, bench, extra hands, extra feet',
        'seed':171125,'sampler_name':'DPM++ 2M','scheduler':'Karras','steps':28,'cfg_scale':6.0,
        'width':512,'height':512,'batch_size':1,'n_iter':1,'denoising_strength':0.85,
        'inpainting_fill':2,'inpaint_full_res':True,'inpaint_full_res_padding':48,'mask_blur':3,
        'send_images':True,'save_images':False}
    generation_info={}
    if reuse_candidate:
        patch=Image.open(reuse_candidate).convert('RGBA')
        generation_info=json.loads(reuse_candidate.with_suffix('.json').read_text()).get('generation_info',{})
    else:
        print('Removing chair ends with local masked inpainting',flush=True)
        response=art.request('/sdapi/v1/img2img',payload)
        result=Image.open(io.BytesIO(base64.b64decode(response['images'][0]))).convert('RGB')
        result.save(PRIVATE/'rin_seated_v3-original.png')
        art.PRIVATE=ROOT/'.private/art-studio/production/student'
        patch=art.remove_background(result)
        generation_info=json.loads(response.get('info','{}'))
    if patch.size!=approved.size:raise RuntimeError('Chair patch dimensions differ from the approved source')
    # Rectangles bound the permitted edit, but the right rectangle overlaps the
    # original leg silhouette. Replace only darker warm wood pixels within it;
    # retain brighter skin and cool uniform pixels instead of cutting a notch.
    composite_mask=Image.new('L',approved.size,0)
    for y in range(approved.height):
        for x in range(approved.width):
            r,g,b,a=approved.getpixel((x,y))
            if mask.getpixel((x,y)) and (x<=174 or (a and r<195 and r>=g+2 and g>=b)):
                composite_mask.putpixel((x,y),255)
    composite_mask.save(PRIVATE/'seated-chair-composite-mask.png')
    output=Image.composite(patch,approved,composite_mask)
    # Compare all four channels, including invisible RGB, outside the exact masks.
    def outside_hash(image):
        values=bytearray()
        for pixel,coverage in zip(image.getdata(),composite_mask.getdata()):
            if coverage==0:values.extend(pixel)
        return hashlib.sha256(values).hexdigest()
    original_outside=outside_hash(approved)
    if outside_hash(output)!=original_outside:raise RuntimeError('Correction altered approved pixels outside the chair masks')
    regions={'face':(150,0,365,200),'hands':(180,265,335,365)}
    hashes={}
    for name,region in regions.items():
        digest=hashlib.sha256(approved.crop(region).tobytes()).hexdigest()
        if hashlib.sha256(output.crop(region).tobytes()).hexdigest()!=digest:raise RuntimeError(name+' pixels changed')
        hashes[name+'_sha256']=digest
    output.save(PRIVATE/'rin_seated_v3.png')
    metadata=json.loads(source.with_suffix('.json').read_text())
    metadata.update(file='rin_seated_v3.png',review_status='candidate, not approved',negative_embedding=embedding)
    metadata['chair_correction']={'provider':'Local AUTOMATIC1111 + exact-mask RGBA compositing',
        'prompt':prompt,'negative_prompt':payload['negative_prompt'],'negative_embedding':embedding,
        'seed':171125,'steps':28,'denoising_strength':0.85,
        'reference':'Previously approved corrected RGBA seated image, including reviewed hands',
        'reference_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'mask_rectangles_inclusive':[[132,392,174,446],[343,392,383,449]],
        'composite_selection':'Left chair-end rectangle; only darker warm wood pixels in right rectangle to retain the leg silhouette',
        'outside_mask_pixels_unchanged':True,'outside_mask_rgba_sha256':original_outside,
        'face_pixels_unchanged':True,'hands_pixels_unchanged':True,**hashes,
        'generation_info':generation_info}
    (PRIVATE/'rin_seated_v3.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf8')
    print('Seated v3 saved; all RGBA pixels outside chair masks, face and hands are byte-identical',flush=True)

if __name__=='__main__':main()
