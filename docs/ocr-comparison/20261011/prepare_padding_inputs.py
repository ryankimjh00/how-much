"""[OCR 추가] 최소 크기 오류와 실제 판독 실패를 구분할 공통 여백 입력을 만든다."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageOps
root=Path(__file__).resolve().parent
cases=json.loads((root/'manifest.json').read_text())
out=Path('/tmp/receipt-ocr-comparison/padded-inputs')
out.mkdir(exist_ok=True)
manifest=[]
for case in cases:
 if case['photo_id']!='traders-original' or case['kind']=='whole':continue
 pic=Image.open(case['path']).convert('RGB')
 horizontal=max(0,32-pic.width)
 vertical=max(0,32-pic.height)
 pad=[horizontal//2,vertical//2,horizontal-horizontal//2,vertical-vertical//2]
 pic=ImageOps.expand(pic,border=tuple(pad),fill='white')
 new=dict(case)
 new['id']=case['id']+'-padded'
 new['path']=str(out/(new['id']+'.png'))
 pic.save(new['path'])
 new.update(width=pic.width,height=pic.height,padding=pad,source_id=case['id'],sha256=hashlib.sha256(Path(new['path']).read_bytes()).hexdigest())
 manifest.append(new)
(root/'padding-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print('공통 패딩',len(manifest))
