"""[OCR 추가] 공통 여백 시험의 원문·예외·정답을 모델별로 구분하여 집계한다."""
import json
from pathlib import Path
from summarize import normalized_number

ROOT = Path(__file__).resolve().parent
cases = json.loads((ROOT / 'padding-manifest.json').read_text())
summary = []
for path in sorted((ROOT / 'padding-results').glob('*.jsonl')):
    records = {record['id']: record for record in map(json.loads, path.read_text().splitlines())}
    assert len(records) == len(cases)
    for case in cases:
        assert records[case['id']]['sha256'] == case['sha256']
    for kind in ['quantity', 'amount', 'row']:
        selected = [case for case in cases if case['kind'] == kind]
        # [OCR 추가] 행 전체의 텍스트를 임의로 분리해 수량·금액 정답으로 세지 않는다.
        correct = None
        if kind != 'row':
            correct = sum(normalized_number(records[case['id']]['text']) == case['expected'] for case in selected)
        summary.append(dict(
            engine=path.stem, kind=kind, correct=correct, total=len(selected),
            empty=sum(not records[case['id']]['text'].strip() for case in selected),
            errors=sum('error' in records[case['id']] for case in selected),
        ))
(ROOT / 'padding-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2))
for row in summary:
    print(row)
