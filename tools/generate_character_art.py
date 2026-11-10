"""Produce Rin's game PNGs through the requested local AOM3/ControlNet API.

Run with the isolated studio Python (Pillow is installed there). Intermediate
images remain private. Outputs contain model/prompt/seed provenance metadata.
"""
import argparse, base64, io, json, os, time, urllib.request
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Game/Art/Illustrations'
PRIVATE=ROOT/'.private/art-studio/production/student'
API='http://127.0.0.1:7861'
IDENTITY='1girl, 17-year-old high school student, youthful face, chestnut brown hair in twin braids with soft bangs, warm brown eyes, gentle thoughtful expression, modest school uniform, cream collared shirt, muted forest green cardigan, navy knee-length pleated skirt, opaque dark tights'
STYLE='beautiful anime visual novel illustration, delicate clean lineart, restrained painterly shading, muted earthy colors, soft rural melancholy, consistent character design, natural anatomy, soft diffuse light'
NEGATIVE='young child, mature adult face, nude, nudity, underwear, revealing clothes, erotic, sexual, suggestive, low quality, bad anatomy, extra limbs, extra fingers, extra legs, extra feet, duplicate objects, watermark, text, signature, neon colors, oversaturated'
SEGMENTER=None

def request(route,payload=None,timeout=900):
    data=json.dumps(payload).encode() if payload is not None else None
    req=urllib.request.Request(API+route,data=data,headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=timeout) as response:return json.load(response)

def encoded(image):
    buffer=io.BytesIO();image.save(buffer,format='PNG');return base64.b64encode(buffer.getvalue()).decode()

def pose_image(name,width=512,height=768):
    image=Image.new('RGB',(512,768),'black'); draw=ImageDraw.Draw(image)
    # COCO/OpenPose order: nose, neck, shoulders/arms, hips/legs, eyes/ears.
    points=[(256,100),(256,170),(205,180),(180,280),(175,375),(305,180),(330,280),(335,375),(220,385),(215,525),(210,690),(292,385),(297,525),(302,690),(242,91),(270,91),(228,101),(284,101)]
    if name in ['seated','reading']:
        points[8:14]=[(210,340),(300,390),(300,625),(270,340),(365,410),(365,645)]
        points[3:5]=[(180,270),(240,320)];points[6:8]=[(330,270),(275,320)]
    if name=='cooking': points[3:5]=[(170,260),(240,290)];points[6:8]=[(325,255),(280,290)]
    if name=='resting':
        image=Image.new('RGB',(width,height),'black');draw=ImageDraw.Draw(image)
        points=[(105,150),(170,195),(180,145),(270,135),(340,180),(180,245),(290,280),(365,225),(405,190),(540,180),(690,195),(405,260),(545,270),(690,290),(97,140),(116,140),(90,155),(125,155)]
    pairs=[(1,2),(2,3),(3,4),(1,5),(5,6),(6,7),(1,8),(8,9),(9,10),(1,11),(11,12),(12,13),(1,0),(0,14),(14,16),(0,15),(15,17)]
    colors=['#ff0000','#ff5500','#ffaa00','#ffff00','#aaff00','#55ff00','#00ff00','#00ff55','#00ffaa','#00ffff','#00aaff','#0055ff','#0000ff','#5500ff','#aa00ff','#ff00ff','#ff00aa']
    for (a,b),color in zip(pairs,colors):draw.line([points[a],points[b]],fill=color,width=7)
    for point in points:draw.ellipse((point[0]-5,point[1]-5,point[0]+5,point[1]+5),fill='white')
    return image

def remove_background(image):
    """Local anime foreground segmentation preserves hair and cream clothing."""
    global SEGMENTER
    from rembg import new_session, remove
    os.environ['U2NET_HOME']=str(PRIVATE/'segmentation-models')
    if SEGMENTER is None: SEGMENTER=new_session('isnet-anime',providers=['CPUExecutionProvider'])
    return remove(image.convert('RGBA'),session=SEGMENTER)

def remove_flat_background(image):
    result=image.convert('RGBA');pixels=result.load();width,height=result.size
    queue=deque([(x,0) for x in range(width)]+[(x,height-1) for x in range(width)]+[(0,y) for y in range(height)]+[(width-1,y) for y in range(height)])
    seen=set()
    while queue:
        x,y=queue.popleft()
        if (x,y) in seen or not(0<=x<width and 0<=y<height):continue
        seen.add((x,y));r,g,b,a=pixels[x,y]
        if min(r,g,b)<218 or max(r,g,b)-min(r,g,b)>30:continue
        pixels[x,y]=(r,g,b,0)
        queue.extend(((x-1,y),(x+1,y),(x,y-1),(x,y+1)))
    return result

def generate(name,prompt,seed,width=512,height=768,pose=None,reference=None,cutout=True,inpaint=False):
    target=OUT/(name+'.png')
    if target.exists():return
    payload={'prompt':prompt+', '+STYLE,'negative_prompt':NEGATIVE,'seed':seed,'sampler_name':'DPM++ 2M','scheduler':'Karras','steps':24,'cfg_scale':6.5,'width':width,'height':height,'batch_size':1,'n_iter':1,'send_images':True,'save_images':False}
    if reference is not None:
        payload.update(init_images=[encoded(reference.convert('RGB'))],denoising_strength=0.32)
        if inpaint:
            mask=Image.new('L',reference.size,0);ImageDraw.Draw(mask).rectangle((0,240,reference.width,reference.height),fill=255)
            payload.update(mask=encoded(mask),denoising_strength=0.74,inpainting_fill=1,inpaint_full_res=False,mask_blur=12)
    if pose is not None:
        models=request('/controlnet/model_list').get('model_list',[])
        model=next((m for m in models if 'openpose' in m.lower()),None)
        if not model:raise RuntimeError('The requested OpenPose model is not loaded')
        payload['alwayson_scripts']={'ControlNet':{'args':[{'enabled':True,'module':'none','model':model,'weight':0.85,'image':encoded(pose_image(pose,width,height)),'resize_mode':'Just Resize','low_vram':True,'pixel_perfect':False,'control_mode':'Balanced','guidance_start':0,'guidance_end':0.85}]}}
    print('Generating',name,flush=True)
    response=request('/sdapi/v1/img2img' if reference is not None else '/sdapi/v1/txt2img',payload)
    raw=base64.b64decode(response['images'][0]);original=Image.open(io.BytesIO(raw));original.save(PRIVATE/(name+'-original.png'))
    result=remove_background(original) if cutout else original
    result.save(target)
    metadata={'file':target.name,'provider':'Local AUTOMATIC1111','checkpoint':'AOM3A1B_orangemixs.safetensors','checkpoint_sha256':'5493a0ec491f5961dbdc1c861404088a6ae9bd4007f6a3a7c5dee8789cdc1361','prompt':payload['prompt'],'negative_prompt':NEGATIVE,'seed':seed,'steps':24,'cfg_scale':6.5,'pose':pose,'reference':'Rin base portrait' if reference is not None else None,'generation_info':json.loads(response.get('info','{}'))}
    (OUT/(name+'.json')).write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

if __name__=='__main__':
    import runpy
    runpy.run_path(str(Path(__file__).with_name('regenerate_student_art.py')),run_name='__main__')
