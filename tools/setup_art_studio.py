"""Install an isolated local A1111 studio. Model weights never enter source/export."""
import hashlib, json, os, subprocess, sys, urllib.request, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STUDIO = ROOT / '.private' / 'art-studio'
PYTHON = STUDIO / 'python' / 'python.exe'
WEBUI = STUDIO / 'stable-diffusion-webui'
MODEL = WEBUI / 'models' / 'Stable-diffusion' / 'AOM3A1B_orangemixs.safetensors'
MODEL_URL = 'https://huggingface.co/WarriorMama777/OrangeMixs/resolve/main/Models/AbyssOrangeMix3/AOM3A1B_orangemixs.safetensors'
MODEL_SHA = '5493a0ec491f5961dbdc1c861404088a6ae9bd4007f6a3a7c5dee8789cdc1361'

def download(url, path):
    if path.exists(): return
    path.parent.mkdir(parents=True, exist_ok=True)
    print('Downloading', path.name, flush=True)
    urllib.request.urlretrieve(url, path.with_suffix(path.suffix+'.part'))
    path.with_suffix(path.suffix+'.part').replace(path)

def run(args, cwd=None):
    print('Running', str(args[0]), str(args[1]) if len(args)>1 else '', flush=True)
    subprocess.run(args, cwd=cwd, check=True)

def write_launcher():
    launcher='@echo off\r\nset "PIP_CONSTRAINT=%~dp0constraints.txt"\r\nset "REQS_FILE=%~dp0requirements-compatible.txt"\r\nset "STABLE_DIFFUSION_REPO=https://github.com/w-e-w/stablediffusion.git"\r\ncd /d "%~dp0stable-diffusion-webui"\r\n"%~dp0python\\python.exe" -u launch.py --api --port 7861 --medvram --skip-version-check --no-download-sd-model --skip-python-version-check --autolaunch\r\n'
    (STUDIO/'START-ART-STUDIO.cmd').write_text(launcher)

def main():
    STUDIO.mkdir(parents=True, exist_ok=True)
    (STUDIO/'.gdignore').touch()
    if not PYTHON.exists():
        archive = STUDIO/'python.zip'
        download('https://www.python.org/ftp/python/3.10.11/python-3.10.11-embed-amd64.zip', archive)
        PYTHON.parent.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as z: z.extractall(PYTHON.parent)
        pth = PYTHON.parent/'python310._pth'
        pth.write_text('python310.zip\n.\nLib/site-packages\nimport site\n')
        download('https://bootstrap.pypa.io/get-pip.py', STUDIO/'get-pip.py')
        run([str(PYTHON), str(STUDIO/'get-pip.py')])
    if not WEBUI.exists():
        run(['git','clone','https://github.com/AUTOMATIC1111/stable-diffusion-webui.git',str(WEBUI)])
    # Embeddable Python deliberately ignores PYTHONPATH; add the app explicitly.
    (PYTHON.parent/'python310._pth').write_text('python310.zip\n.\nLib/site-packages\n'+str(WEBUI)+'\nimport site\n')
    pins=['setuptools==69.5.1','numpy==1.26.2','opencv-python==4.10.0.84','opencv-contrib-python==4.10.0.84','opencv-python-headless==4.10.0.84','mediapipe==0.10.9','protobuf==3.20.3','onnx==1.15.0','onnxruntime==1.17.3','jax==0.4.23','jaxlib==0.4.23','scipy==1.12.0','rembg==2.0.57','Pillow==9.5.0']
    constraints=STUDIO/'constraints.txt'
    constraints.write_text('\n'.join(pins)+'\n')
    run([str(PYTHON),'-m','pip','install','-c',str(constraints),*pins,'wheel'])
    run([str(PYTHON),'-m','pip','install','--no-build-isolation','https://github.com/openai/CLIP/archive/d50d76daa670286dd6cacf3bcd80b5e4823fc8e1.zip'])
    download(MODEL_URL, MODEL)
    digest = hashlib.file_digest(MODEL.open('rb'),'sha256').hexdigest()
    if digest != MODEL_SHA: raise RuntimeError('Checkpoint SHA256 mismatch')
    print('AOM3A1B checksum verified', flush=True)
    config = {'sd_model_checkpoint':MODEL.name,'samples_save':False,'grid_save':False,'show_progress_every_n_steps':0}
    (WEBUI/'config.json').write_text(json.dumps(config, indent=2))
    env = os.environ.copy()
    env['PYTHONPATH'] = str(WEBUI)
    env['GIT_TERMINAL_PROMPT'] = '0'
    env['GCM_INTERACTIVE'] = 'Never'
    env['STABLE_DIFFUSION_REPO'] = 'https://github.com/w-e-w/stablediffusion.git'
    env['PIP_CONSTRAINT']=str(constraints)
    compatible_requirements=STUDIO/'requirements-compatible.txt'
    compatible_requirements.write_text((WEBUI/'requirements_versions.txt').read_text().replace('protobuf==3.20.0','protobuf==3.20.3'))
    env['REQS_FILE']=str(compatible_requirements)
    write_launcher()
    args = [str(PYTHON),'-u',str(WEBUI/'launch.py'),'--api','--port','7861','--medvram','--skip-version-check','--no-download-sd-model','--skip-python-version-check']
    print('Starting local-only API on 127.0.0.1:7861', flush=True)
    subprocess.run(args, cwd=WEBUI, env=env, check=True)

if __name__ == '__main__': main()
