"""[OCR 추가] 실제 모델 출력과 같은 입력 사진으로 보고서용 그림을 생성한다."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[2] / 'ocr-comparison/20261011'
out=Path(__file__).resolve().parent
manifest={x['id']:x for x in json.loads((root/'manifest.json').read_text())}
id='samseon-original-quantity-01'
photo=Image.open(manifest[id]['path']).convert('RGB')
canvas=Image.new('RGB',(980,340),'white')
font=ImageFont.truetype(str(out.parents[2] / 'app/assets/fonts/NotoSansKR-Regular.ttf'),24)
draw=ImageDraw.Draw(canvas)
for i,engine in enumerate(['mlkit','paddle','tesseract-auto']):
 x=20+i*325
 pic=photo.resize((210,210),Image.Resampling.NEAREST)
 canvas.paste(pic,(x,45))
 draw.text((x,5),{'mlkit':'ML Kit','paddle':'PaddleOCR','tesseract-auto':'Tesseract PSM 3'}[engine],font=font,fill='#173642')
 records={v['id']:v for v in map(json.loads,(root/'results'/f'{engine}.jsonl').read_text().splitlines())}
 text=records[id]['text']
 draw.text((x,265),'결과: '+(text if text else '빈 결과'),font=font,fill='#173642')
canvas.save(out/'pepsi-quantity.png')
# [OCR 추가] 그림은 보고서 표시용 확대이며 OCR 시험 입력은 바꾸지 않는다.
case=next(c for c in json.loads((root/'padding-manifest.json').read_text()) if c['kind']=='quantity')
old=Image.open(manifest[case['source_id']]['path']).convert('RGB')
new=Image.open(case['path']).convert('RGB')
canvas=Image.new('RGB',(800,260),'white');draw=ImageDraw.Draw(canvas)
for i,(pic,label) in enumerate([(old,f'원래 영역 {old.width}×{old.height}px'),(new,f'공통 여백 {new.width}×{new.height}px')]):
 x=30+i*400
 draw.text((x,5),label,font=font,fill='#173642')
 shown=pic.resize((pic.width*5,pic.height*5),Image.Resampling.NEAREST)
 canvas.paste(shown,(x,55))
 draw.rectangle((x-1,54,x+shown.width,55+shown.height),outline='#aaaaaa',width=1)
canvas.save(out/'padding-example.png')
