"""[OCR 추가] 조사 범위·한글·출처 링크와 페이지 구성을 확인한다."""
import json
from pathlib import Path
import pymupdf
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
pdf = next(HERE.glob('*.pdf'))
document = pymupdf.open(pdf)
texts = [page.get_text() for page in document]
combined = '\n'.join(texts)
# 줄바꿈으로 나뉜 용어도 PDF에 실제 포함됐는지 확인한다.
compact_text = ''.join(combined.split())
assert len(document) == 20, '페이지가 넘쳐 분리됐는지 확인한다.'
assert all(len(text) > 350 for text in texts)
for required in ['Android', 'iOS', '크로스플랫폼', '경량', 'ML Kit', 'LiteRT', 'Core ML', 'ONNX', 'ExecuTorch', '기본 사용', '구현 방법', 'Paddle Lite', 'PaddlePredictor', 'OCR 툴킷', '경량 추론 엔진', '모바일 ML SDK', '딥러닝 프레임워크', 'F-13', 'F-18', '손글씨', '매장', '구매일']:
    assert ''.join(required.split()) in compact_text, required
for excluded in ['원근보정', 'FastAPI', '275개', '현재 선택', '채택', '물체', 'EfficientDet', 'SSD MobileNet', 'Gemma', 'Llama', 'MobileNetV2', '이미지 분류', '개당 가격', 'Foundation Models']:
    assert excluded not in combined, excluded
links = {link['uri'] for page in document for link in page.get_links() if 'uri' in link}
assert len(links) == 24
for measured in ['21/21', '15/21', '7/21', '2/15', '7/15', 'Ubuntu', '에뮬레이터']:
    assert measured in combined, measured
assert '\ufffd' not in combined
for measured in ['동일 Android', '1600px', '5.5.1', '4000px', '1.9GB', 'PSM 10']:
    assert ''.join(measured.split()) in compact_text, measured
result = {'pages': len(document), 'unique_source_links':len(links), 'scope':'앱 OCR 요구사항·기술 조사·Android 독립 모델 비교', 'examples_executed':False, 'android_engines_executed':['mlkit','paddle','tesseract']}
(HERE/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
# 페이지 전체를 한눈에 확인하고, 긴 코드가 있는 페이지는 원본 크기로 확인한다.
canvas = Image.new('RGB',(900,((len(document)+2)//3)*430),'#cccccc')
for index,page in enumerate(document):
    pix = page.get_pixmap(matrix=pymupdf.Matrix(0.45,0.45))
    tile = Image.frombytes('RGB',(pix.width,pix.height),pix.samples)
    x,y=(index%3)*300,(index//3)*430
    canvas.paste(tile,(x+12,y+20))
    ImageDraw.Draw(canvas).text((x+12,y+3),str(index+1),fill='black')
canvas.save('/tmp/ai-survey-pages.png')
document[8].get_pixmap(matrix=pymupdf.Matrix(1.3,1.3)).save('/tmp/ai-survey-code.png')
print(json.dumps(result,ensure_ascii=False))
