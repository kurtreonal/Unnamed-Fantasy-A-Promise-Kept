"""Fetch rembg's official anime segmentation model through GitHub's asset API."""
import json,os,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
TARGET=ROOT/'.private/art-studio/production/segmentation-models/isnet-anime.onnx'
def main():
    if TARGET.exists():return
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    headers={'User-Agent':'PromiseKeptLocalArt/1.0','Accept':'application/vnd.github+json'}
    request=urllib.request.Request('https://api.github.com/repos/danielgatis/rembg/releases/tags/v0.0.0',headers=headers)
    with urllib.request.urlopen(request) as response:release=json.load(response)
    asset=next(a for a in release['assets'] if a['name']=='isnet-anime.onnx')
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self,*args):return None
    request=urllib.request.Request(asset['url'],headers={'User-Agent':headers['User-Agent'],'Accept':'application/octet-stream'})
    try:response=urllib.request.build_opener(NoRedirect).open(request)
    except urllib.error.HTTPError as error:
        if error.code!=302:raise
        url=error.headers['Location']
    else:url=response.geturl();response.close()
    urllib.request.urlretrieve(url,str(TARGET)+'.part');Path(str(TARGET)+'.part').replace(TARGET)
    assert TARGET.stat().st_size==asset['size']
    print('Downloaded official anime cutout model',TARGET.stat().st_size,flush=True)
if __name__=='__main__':main()
