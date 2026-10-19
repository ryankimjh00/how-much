"""[OCR 추가] 엔진 하나만 Android에서 시험하고 원문·해시를 별도 파일로 저장한다."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
APP = REPO / 'app'
SDK = Path('/home/jhshin/mobile/.android-build/sdk')
FLUTTER = Path('/home/jhshin/mobile/.flutter-toolchain/flutter/bin/flutter')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', choices=['mlkit', 'paddle', 'tesseract'], required=True)
    parser.add_argument('--suite', choices=['base', 'padding'], default='base')
    parser.add_argument('--psm', choices=[3, 7, 10], type=int, default=3)
    parser.add_argument('--device', default='emulator-5554')
    args = parser.parse_args()
    if args.engine != 'tesseract' and args.psm != 3:
        parser.error('PSM 7·10은 Tesseract에만 적용한다.')
    run = f'{args.engine}-{args.suite}-psm{args.psm}'
    (ROOT / 'logs').mkdir(exist_ok=True)
    (ROOT / 'results').mkdir(exist_ok=True)
    env = os.environ.copy()
    env.update(ANDROID_HOME=str(SDK), GRADLE_USER_HOME='/home/jhshin/mobile/.android-build/gradle',
               PUB_CACHE='/home/jhshin/mobile/.flutter-toolchain/pub-cache')
    defines = ['--dart-define=OCR_COMPARE=true', f'--dart-define=OCR_ENGINE={args.engine}',
               f'--dart-define=OCR_SUITE={args.suite}', f'--dart-define=OCR_PSM={args.psm}']
    # [OCR 추가] 설치 전에 다른 패키지인지 검사한다. 테스트 후 자동 삭제도 금지한다.
    with (ROOT / 'logs' / f'{run}-build.log').open('w') as log:
        subprocess.run([str(FLUTTER), 'build', 'apk', '--debug', '--no-pub',
                        '--target=integration_test/ocr_android_comparison_test.dart', *defines],
                       cwd=APP, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    apk = APP / 'build/app/outputs/flutter-apk/app-debug.apk'
    badging = subprocess.check_output([str(SDK / 'build-tools/35.0.0/aapt'), 'dump', 'badging', str(apk)], text=True)
    assert "name='com.todayone.todo.ocrcompare2'" in badging.splitlines()[0], '기본 앱에는 설치하지 않는다.'
    log_path = ROOT / 'logs' / f'{run}.log'
    print(f'Android 시작: {run}', flush=True)
    with log_path.open('w') as log:
        completed = subprocess.run([str(FLUTTER), 'test', 'integration_test/ocr_android_comparison_test.dart',
                                    '-d', args.device, '--no-pub', '--no-uninstall', *defines],
                                   cwd=APP, env=env, stdout=log, stderr=subprocess.STDOUT)
    records = []
    for line in log_path.read_text().splitlines():
        marker = 'ANDROID_OCR_COMPARE '
        if marker in line:
            records.append(json.loads(line.split(marker, 1)[1]))
    # [OCR 추가] 중단된 실행은 완료된 비교 파일과 구분하여 보관한다.
    output_name = f'{run}.jsonl' if completed.returncode == 0 else f'{run}.partial.jsonl'
    (ROOT / 'results' / output_name).write_text(''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in records))
    print(f'Android 종료: {run}, {len(records)}건, 오류 {sum("error" in r for r in records)}건', flush=True)
    if completed.returncode:
        raise SystemExit(completed.returncode)


if __name__ == '__main__':
    main()
