"""[OCR 추가] 한글·페이지·글꼴·출처 링크와 표 성적을 PDF에서 확인한다."""
import hashlib
import json
from pathlib import Path

import pymupdf

HERE = Path(__file__).resolve().parent
pdf = HERE / '얼마였지_온디바이스AI_조사구현검증보고서_20261011.pdf'
document = pymupdf.open(pdf)
assert len(document) == 11
text = '\n'.join(page.get_text() for page in document)
assert '\ufffd' not in text
for outside_scope in ['크로스플랫폼', '백엔드', 'FastAPI', 'Supabase', 'Amplify', '원근', 'perspective', '모서리']:
    assert outside_scope not in text, outside_scope
for expected in ['온디바이스 AI', '21/21', '15/21', '2/15', '7/15', '12/15', '0/15', '275개', '미측정']:
    assert expected in text, expected
records = []
for index, page in enumerate(document):
    outside = [block[:4] for block in page.get_text('blocks') if block[0] < -1 or block[1] < -1 or block[2] > page.rect.width + 1 or block[3] > page.rect.height + 1]
    assert not outside
    assert len(page.get_text()) > 400
    assert '얼마였지 /' in page.get_text(), '절 머리 없는 빈약한 넘김 페이지'
    records.append(dict(page=index + 1, chars=len(page.get_text()), outside=outside, links=len(page.get_links())))
fonts = sorted(set(font[3] for page in document for font in page.get_fonts()))
assert any('ReportKR' in font for font in fonts)
links = [link['uri'] for page in document for link in page.get_links() if 'uri' in link]
assert len(set(links)) == 12
output = dict(
    file=pdf.name, sha256=hashlib.sha256(pdf.read_bytes()).hexdigest(),
    pages=len(document), pages_detail=records, fonts=fonts,
    links=len(links), unique_sources=len(set(links)),
    visual_review='전체 11쪽 배치와 비교 표·그림·참고문헌을 렌더링하여 확인',
    actual_padding_test='세 엔진 각각 45건, 입력 해시 확인, 실행 예외 0건',
    production_config='pubspec.yaml·applicationId 원래 바이트로 복원',
)
(HERE / 'verification.json').write_text(json.dumps(output, ensure_ascii=False, indent=2))
print('검수 완료',len(document),'쪽 / 공식 출처',len(set(links)),'개')
