"""[OCR 추가] 수동 정답으로 모델별 결과를 따로 집계한다. 후보 혼합은 하지 않는다."""
import csv
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
cases = json.loads((ROOT / 'manifest.json').read_text())


def normalized_number(text):
    # [OCR 추가] 쉼표/점 천 단위 표기만 허용한다. I→1 등 오인식 보정은 하지 않는다.
    compact = ''.join(text.split())
    if re.fullmatch(r'\d+', compact):
        return str(int(compact))
    if re.fullmatch(r'\d{1,3}(?:[,.]\d{3})+', compact):
        return str(int(re.sub(r'[,.]', '', compact)))
    return None


def normalized_name(text):
    return ''.join(character.upper() for character in text if character.isalnum())


def edit_distance(left, right):
    previous = list(range(len(right) + 1))
    for i, first in enumerate(left, 1):
        current = [i]
        for j, second in enumerate(right, 1):
            current.append(min(current[-1] + 1, previous[j] + 1, previous[j-1] + (first != second)))
        previous = current
    return previous[-1]


def main():
    rows = []
    counts = {}
    for path in sorted((ROOT / 'results').glob('*.jsonl')):
        records = {record['id']: record for record in map(json.loads, path.read_text().splitlines())}
        for case in cases:
            if case['kind'] not in ['quantity', 'amount', 'name', 'blank'] or case['id'] not in records:
                continue
            record = records[case['id']]
            assert record['sha256'] == case['sha256'], case['id']
            kind = case['kind']
            text = record['text']
            if kind == 'name':
                expected = normalized_name(case['expected'])
                actual = normalized_name(text)
                correct = expected == actual
                distance = edit_distance(expected, actual)
            elif kind == 'blank':
                correct = text.strip() == ''
                distance = 0
            else:
                correct = normalized_number(text) == case['expected']
                distance = 0
            key = (record['engine'], case['photo_id'], kind)
            summary = counts.setdefault(key, {'correct': 0, 'total': 0, 'empty': 0, 'errors': 0, 'name_edits': 0, 'name_chars': 0})
            summary['correct'] += int(correct)
            summary['total'] += 1
            summary['empty'] += int(not text.strip())
            summary['errors'] += int('error' in record)
            summary['name_edits'] += distance
            summary['name_chars'] += len(normalized_name(case['expected'])) if kind == 'name' else 0
            rows.append(dict(engine=record['engine'], id=case['id'], kind=kind, expected=case['expected'], actual=text, correct=correct, empty=not text.strip(), seconds=record['seconds']))
    with (ROOT / 'field-results.csv').open('w') as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = [{'engine': key[0], 'photo': key[1], 'kind': key[2], **value} for key, value in counts.items()]
    (ROOT / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2))
    for engine in ['mlkit', 'paddle', 'tesseract-auto', 'tesseract-line', 'tesseract-digit']:
        print(engine)
        for kind in ['quantity', 'amount', 'name']:
            selected = [entry for entry in summary if entry['engine'] == engine and entry['kind'] == kind]
            print(kind, sum(entry['correct'] for entry in selected), '/', sum(entry['total'] for entry in selected))


if __name__ == "__main__":
    main()
