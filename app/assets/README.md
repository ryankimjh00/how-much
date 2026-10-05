# 디자인 에셋

- `figma/`: 사용자가 제공한 Figma 파일 `3V6S4dhhntbYRT5iLg31EE`, `02 · Screens`의 원본 SVG. 화면별 노드 ID를 파일명에 유지한다. 아이콘의 원본 크기·색을 변경하지 않고 버튼에서 터치 영역을 확보한다.
- `fonts/`: [Google Fonts](https://github.com/google/fonts)의 Jua, Gaegu, Noto Sans KR. 각각의 SIL Open Font License를 함께 보관한다.
- Noto Sans KR은 원본 가변 글꼴의 `wght`를 fontTools로 400/500/700에 고정한 TTF다. Flutter에서 본문·중간·굵은 글자를 일관되게 선택하도록 정적 글꼴로 등록한다.
- 카메라 영상과 가격 그래프는 실제 데이터다. Figma 샘플 영상·샘플 그래프를 초기 사용자 데이터로 넣지 않는다.
