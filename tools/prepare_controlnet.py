"""Install the requested pose extension and official SD1.5 OpenPose weights."""
import hashlib, json, os, subprocess, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WEBUI=ROOT/'.private/art-studio/stable-diffusion-webui'
def main():
    extension=WEBUI/'extensions/sd-webui-controlnet'
    env=os.environ.copy(); env['GIT_TERMINAL_PROMPT']='0';env['GCM_INTERACTIVE']='Never'
    if not extension.exists(): subprocess.run(['git','clone','https://github.com/Mikubill/sd-webui-controlnet.git',str(extension)],check=True,env=env)
    models=extension/'models';models.mkdir(exist_ok=True)
    source='https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/'
    for name in ['control_v11p_sd15_openpose.pth','control_v11p_sd15_openpose.yaml']:
        path=models/name
        if not path.exists():
            print('Downloading',name,flush=True)
            urllib.request.urlretrieve(source+name,str(path)+'.part'); Path(str(path)+'.part').replace(path)
    print('OpenPose model SHA256',hashlib.file_digest((models/'control_v11p_sd15_openpose.pth').open('rb'),'sha256').hexdigest(),flush=True)
if __name__=='__main__':main()
