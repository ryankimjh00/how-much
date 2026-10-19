"""[OCR 추가] 준비된 모델·언어 데이터·동일 사진을 비교 APK 전용 경로에 배치한다."""
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def copy_file(source, destination, expected_hash=None):
    data = source.read_bytes()
    actual_hash = hashlib.sha256(data).hexdigest()
    if expected_hash is not None and actual_hash != expected_hash:
        raise ValueError(f'입력 파일 해시 불일치: {source}')
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return actual_hash


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--onnx-models', type=Path, required=True)
    parser.add_argument('--korean-config', type=Path, required=True)
    parser.add_argument('--tessdata', type=Path, required=True)
    parser.add_argument('--tesseract-aar', type=Path, required=True)
    args = parser.parse_args()
    for model in ['det', 'rec']:
        copy_file(args.onnx_models / model / 'inference.onnx', HERE / f'assets/models/{model}/inference.onnx')
    copy_file(args.korean_config, HERE / 'assets/models/rec/inference.yml')
    previous = REPO / 'docs/ocr-comparison/20261011'
    environment = json.loads((previous / 'environment.json').read_text())
    for language in ['kor', 'eng']:
        original_path = f'/usr/share/tesseract-ocr/4.00/tessdata/{language}.traineddata'
        copy_file(args.tessdata / f'{language}.traineddata', HERE / f'assets/tessdata/{language}.traineddata',
                  environment['hashes'][original_path])
    copy_file(args.tesseract_aar, HERE / 'libs/tesseract4android-4.9.0.aar')
    for suite, manifest_name in [('comparison', 'manifest.json'), ('padding', 'padding-manifest.json')]:
        manifest = previous / manifest_name
        for case in json.loads(manifest.read_text()):
            copy_file(Path(case['path']), HERE / f'assets/{suite}/{case["id"]}.png', case['sha256'])
        copy_file(manifest, HERE / f'assets/{suite}/manifest.json')
    print('비교 전용 모델·언어 데이터·262개 입력 준비 완료')


if __name__ == '__main__':
    main()
