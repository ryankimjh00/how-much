# 온디바이스 AI 조사·구현·검증 보고서

[A4 11쪽 PDF](얼마였지_온디바이스AI_조사구현검증보고서_20261011.pdf) · [HTML 원본](얼마였지_온디바이스AI_조사구현검증보고서_20261011.html)

온디바이스 AI 기술 조사, 실제 영수증 OCR 구현, 모델별 독립 비교와 추가 검증만 담았다. 기준은 `037fe0a`, 시험 브랜치는 `test/receipt-ocr-models`다. 작성일은 2026-10-11이다.

실제 원본·보정본·재작성본과 모의 응답 테스트를 구분한다. ML Kit는 Android 에뮬레이터의 네이티브 인식기, PaddleOCR·Tesseract는 Ubuntu 호스트에서 실행했다. 단독 수량과 전체 사진 위치 검출의 성적을 별도로 보고하며 실기기 속도·메모리·발열·iOS OCR 비교는 미측정이다.

추가로 세 엔진에 동일한 흰 여백을 붙인 트레이더스 작은 영역 45건씩을 입력했다. 최소 크기 오류가 없어진 것과 정답을 읽은 것을 구분했다. 원문·입력 해시는 [비교 자료](../../ocr-comparison/20261011/README.md)에 있다. 앱 인식기는 교체하지 않았고 기존 앱·기록·로컬 변경을 유지했다.

PDF는 한글 글꼴 포함, 11쪽 전체 배치, 공식 출처 12개의 클릭 링크, 한글 텍스트 추출과 주요 성적을 검수했다. [검수 기록](verification.json)을 보관한다.

재생성 도구는 `/tmp/howmuch-ai-report-env`의 WeasyPrint 70.0·PyMuPDF·Pillow이며 앱 패키지와 분리했다.

```bash
/tmp/howmuch-ai-report-env/bin/python docs/research/on-device-ai-20261011/build_report.py
/tmp/howmuch-ai-report-env/bin/python docs/research/on-device-ai-20261011/verify_report.py
```

그림은 `build_figures.py`로 생성한다. 비교 입력을 `prepare_inputs.py`·`prepare_padding_inputs.py`로 먼저 준비한다. PDF의 그림 확대는 표시용이며 실제 OCR 시험 입력에는 적용하지 않았다.

요청한 Windows 저장 위치: `C:\Users\AA\Downloads\airesearch\얼마였지_온디바이스AI_OCR보고서_20261011.pdf`.

기존 Windows PDF는 덮어쓰기 권한 오류로 교체하지 못했으므로 `수정본.pdf`가 현재 문서다. 저장소의 PDF는 수정된 11쪽 문서다.

사용자 요청에 따라 원근보정 설명·도식·구현 참조와 일반 이미지 보정 구현 절을 제거했다. OCR 모델·연결·선택·실제 비교 시험을 중심으로 구성했다. 시험 조건의 기존 보정 사진 사용 여부는 정확한 결과 해석을 위해 명시한다.
# 이전 보고서 안내

이 폴더의 조사·구현·검증 보고서는 이전 작업 기록이다. 사용자 요청 범위에 맞춰 다시 작성한 현재 문서는 [온디바이스 AI 기술 조사](../on-device-ai-survey-20261011/README.md)에 있다.

