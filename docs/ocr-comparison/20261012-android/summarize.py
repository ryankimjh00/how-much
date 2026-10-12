"""[OCR 추가] 같은 Android 입력을 엔진·PSM별로 채점하며 결과를 합치지 않는다."""
import csv
import importlib.util
import json
from pathlib import Path
import statistics
import unicodedata

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent / '20261011'
spec = importlib.util.spec_from_file_location('number_scoring', BASE / 'summarize.py')
scoring = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scoring)


def name_text(text):
    # [OCR 추가] 한글 완성형과 자모 분해형의 표현 차이만 정규화한다.
    return scoring.normalized_name(unicodedata.normalize('NFC', text))


def main():
    summaries, fields, locations, timings = [], [], [], []
    for path in sorted((ROOT / 'results').glob('*.jsonl')):
        if path.name.endswith('.partial.jsonl'):
            continue
        records = [json.loads(line) for line in path.read_text().splitlines()]
        assert records, path
        suite = records[0]['suite']
        cases = json.loads((BASE / ('manifest.json' if suite == 'base' else 'padding-manifest.json')).read_text())
        psm = records[0]['psm']
        expected_cases = [case for case in cases if
                          (psm != 10 or case['kind'] == 'quantity') and
                          (psm != 7 or case['kind'] != 'whole')]
        lookup = {case['id']: case for case in cases}
        by_id = {record['id']: record for record in records}
        assert len(by_id) == len(records), f'중복 결과: {path}'
        assert set(by_id) == {case['id'] for case in expected_cases}, f'누락 입력: {path}'
        counts = {}
        for record in records:
            case = lookup[record['id']]
            assert record['sha256'] == case['sha256'], case['id']
            assert record['suite'] == suite and record['psm'] == psm
            kind, text = case['kind'], record['text']
            if kind not in ['quantity', 'amount', 'name', 'blank']:
                continue
            edits, chars = 0, 0
            if kind == 'name':
                expected, actual = name_text(case['expected']), name_text(text)
                correct = expected == actual
                edits, chars = scoring.edit_distance(expected, actual), len(expected)
            elif kind == 'blank':
                correct = not text.strip() and 'error' not in record
            else:
                correct = scoring.normalized_number(text) == case['expected']
            key = (case['photo_id'], kind)
            count = counts.setdefault(key, dict(correct=0, total=0, empty=0, errors=0, name_edits=0, name_chars=0))
            for key_name, increment in dict(correct=int(correct), total=1, empty=int(not text.strip()),
                                           errors=int('error' in record), name_edits=edits, name_chars=chars).items():
                count[key_name] += increment
            fields.append(dict(run=path.stem, id=case['id'], kind=kind, expected=case['expected'],
                               actual=text, correct=correct, error=record.get('error', ''), seconds=record['seconds']))
        for (photo, kind), count in counts.items():
            summaries.append(dict(run=path.stem, engine=records[0]['engine'], suite=suite, psm=psm,
                                  photo=photo, kind=kind, **count))
        times = [record['seconds'] for record in records]
        timings.append(dict(run=path.stem, count=len(records), errors=sum('error' in r for r in records),
                            first_seconds=times[0], median_seconds=statistics.median(times), total_seconds=sum(times)))
        if suite != 'base':
            continue
        for field in cases:
            if field['kind'] not in ['quantity', 'amount']:
                continue
            for context in ['whole', 'row']:
                record_id = field['photo_id'] if context == 'whole' else field['id'].replace('-quantity-', '-row-').replace('-amount-', '-row-')
                if record_id not in by_id:
                    continue
                source, record = lookup[record_id], by_id[record_id]
                offset = source['bounds'][:2] if source['bounds'] else [0, 0]
                selected = []
                left, top, right, bottom = field['bounds']
                for token in record.get('tokens', []):
                    box = token['bounds']
                    x = (box[0] + box[2]) / 2 + offset[0]
                    y = (box[1] + box[3]) / 2 + offset[1]
                    if left <= x <= right and top <= y <= bottom:
                        selected.append(token)
                values = [scoring.normalized_number(token['text']) for token in selected]
                # [OCR 추가] 다른 행의 같은 숫자를 가져오거나 한 토큰을 억지로 분리하지 않는다.
                correct = len(values) == 1 and values[0] == field['expected'] and 'error' not in record
                locations.append(dict(run=path.stem, context=context, photo=field['photo_id'], kind=field['kind'],
                                      id=field['id'], expected=field['expected'], selected=json.dumps(selected, ensure_ascii=False), correct=correct))
    for filename, rows in [('field-results.csv', fields), ('localization.csv', locations)]:
        if rows:
            with (ROOT / filename).open('w') as output:
                writer = csv.DictWriter(output, fieldnames=list(rows[0]))
                writer.writeheader()
                writer.writerows(rows)
    location_summary = []
    for run, context, photo, kind in dict.fromkeys((r['run'], r['context'], r['photo'], r['kind']) for r in locations):
        selected = [r for r in locations if (r['run'], r['context'], r['photo'], r['kind']) == (run, context, photo, kind)]
        location_summary.append(dict(run=run, context=context, photo=photo, kind=kind,
                                     correct=sum(r['correct'] for r in selected), total=len(selected)))
    for filename, data in [('summary.json', summaries), ('localization-summary.json', location_summary), ('timings.json', timings)]:
        (ROOT / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2))
    print(json.dumps(timings, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
