#!/usr/bin/env python3
"""APK가 사용하는 OpenCV 네이티브 함수가 실제로 포함됐는지 확인한다."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from zipfile import ZipFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--keep-file', type=Path, default=(
        Path(__file__).resolve().parent.parent /
        'app/.dart_tool/hooks_runner/shared/dartcv4/dartcv_keep.txt'
    ))
    args = parser.parse_args()
    if not args.keep_file.is_file():
        parser.error('Release 빌드가 생성한 dartcv_keep.txt가 필요합니다.')
    # [OCR 추가] 고정한 몇 함수뿐 아니라 해당 AOT 빌드가 기록한 모든 함수와 해제 함수를 검사한다.
    required = {
        line.strip() for line in args.keep_file.read_text().splitlines()
        if line.strip()
    }
    if not required:
        parser.error('필요 함수 목록이 비어 있어 검사할 수 없습니다.')
    with tempfile.TemporaryDirectory(prefix='howmuch-apk-symbols-') as folder:
        library = Path(folder) / 'libdartcv.so'
        with ZipFile(args.apk) as apk:
            library.write_bytes(apk.read('lib/arm64-v8a/libdartcv.so'))
        result = subprocess.run(
            ['nm', '-D', '--defined-only', str(library)],
            check=True, capture_output=True, text=True,
        )
        exported = {line.split()[-1] for line in result.stdout.splitlines() if line.split()}
    missing = sorted(required - exported)
    if missing:
        print('APK에 필요한 OpenCV 함수가 빠졌습니다:')
        print('\n'.join(missing))
        return 1
    print(f'OpenCV 필요 함수 {len(required)}개 포함 확인: {args.apk.name}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
