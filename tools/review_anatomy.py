"""Create enlarged, private QA crops without changing the release assets."""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'Game/Art/Illustrations';QA=ROOT/'.godot/art-review';QA.mkdir(parents=True,exist_ok=True)
def main():
    names=['rin_seated','rin_standing']
    sheet=Image.new('RGB',(1200,900),'#d8d4c8');draw=ImageDraw.Draw(sheet)
    for index,name in enumerate(names):
        image=Image.open(ART/(name+'.png')).convert('RGBA')
        x=(index%2)*600;y=(index//2)*450
        crop=image.crop((145,245,365,445));base=Image.new('RGBA',crop.size,'#d8d4c8');base.alpha_composite(crop)
        sheet.paste(base.convert('RGB').resize((550,400)),(x+20,y+35));draw.text((x+20,y+10),name,fill='black')
    output=QA/'hands-review.png';sheet.save(output);print(output)
if __name__=='__main__':main()
