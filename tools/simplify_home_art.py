"""Withdraw complex action poses; retain only seated and talking sprites."""
import shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    art=ROOT/'Game/Art/Illustrations'
    archive=ROOT/'.private/art-studio/production/withdrawn-action-poses';archive.mkdir(parents=True,exist_ok=True)
    for name in ['rin_cooking','rin_reading','rin_resting']:
        for suffix in ['.png','.png.import','.json']:
            source=art/(name+suffix)
            if source.exists():shutil.move(str(source),str(archive/source.name))
    print('Complex action illustrations withdrawn. Home uses seated Rin; dialogue uses standing Rin.')
if __name__=='__main__':main()
