"""[OCR 추가] 정답 영역 안의 숫자만 연결하여 이웃 수량의 오확정을 확인한다."""
import csv
import json
from pathlib import Path
from summarize import normalized_number

ROOT = Path(__file__).resolve().parent
cases = json.loads((ROOT / 'manifest.json').read_text())
lookup = {case['id']: case for case in cases}
rows = []
for engine in ['mlkit', 'paddle', 'tesseract-auto', 'tesseract-line']:
    records = {entry['id']: entry for entry in map(json.loads, (ROOT / 'results' / f'{engine}.jsonl').read_text().splitlines())}
    for field in cases:
        if field['kind'] not in ['quantity', 'amount']:
            continue
        for context in ['whole', 'row']:
            record_id = field['photo_id'] if context == 'whole' else field['id'].replace('-quantity-', '-row-').replace('-amount-', '-row-')
            if record_id not in records:
                continue
            source = lookup[record_id]
            record = records[record_id]
            assert record['sha256'] == source['sha256']
            offset = source['bounds'][:2] if source['bounds'] else [0, 0]
            tokens = []
            if engine == 'paddle':
                raw = record.get('raw', {})
                for text, polygon, score in zip(raw.get('rec_texts', []), raw.get('rec_polys', []), raw.get('rec_scores', [])):
                    xs = [point[0] for point in polygon]
                    ys = [point[1] for point in polygon]
                    tokens.append((text, [min(xs), min(ys), max(xs), max(ys)], score))
            else:
                for token in record.get('tokens', []):
                    if engine == 'mlkit':
                        box = token['bounds']
                        score = token['confidence']
                    else:
                        left, top, width, height = (int(token[key]) for key in ['left', 'top', 'width', 'height'])
                        box = [left, top, left + width, top + height]
                        score = float(token['conf']) / 100
                    tokens.append((token['text'], box, score))
            left, top, right, bottom = field['bounds']
            selected = []
            for text, box, score in tokens:
                x = (box[0] + box[2]) / 2 + offset[0]
                y = (box[1] + box[3]) / 2 + offset[1]
                if left <= x <= right and top <= y <= bottom:
                    selected.append({'text': text, 'confidence': score})
            # [OCR 추가] 다른 열/다른 행의 숫자를 가져오거나 문자열을 억지로 분리하지 않는다.
            values = [normalized_number(token['text']) for token in selected]
            correct = len(values) == 1 and values[0] == field['expected']
            rows.append(dict(engine=engine, context=context, photo=field['photo_id'], kind=field['kind'], id=field['id'], expected=field['expected'], selected=json.dumps(selected, ensure_ascii=False), correct=correct))
with (ROOT / 'localization.csv').open('w') as output:
    writer = csv.DictWriter(output, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
summary = []
for engine in ['mlkit', 'paddle', 'tesseract-auto', 'tesseract-line']:
    for context in ['whole', 'row']:
        for photo in dict.fromkeys(case['photo_id'] for case in cases):
            for kind in ['quantity', 'amount']:
                selected = [row for row in rows if row['engine'] == engine and row['context'] == context and row['photo'] == photo and row['kind'] == kind]
                if selected:
                    summary.append(dict(engine=engine, context=context, photo=photo, kind=kind, correct=sum(row['correct'] for row in selected), total=len(selected)))
(ROOT / 'localization-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2))
for entry in summary:
    if entry['engine'] in ['mlkit', 'paddle'] and entry['kind'] == 'quantity':
        print(entry)
