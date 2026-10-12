"""[OCR 추가] 앱과 분리하여 동일 PNG의 모델별 원문·좌표를 기록한다."""
import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('engine', choices=['paddle', 'tesseract-auto', 'tesseract-line', 'tesseract-digit'])
parser.add_argument('manifest')
parser.add_argument('output')
args = parser.parse_args()
cases = json.loads(Path(args.manifest).read_text())
if args.engine == 'paddle':
    os.environ['PADDLE_PDX_CACHE_HOME'] = '/tmp/receipt-paddle-cache'
    os.environ['PADDLE_PDX_MODEL_SOURCE'] = 'bos'
    os.environ['PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK'] = 'True'
    os.environ['HF_HOME'] = '/tmp/receipt-hf-cache'
    from paddleocr import PaddleOCR
    recognizer = PaddleOCR(
        text_detection_model_name='PP-OCRv5_mobile_det',
        text_recognition_model_name='korean_PP-OCRv5_mobile_rec',
        use_doc_orientation_classify=False, use_doc_unwarping=False,
        use_textline_orientation=False, device='cpu', cpu_threads=4,
        enable_mkldnn=False,
    )

with Path(args.output).open('w') as output:
    for case in cases:
        if args.engine == 'tesseract-line' and case['kind'] == 'whole':
            continue
        if args.engine == 'tesseract-digit' and case['kind'] != 'quantity':
            continue
        # [OCR 추가] 모델에 넘긴 파일이 고정 입력과 다르면 시험을 중단한다.
        path = Path(case['path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == case['sha256']
        record = {'id': case['id'], 'engine': args.engine, 'sha256': case['sha256']}
        started = time.perf_counter()
        try:
            if args.engine == 'paddle':
                raw = list(recognizer.predict(str(path)))[0].json['res']
                record.update(text='\n'.join(raw['rec_texts']), raw=raw)
            else:
                segmentation = {'tesseract-auto': '3', 'tesseract-line': '7', 'tesseract-digit': '10'}[args.engine]
                with tempfile.TemporaryDirectory(prefix='receipt-tesseract-') as folder:
                    base = Path(folder) / 'result'
                    command = ['tesseract', str(path), str(base), '-l', 'kor+eng', '--oem', '1', '--psm', segmentation]
                    if args.engine == 'tesseract-digit':
                        command.extend(['-c', 'tessedit_char_whitelist=0123456789'])
                    command.extend(['tsv', 'txt'])
                    completed = subprocess.run(command, capture_output=True, text=True, check=True, timeout=120)
                    tokens = [row for row in csv.DictReader(io.StringIO(base.with_suffix('.tsv').read_text()), delimiter='\t') if row['text'].strip()]
                    record.update(text=base.with_suffix('.txt').read_text().strip(), tokens=tokens, stderr=completed.stderr)
        except Exception as error:
            # [OCR 추가] 빈 인식과 실행 실패를 구분하고 다음 사진은 계속 시험한다.
            record.update(text='', error=str(error))
        record['seconds'] = time.perf_counter() - started
        output.write(json.dumps(record, ensure_ascii=False) + '\n')
        output.flush()
        print(args.engine, case['id'], repr(record['text']), flush=True)
